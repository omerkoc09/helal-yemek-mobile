package handlers

import (
	"context"
	"errors"

	"github.com/gofiber/fiber/v2"
	"github.com/omerkoc/itimat-mobile/internal/models"
	"github.com/omerkoc/itimat-mobile/internal/repository"
)

// favoriteStore — FavoriteHandler'ın ihtiyaç duyduğu minimal arayüz.
// *repository.FavoriteRepo bunu otomatik karşılar; testte sahte uygulama kullanılır.
type favoriteStore interface {
	ListByUser(ctx context.Context, userID string) ([]models.Venue, error)
	Add(ctx context.Context, userID, venueID string) error
	Remove(ctx context.Context, userID, venueID string) error
}

type FavoriteHandler struct {
	favoriteRepo favoriteStore
}

func NewFavoriteHandler(favoriteRepo *repository.FavoriteRepo) *FavoriteHandler {
	return &FavoriteHandler{favoriteRepo: favoriteRepo}
}

// GET /favorites
func (h *FavoriteHandler) List(c *fiber.Ctx) error {
	userID, err := getUserID(c)
	if err != nil {
		return err
	}
	venues, err := h.favoriteRepo.ListByUser(c.Context(), userID)
	if err != nil {
		return fiber.ErrInternalServerError
	}
	return c.JSON(venues)
}

// POST /favorites/:venueId
func (h *FavoriteHandler) Add(c *fiber.Ctx) error {
	userID, err := getUserID(c)
	if err != nil {
		return err
	}
	venueID := c.Params("venueId")
	if err := h.favoriteRepo.Add(c.Context(), userID, venueID); err != nil {
		return fiber.ErrInternalServerError
	}
	return c.SendStatus(201)
}

// DELETE /favorites/:venueId
func (h *FavoriteHandler) Remove(c *fiber.Ctx) error {
	userID, err := getUserID(c)
	if err != nil {
		return err
	}
	venueID := c.Params("venueId")
	if err := h.favoriteRepo.Remove(c.Context(), userID, venueID); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return fiber.ErrNotFound
		}
		return fiber.ErrInternalServerError
	}
	return c.SendStatus(204)
}
