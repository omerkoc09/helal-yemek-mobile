package handlers

import (
	"errors"
	"strings"

	"github.com/gofiber/fiber/v2"
	"github.com/omerkoc/caiz-mi/internal/models"
	"github.com/omerkoc/caiz-mi/internal/repository"
)

type GuideHandler struct {
	guideRepo    *repository.GuideRepo
	venueRepo    *repository.VenueRepo
	referralRepo *repository.ReferralRepo
}

func NewGuideHandler(guideRepo *repository.GuideRepo, venueRepo *repository.VenueRepo, referralRepo *repository.ReferralRepo) *GuideHandler {
	return &GuideHandler{guideRepo: guideRepo, venueRepo: venueRepo, referralRepo: referralRepo}
}

// POST /guide/apply — Traveler → Guide başvurusu gönderir.
func (h *GuideHandler) Apply(c *fiber.Ctx) error {
	userID, err := getUserID(c)
	if err != nil {
		return err
	}
	role := getUserRole(c)

	if role != string(models.RoleTraveler) {
		return c.Status(400).JSON(fiber.Map{"error": "yalnızca traveler kullanıcılar başvurabilir"})
	}

	var body struct {
		ReferralCode string `json:"referral_code"`
	}
	if err := c.BodyParser(&body); err != nil || strings.TrimSpace(body.ReferralCode) == "" {
		return c.Status(400).JSON(fiber.Map{"error": "referans kodu gereklidir"})
	}
	body.ReferralCode = strings.ToUpper(strings.TrimSpace(body.ReferralCode))

	// Referans kodunu doğrula
	refCode, err := h.referralRepo.FindActiveByCode(c.Context(), body.ReferralCode)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return c.Status(400).JSON(fiber.Map{"error": "geçersiz veya kullanılmış referans kodu"})
		}
		return fiber.ErrInternalServerError
	}

	hasPending, err := h.guideRepo.HasPendingApplication(c.Context(), userID)
	if err != nil {
		return fiber.ErrInternalServerError
	}
	if hasPending {
		return c.Status(409).JSON(fiber.Map{"error": "bekleyen bir başvurunuz zaten var"})
	}

	app := &models.GuideApplication{
		UserID:     userID,
		Status:     models.ApplicationStatusPending,
		ReferredBy: &refCode.GuideID,
	}
	if err := h.guideRepo.Create(c.Context(), app); err != nil {
		return fiber.ErrInternalServerError
	}

	// Kodu kullanılmış olarak işaretle
	if err := h.referralRepo.UseCode(c.Context(), refCode.ID, userID); err != nil {
		return fiber.ErrInternalServerError
	}

	// Guide'a yeni aktif kod üret
	if _, err := h.referralRepo.CreateCode(c.Context(), refCode.GuideID); err != nil {
		return fiber.ErrInternalServerError
	}

	return c.Status(201).JSON(app)
}

// GET /guide/my-venues — Guide'ın kendi eklediği mekanları listeler.
func (h *GuideHandler) MyVenues(c *fiber.Ctx) error {
	userID, err := getUserID(c)
	if err != nil {
		return err
	}
	venues, err := h.venueRepo.FindByAddedBy(c.Context(), userID)
	if err != nil {
		return fiber.ErrInternalServerError
	}
	return c.JSON(venues)
}

// GET /guide/my-referral-code — Guide'ın aktif referans kodunu döndürür.
func (h *GuideHandler) MyReferralCode(c *fiber.Ctx) error {
	userID, err := getUserID(c)
	if err != nil {
		return err
	}
	rc, err := h.referralRepo.GetActiveByGuideID(c.Context(), userID)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return c.Status(404).JSON(fiber.Map{"error": "aktif referans kodunuz bulunmuyor"})
		}
		return fiber.ErrInternalServerError
	}
	return c.JSON(fiber.Map{"referral_code": rc.Code})
}
