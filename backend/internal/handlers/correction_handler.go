package handlers

import (
	"errors"

	"github.com/gofiber/fiber/v2"
	"github.com/omerkoc/caiz-mi/internal/models"
	"github.com/omerkoc/caiz-mi/internal/repository"
)

type CorrectionHandler struct {
	correctionRepo *repository.CorrectionRepo
	auditRepo      *repository.AuditRepo
}

func NewCorrectionHandler(correctionRepo *repository.CorrectionRepo, auditRepo *repository.AuditRepo) *CorrectionHandler {
	return &CorrectionHandler{correctionRepo: correctionRepo, auditRepo: auditRepo}
}

// POST /venues/:id/corrections — Guide
func (h *CorrectionHandler) Create(c *fiber.Ctx) error {
	venueID := c.Params("id")
	userID, err := getUserID(c)
	if err != nil {
		return err
	}

	var req struct {
		FieldName string  `json:"field_name"`
		OldValue  *string `json:"old_value"`
		NewValue  string  `json:"new_value"`
	}
	if err := c.BodyParser(&req); err != nil {
		return fiber.ErrBadRequest
	}
	if req.FieldName == "" || req.NewValue == "" {
		return c.Status(400).JSON(fiber.Map{"error": "field_name ve new_value zorunludur"})
	}

	cs := &models.CorrectionSuggestion{
		VenueID:     venueID,
		SuggestedBy: userID,
		FieldName:   req.FieldName,
		OldValue:    req.OldValue,
		NewValue:    req.NewValue,
		Status:      models.CorrectionStatusPending,
	}
	if err := h.correctionRepo.Create(c.Context(), cs); err != nil {
		return fiber.ErrInternalServerError
	}
	return c.Status(201).JSON(cs)
}

// GET /admin/corrections — Admin: bekleyen düzeltme önerileri
func (h *CorrectionHandler) ListPending(c *fiber.Ctx) error {
	list, err := h.correctionRepo.ListPending(c.Context())
	if err != nil {
		return fiber.ErrInternalServerError
	}
	return c.JSON(list)
}

// PUT /admin/corrections/:id — Admin: onayla veya reddet
// Body: {"action": "approve"|"reject", "note": "..."}
func (h *CorrectionHandler) Review(c *fiber.Ctx) error {
	id := c.Params("id")
	adminID, err := getUserID(c)
	if err != nil {
		return err
	}

	var req struct {
		Action string  `json:"action"` // "approve" | "reject"
		Note   *string `json:"note"`
	}
	if err := c.BodyParser(&req); err != nil {
		return fiber.ErrBadRequest
	}
	if req.Action != "approve" && req.Action != "reject" {
		return c.Status(400).JSON(fiber.Map{"error": "action 'approve' veya 'reject' olmalıdır"})
	}

	_, err = h.correctionRepo.FindByID(c.Context(), id)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return fiber.ErrNotFound
		}
		return fiber.ErrInternalServerError
	}

	status := models.CorrectionStatusApproved
	if req.Action == "reject" {
		status = models.CorrectionStatusRejected
	}

	if err := h.correctionRepo.UpdateStatus(c.Context(), id, adminID, status, req.Note); err != nil {
		return fiber.ErrInternalServerError
	}

	// Audit log
	action := "approve_correction"
	if req.Action == "reject" {
		action = "reject_correction"
	}
	l := &models.AuditLog{
		AdminID:    adminID,
		Action:     action,
		TargetType: "correction",
		TargetID:   id,
		Note:       req.Note,
	}
	_ = h.auditRepo.Create(c.Context(), l)

	return c.JSON(fiber.Map{"status": status})
}
