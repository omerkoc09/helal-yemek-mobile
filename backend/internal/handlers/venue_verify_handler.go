package handlers

import (
	"errors"
	"strings"

	"github.com/gofiber/fiber/v2"
	"github.com/omerkoc/caiz-mi/internal/models"
	"github.com/omerkoc/caiz-mi/internal/repository"
)

// ConfirmVenue godoc
// POST /api/v1/venues/:id/confirm  (Guide)
func (h *VenueHandler) ConfirmVenue(c *fiber.Ctx) error {
	venueID := c.Params("id")
	guideID, err := getUserID(c)
	if err != nil {
		return err
	}

	guideCity := ""
	if getUserRole(c) == string(models.RoleGuide) {
		gc, gcErr := h.userRepo.GetGuideCity(c.Context(), guideID)
		if gcErr != nil {
			return fiber.ErrInternalServerError
		}
		if gc != nil {
			guideCity = *gc
		}
	}

	if err := h.venueRepo.ConfirmVenue(c.Context(), venueID, guideID, guideCity, h.verificationPeriodDays); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "mekan bulunamadı"})
		}
		msg := err.Error()
		if strings.Contains(msg, "doğrulamışsınız") ||
			strings.Contains(msg, "kendi eklediğiniz") ||
			strings.Contains(msg, "yalnızca onaylı") ||
			strings.Contains(msg, "rehberi olduğunuz") {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": msg})
		}
		return fiber.ErrInternalServerError
	}
	return c.JSON(fiber.Map{"status": "confirmed"})
}

// PUT /api/v1/venues/:id/verify
// Rehber kendi mekanının hâlâ helal olduğunu teyit eder.
func (h *VenueHandler) Verify(c *fiber.Ctx) error {
	venueID := c.Params("id")
	guideID, err := getUserID(c)
	if err != nil {
		return err
	}

	dropped, err := h.venueRepo.VerifyByGuide(c.Context(), venueID, guideID, h.verificationPeriodDays)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return fiber.ErrNotFound
		}
		return fiber.ErrInternalServerError
	}

	_ = h.verifLogRepo.Create(c.Context(), venueID, guideID, "verified")

	// Düşen rehberlere bildirim (fire-and-forget; mekan adını detaydan al).
	if len(dropped) > 0 && h.notifService != nil {
		venueName := ""
		if v, vErr := h.venueRepo.FindByID(c.Context(), venueID); vErr == nil {
			venueName = v.Name
		}
		for _, gid := range dropped {
			_ = h.notifService.SendConfirmationReset(c.Context(), gid, venueID, venueName)
		}
	}

	return c.JSON(fiber.Map{"status": "verified"})
}

// TrackDirectionClick godoc
// POST /api/v1/venues/:id/direction-click
// Yol tarifi butonuna basıldığını kaydeder. Auth opsiyonel — token varsa user_id,
// yoksa anonim (NULL). Fire-and-forget; her zaman 204 döner.
func (h *VenueHandler) TrackDirectionClick(c *fiber.Ctx) error {
	venueID := c.Params("id")

	var userID *string
	if uid, ok := c.Locals("userID").(string); ok && uid != "" {
		userID = &uid
	}

	// Hata olsa bile kullanıcı akışını bozmamak için sessizce yut; yine de 204 dön.
	_ = h.directionRepo.Create(c.Context(), venueID, userID)

	return c.SendStatus(fiber.StatusNoContent)
}

// Fotoğraf proxy'sinde izin verilen genişlik sınırları.
// Üst sınır olmadan biri w=100000 isteyerek Places kotasını ve bant genişliğini
// tüketebilirdi; alt sınır anlamsız isteklerin önüne geçer.
const (
	minPhotoWidth     = 100
	maxPhotoWidth     = 1600
	defaultPhotoWidth = 800
)
