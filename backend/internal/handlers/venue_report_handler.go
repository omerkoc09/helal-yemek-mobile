package handlers

import (
	"errors"

	"github.com/gofiber/fiber/v2"
	"github.com/omerkoc/caiz-mi/internal/models"
	"github.com/omerkoc/caiz-mi/internal/repository"
)

var validReasons = map[string]bool{
	"closed":        true,
	"halal_criteria": true,
	"wrong_address": true,
	"wrong_food":    true,
	"other":         true,
}

type VenueReportHandler struct {
	reportRepo *repository.VenueReportRepo
}

func NewVenueReportHandler(reportRepo *repository.VenueReportRepo) *VenueReportHandler {
	return &VenueReportHandler{reportRepo: reportRepo}
}

// POST /venues/:id/reports
func (h *VenueReportHandler) Create(c *fiber.Ctx) error {
	venueID := c.Params("id")
	userID, err := getUserID(c)
	if err != nil {
		return err
	}

	var req struct {
		Reason      string  `json:"reason"`
		Description *string `json:"description"`
	}
	if err := c.BodyParser(&req); err != nil {
		return fiber.ErrBadRequest
	}
	if !validReasons[req.Reason] {
		return c.Status(400).JSON(fiber.Map{"error": "geçersiz sebep"})
	}
	if req.Reason == "other" && (req.Description == nil || *req.Description == "") {
		return c.Status(400).JSON(fiber.Map{"error": "'diğer' seçeneği için açıklama zorunludur"})
	}

	rp := &models.VenueReport{
		VenueID:     venueID,
		UserID:      userID,
		Reason:      req.Reason,
		Description: req.Description,
	}
	if err := h.reportRepo.Create(c.Context(), rp); err != nil {
		return fiber.ErrInternalServerError
	}
	return c.Status(201).JSON(rp)
}

// GET /admin/venue-reports
func (h *VenueReportHandler) AdminList(c *fiber.Ctx) error {
	reports, err := h.reportRepo.List(c.Context())
	if err != nil {
		return fiber.ErrInternalServerError
	}
	return c.JSON(reports)
}

// PUT /admin/venue-reports/:id/resolve
func (h *VenueReportHandler) AdminResolve(c *fiber.Ctx) error {
	id := c.Params("id")
	if err := h.reportRepo.Resolve(c.Context(), id); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return fiber.ErrNotFound
		}
		return fiber.ErrInternalServerError
	}
	return c.SendStatus(204)
}
