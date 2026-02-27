package handlers

import (
	"errors"

	"github.com/gofiber/fiber/v2"
	"github.com/omerkoc/caiz-mi/internal/repository"
)

type FavoriteHandler struct {
	favoriteRepo *repository.FavoriteRepo
}

func NewFavoriteHandler(favoriteRepo *repository.FavoriteRepo) *FavoriteHandler {
	return &FavoriteHandler{favoriteRepo: favoriteRepo}
}

// GET /favorites
func (h *FavoriteHandler) List(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	venues, err := h.favoriteRepo.ListByUser(c.Context(), userID)
	if err != nil {
		return fiber.ErrInternalServerError
	}
	return c.JSON(venues)
}

// POST /favorites/:venueId
func (h *FavoriteHandler) Add(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	venueID := c.Params("venueId")
	if err := h.favoriteRepo.Add(c.Context(), userID, venueID); err != nil {
		return fiber.ErrInternalServerError
	}
	return c.SendStatus(201)
}

// DELETE /favorites/:venueId
func (h *FavoriteHandler) Remove(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)
	venueID := c.Params("venueId")
	if err := h.favoriteRepo.Remove(c.Context(), userID, venueID); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return fiber.ErrNotFound
		}
		return fiber.ErrInternalServerError
	}
	return c.SendStatus(204)
}
