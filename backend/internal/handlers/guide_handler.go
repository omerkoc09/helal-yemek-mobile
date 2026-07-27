package handlers

import (
	"context"
	"errors"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/omerkoc/caiz-mi/internal/models"
	"github.com/omerkoc/caiz-mi/internal/repository"
)

// guideStore — GuideHandler'ın başvuru akışında ihtiyaç duyduğu minimal arayüz.
type guideStore interface {
	HasPendingApplication(ctx context.Context, userID string) (bool, error)
	Create(ctx context.Context, app *models.GuideApplication) error
	FindLatestByUserID(ctx context.Context, userID string) (*models.GuideApplication, error)
}

// guideVenueLister — GuideHandler'ın mekan listeleri için ihtiyaç duyduğu metotlar.
type guideVenueLister interface {
	FindByAddedBy(ctx context.Context, userID string) ([]models.Venue, error)
	FindConfirmedBy(ctx context.Context, guideID string) ([]models.Venue, error)
}

type GuideHandler struct {
	guideRepo guideStore
	venueRepo guideVenueLister
}

func NewGuideHandler(guideRepo *repository.GuideRepo, venueRepo *repository.VenueRepo) *GuideHandler {
	return &GuideHandler{guideRepo: guideRepo, venueRepo: venueRepo}
}

// POST /guide/apply — Tek yol: şehir beyanı + terms kabul → admin onayına pending.
func (h *GuideHandler) Apply(c *fiber.Ctx) error {
	userID, err := getUserID(c)
	if err != nil {
		return err
	}
	if getUserRole(c) != string(models.RoleTraveler) {
		return c.Status(400).JSON(fiber.Map{"error": "yalnızca traveler kullanıcılar başvurabilir"})
	}

	var body struct {
		City          string `json:"city"`
		TermsAccepted bool   `json:"terms_accepted"`
	}
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "geçersiz istek"})
	}
	if !body.TermsAccepted {
		return c.Status(400).JSON(fiber.Map{"error": "rehberlik şartlarını kabul etmelisiniz"})
	}
	city, ok := models.NormalizeCity(body.City)
	if !ok {
		return c.Status(400).JSON(fiber.Map{"error": "geçerli bir şehir seçiniz"})
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
		City:            city,
		TermsAcceptedAt: &now,
	}
	if err := h.guideRepo.Create(c.Context(), app); err != nil {
		return fiber.ErrInternalServerError
	}
	return c.Status(201).JSON(fiber.Map{"status": "pending"})
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

// GET /guide/my-confirmations — Rehberin doğruladığı mekanlar (doğrulama tarihiyle).
// "Eklediklerim" ile ayrık bir listedir: ekleyen kişiye confirm akışı açılmadığı
// için bir mekan normalde iki listede birden görünmez.
func (h *GuideHandler) MyConfirmations(c *fiber.Ctx) error {
	userID, err := getUserID(c)
	if err != nil {
		return err
	}
	venues, err := h.venueRepo.FindConfirmedBy(c.Context(), userID)
	if err != nil {
		return fiber.ErrInternalServerError
	}
	return c.JSON(venues)
}

// GET /guide/my-application — Kullanıcının en güncel guide başvurusunu döndürür.
// Başvuru yoksa 404. Mobil, açılışta pending/rejected durumunu göstermek için kullanır.
func (h *GuideHandler) MyApplication(c *fiber.Ctx) error {
	userID, err := getUserID(c)
	if err != nil {
		return err
	}
	app, err := h.guideRepo.FindLatestByUserID(c.Context(), userID)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return c.Status(404).JSON(fiber.Map{"error": "başvurunuz bulunmuyor"})
		}
		return fiber.ErrInternalServerError
	}
	return c.JSON(fiber.Map{
		"status": app.Status,
		"note":   app.Note,
	})
}
