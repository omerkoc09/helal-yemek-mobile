package handlers

import (
	"github.com/gofiber/fiber/v2"
	"github.com/omerkoc/caiz-mi/internal/models"
	"github.com/omerkoc/caiz-mi/internal/repository"
)

type GuideHandler struct {
	guideRepo *repository.GuideRepo
	venueRepo *repository.VenueRepo
}

func NewGuideHandler(guideRepo *repository.GuideRepo, venueRepo *repository.VenueRepo) *GuideHandler {
	return &GuideHandler{guideRepo: guideRepo, venueRepo: venueRepo}
}

// POST /guide/apply — Traveler → Guide başvurusu gönderir.
func (h *GuideHandler) Apply(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	role, _ := c.Locals("userRole").(string)

	if role != string(models.RoleTraveler) {
		return c.Status(400).JSON(fiber.Map{"error": "yalnızca traveler kullanıcılar başvurabilir"})
	}

	hasPending, err := h.guideRepo.HasPendingApplication(c.Context(), userID)
	if err != nil {
		return fiber.ErrInternalServerError
	}
	if hasPending {
		return c.Status(409).JSON(fiber.Map{"error": "bekleyen bir başvurunuz zaten var"})
	}

	app := &models.GuideApplication{
		UserID: userID,
		Status: models.ApplicationStatusPending,
	}
	if err := h.guideRepo.Create(c.Context(), app); err != nil {
		return fiber.ErrInternalServerError
	}
	return c.Status(201).JSON(app)
}

// GET /guide/my-venues — Guide'ın kendi eklediği mekanları listeler.
func (h *GuideHandler) MyVenues(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	venues, err := h.venueRepo.FindByAddedBy(c.Context(), userID)
	if err != nil {
		return fiber.ErrInternalServerError
	}
	return c.JSON(venues)
}
