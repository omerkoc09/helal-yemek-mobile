package handlers

import (
	"context"
	"errors"
	"strings"

	"github.com/gofiber/fiber/v2"
	"github.com/omerkoc/caiz-mi/internal/models"
	"github.com/omerkoc/caiz-mi/internal/repository"
)

// reviewStore — ReviewHandler'ın ihtiyaç duyduğu minimal arayüz.
// *repository.ReviewRepo bunu otomatik karşılar; testte sahte uygulama kullanılır.
type reviewStore interface {
	ListByVenue(ctx context.Context, venueID string) ([]models.Review, error)
	Create(ctx context.Context, rv *models.Review) error
	Update(ctx context.Context, rv *models.Review) error
	Delete(ctx context.Context, id, userID string, isAdmin bool) error
}

type ReviewHandler struct {
	reviewRepo reviewStore
}

func NewReviewHandler(reviewRepo *repository.ReviewRepo) *ReviewHandler {
	return &ReviewHandler{reviewRepo: reviewRepo}
}

// GET /venues/:id/reviews
func (h *ReviewHandler) List(c *fiber.Ctx) error {
	venueID := c.Params("id")
	reviews, err := h.reviewRepo.ListByVenue(c.Context(), venueID)
	if err != nil {
		return fiber.ErrInternalServerError
	}
	return c.JSON(reviews)
}

// POST /venues/:id/reviews
func (h *ReviewHandler) Create(c *fiber.Ctx) error {
	venueID := c.Params("id")
	userID, err := getUserID(c)
	if err != nil {
		return err
	}

	var req struct {
		Rating  int     `json:"rating"`
		Comment *string `json:"comment"`
	}
	if err := c.BodyParser(&req); err != nil {
		return fiber.ErrBadRequest
	}
	if req.Rating < 1 || req.Rating > 5 {
		return c.Status(400).JSON(fiber.Map{"error": "puan 1-5 arasında olmalıdır"})
	}

	rv := &models.Review{
		VenueID: venueID,
		UserID:  userID,
		Rating:  req.Rating,
		Comment: req.Comment,
	}
	if err := h.reviewRepo.Create(c.Context(), rv); err != nil {
		// UNIQUE constraint (venue_id, user_id) ihlali
		if strings.Contains(err.Error(), "unique") || strings.Contains(err.Error(), "duplicate") {
			return c.Status(409).JSON(fiber.Map{"error": "bu mekana zaten yorum yapmışsınız"})
		}
		return fiber.ErrInternalServerError
	}
	return c.Status(201).JSON(rv)
}

// PUT /venues/:id/reviews/:reviewId
func (h *ReviewHandler) Update(c *fiber.Ctx) error {
	reviewID := c.Params("reviewId")
	userID, err := getUserID(c)
	if err != nil {
		return err
	}

	var req struct {
		Rating  int     `json:"rating"`
		Comment *string `json:"comment"`
	}
	if err := c.BodyParser(&req); err != nil {
		return fiber.ErrBadRequest
	}
	if req.Rating < 1 || req.Rating > 5 {
		return c.Status(400).JSON(fiber.Map{"error": "puan 1-5 arasında olmalıdır"})
	}

	rv := &models.Review{ID: reviewID, UserID: userID, Rating: req.Rating, Comment: req.Comment}
	if err := h.reviewRepo.Update(c.Context(), rv); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return fiber.ErrNotFound
		}
		return fiber.ErrInternalServerError
	}
	return c.JSON(rv)
}

// DELETE /venues/:id/reviews/:reviewId
func (h *ReviewHandler) Delete(c *fiber.Ctx) error {
	reviewID := c.Params("reviewId")
	userID, err := getUserID(c)
	if err != nil {
		return err
	}
	role := getUserRole(c)

	if err := h.reviewRepo.Delete(c.Context(), reviewID, userID, role == "admin"); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return fiber.ErrNotFound
		}
		return fiber.ErrInternalServerError
	}
	return c.SendStatus(204)
}
