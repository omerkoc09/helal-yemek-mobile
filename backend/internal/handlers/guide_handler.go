package handlers

import (
	"errors"
	"strings"
	"time"

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

// POST /guide/apply — İki yol:
//  1. referral_code doluysa: geçerli kodla anında Guide olur (otomatik onay).
//  2. referral_code boşsa: terms_accepted ile admin onayına başvuru gönderir (pending).
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
		ReferralCode  string `json:"referral_code"`
		TermsAccepted bool   `json:"terms_accepted"`
	}
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "geçersiz istek"})
	}
	code := strings.ToUpper(strings.TrimSpace(body.ReferralCode))

	// Yol 2: Kodsuz başvuru (admin onayına pending).
	if code == "" {
		if !body.TermsAccepted {
			return c.Status(400).JSON(fiber.Map{"error": "rehberlik şartlarını kabul etmelisiniz"})
		}
		hasPending, err := h.guideRepo.HasPendingApplication(c.Context(), userID)
		if err != nil {
			return fiber.ErrInternalServerError
		}
		if hasPending {
			return c.Status(409).JSON(fiber.Map{"error": "bekleyen bir başvurunuz zaten var"})
		}
		now := time.Now()
		app := &models.GuideApplication{
			UserID:          userID,
			TermsAcceptedAt: &now,
		}
		if err := h.guideRepo.Create(c.Context(), app); err != nil {
			return fiber.ErrInternalServerError
		}
		return c.Status(201).JSON(fiber.Map{"status": "pending"})
	}

	// Yol 1: Kodlu başvuru (anında guide).
	refCode, err := h.referralRepo.FindActiveByCode(c.Context(), code)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return c.Status(400).JSON(fiber.Map{"error": "geçersiz referans kodu"})
		}
		return fiber.ErrInternalServerError
	}

	// Kendi kodunu kullanamaz (guardrail).
	if refCode.GuideID == userID {
		return c.Status(400).JSON(fiber.Map{"error": "kendi referans kodunuzu kullanamazsınız"})
	}

	// Tek transaction: başvuru kaydı + rol yükseltme + yeni kod üretimi.
	if err := h.referralRepo.ApproveGuideTx(c.Context(), userID, refCode.GuideID); err != nil {
		return fiber.ErrInternalServerError
	}

	return c.Status(201).JSON(fiber.Map{"status": "approved", "role": "guide"})
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
