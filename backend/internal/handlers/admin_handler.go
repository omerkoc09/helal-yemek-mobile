package handlers

import (
	"errors"
	"log"

	"github.com/gofiber/fiber/v2"
	"github.com/omerkoc/caiz-mi/internal/models"
	"github.com/omerkoc/caiz-mi/internal/repository"
)

type AdminHandler struct {
	venueRepo *repository.VenueRepo
	guideRepo *repository.GuideRepo
	userRepo  *repository.UserRepo
	auditRepo *repository.AuditRepo
}

func NewAdminHandler(
	venueRepo *repository.VenueRepo,
	guideRepo *repository.GuideRepo,
	userRepo *repository.UserRepo,
	auditRepo *repository.AuditRepo,
) *AdminHandler {
	return &AdminHandler{
		venueRepo: venueRepo,
		guideRepo: guideRepo,
		userRepo:  userRepo,
		auditRepo: auditRepo,
	}
}

// writeAuditLog — audit kaydını yazar; hata olsa da isteği bloklamaz, sadece loglar.
func (h *AdminHandler) writeAuditLog(c *fiber.Ctx, action, targetType, targetID string, note *string) {
	adminID := c.Locals("userID").(string)
	l := &models.AuditLog{
		AdminID:    adminID,
		Action:     action,
		TargetType: targetType,
		TargetID:   targetID,
		Note:       note,
	}
	_ = h.auditRepo.Create(c.Context(), l)
}

// ── Venue ────────────────────────────────────────────────────────────────────

// GET /admin/venues
func (h *AdminHandler) ListAllVenues(c *fiber.Ctx) error {
	venues, err := h.venueRepo.FindAll(c.Context())
	if err != nil {
		log.Printf("[ADMIN] ListAllVenues error: %v", err)
		return fiber.ErrInternalServerError
	}
	return c.JSON(venues)
}

// DELETE /admin/venues/:id
func (h *AdminHandler) DeleteVenue(c *fiber.Ctx) error {
	id := c.Params("id")
	if err := h.venueRepo.SoftDelete(c.Context(), id); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return fiber.ErrNotFound
		}
		return fiber.ErrInternalServerError
	}
	h.writeAuditLog(c, "delete_venue", "venue", id, nil)
	return c.JSON(fiber.Map{"status": "deleted"})
}

// PUT /admin/venues/:id
func (h *AdminHandler) UpdateVenue(c *fiber.Ctx) error {
	venueID := c.Params("id")
	log.Printf("[ADMIN] UpdateVenue called for id=%s", venueID)

	var req struct {
		Name    *string `json:"name"`
		Address *string `json:"address"`
		City    *string `json:"city"`
		Status  *string `json:"status"`
		Notes   *string `json:"notes"`
	}
	if err := c.BodyParser(&req); err != nil {
		log.Printf("[ADMIN] UpdateVenue body parse error: %v", err)
		return fiber.ErrBadRequest
	}

	if err := h.venueRepo.UpdateVenue(c.Context(), venueID, req.Name, req.Address, req.City,
		nil, nil, req.Notes); err != nil {
		log.Printf("[ADMIN] UpdateVenue repo error for id=%s: %v", venueID, err)
		if errors.Is(err, repository.ErrNotFound) {
			return fiber.ErrNotFound
		}
		return fiber.ErrInternalServerError
	}

	// Status değişikliği
	if req.Status != nil {
		adminID := c.Locals("userID").(string)
		switch *req.Status {
		case "approved":
			_ = h.venueRepo.Approve(c.Context(), venueID, adminID)
		case "rejected":
			_ = h.venueRepo.Reject(c.Context(), venueID, adminID, nil)
		case "pending":
			_ = h.venueRepo.Suspend(c.Context(), venueID, adminID)
		}
	}

	h.writeAuditLog(c, "update_venue", "venue", venueID, nil)
	venue, err := h.venueRepo.FindByID(c.Context(), venueID)
	if err != nil {
		return fiber.ErrInternalServerError
	}
	return c.JSON(venue)
}

// GET /admin/venues/pending
func (h *AdminHandler) ListPendingVenues(c *fiber.Ctx) error {
	venues, err := h.venueRepo.FindPending(c.Context())
	if err != nil {
		return fiber.ErrInternalServerError
	}
	return c.JSON(venues)
}

// PUT /admin/venues/:id/approve
func (h *AdminHandler) ApproveVenue(c *fiber.Ctx) error {
	id := c.Params("id")
	adminID := c.Locals("userID").(string)

	if err := h.venueRepo.Approve(c.Context(), id, adminID); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return fiber.ErrNotFound
		}
		return fiber.ErrInternalServerError
	}

	h.writeAuditLog(c, "approve_venue", "venue", id, nil)
	return c.JSON(fiber.Map{"status": "approved"})
}

// PUT /admin/venues/:id/reject
// Body: {"note": "..."}
func (h *AdminHandler) RejectVenue(c *fiber.Ctx) error {
	id := c.Params("id")
	adminID := c.Locals("userID").(string)

	var req struct {
		Note *string `json:"note"`
	}
	// Body boş olabilir, parse hatasını yoksay
	_ = c.BodyParser(&req)

	if err := h.venueRepo.Reject(c.Context(), id, adminID, req.Note); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return fiber.ErrNotFound
		}
		return fiber.ErrInternalServerError
	}

	h.writeAuditLog(c, "reject_venue", "venue", id, req.Note)
	return c.JSON(fiber.Map{"status": "rejected"})
}

// ── Guide Başvuruları ─────────────────────────────────────────────────────────

// GET /admin/applications
func (h *AdminHandler) ListApplications(c *fiber.Ctx) error {
	list, err := h.guideRepo.ListPending(c.Context())
	if err != nil {
		return fiber.ErrInternalServerError
	}
	return c.JSON(list)
}

// PUT /admin/applications/:id/approve
func (h *AdminHandler) ApproveApplication(c *fiber.Ctx) error {
	id := c.Params("id")
	adminID := c.Locals("userID").(string)

	app, err := h.guideRepo.FindByID(c.Context(), id)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return fiber.ErrNotFound
		}
		return fiber.ErrInternalServerError
	}

	if err := h.guideRepo.UpdateStatus(c.Context(), id, adminID, models.ApplicationStatusApproved, nil); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return c.Status(409).JSON(fiber.Map{"error": "başvuru zaten incelenmiş"})
		}
		return fiber.ErrInternalServerError
	}

	// Kullanıcı rolünü guide'a yükselt
	if err := h.userRepo.UpdateRole(c.Context(), app.UserID, models.RoleGuide); err != nil {
		return fiber.ErrInternalServerError
	}

	h.writeAuditLog(c, "approve_guide_application", "guide_application", id, nil)
	return c.JSON(fiber.Map{"status": "approved"})
}

// PUT /admin/applications/:id/reject
// Body: {"note": "..."}
func (h *AdminHandler) RejectApplication(c *fiber.Ctx) error {
	id := c.Params("id")
	adminID := c.Locals("userID").(string)

	var req struct {
		Note *string `json:"note"`
	}
	if err := c.BodyParser(&req); err != nil {
		return fiber.ErrBadRequest
	}

	if err := h.guideRepo.UpdateStatus(c.Context(), id, adminID, models.ApplicationStatusRejected, req.Note); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return fiber.ErrNotFound
		}
		return fiber.ErrInternalServerError
	}

	h.writeAuditLog(c, "reject_guide_application", "guide_application", id, req.Note)
	return c.JSON(fiber.Map{"status": "rejected"})
}

// ── Audit Log ─────────────────────────────────────────────────────────────────

// GET /admin/audit-logs
func (h *AdminHandler) ListAuditLogs(c *fiber.Ctx) error {
	list, err := h.auditRepo.List(c.Context())
	if err != nil {
		return fiber.ErrInternalServerError
	}
	return c.JSON(list)
}

// ── Kullanıcılar ──────────────────────────────────────────────────────────────

// GET /admin/users
func (h *AdminHandler) ListUsers(c *fiber.Ctx) error {
	list, err := h.userRepo.List(c.Context())
	if err != nil {
		return fiber.ErrInternalServerError
	}
	return c.JSON(list)
}

// PUT /admin/users/:id
func (h *AdminHandler) UpdateUser(c *fiber.Ctx) error {
	id := c.Params("id")
	log.Printf("[ADMIN] UpdateUser called for id=%s", id)

	var req struct {
		Name     *string      `json:"name"`
		Email    *string      `json:"email"`
		Role     *models.Role `json:"role"`
		IsActive *bool        `json:"is_active"`
	}
	if err := c.BodyParser(&req); err != nil {
		log.Printf("[ADMIN] UpdateUser body parse error: %v", err)
		return fiber.ErrBadRequest
	}

	if err := h.userRepo.Update(c.Context(), id, req.Name, req.Email, req.Role, req.IsActive); err != nil {
		log.Printf("[ADMIN] UpdateUser repo error for id=%s: %v", id, err)
		if errors.Is(err, repository.ErrNotFound) {
			return fiber.ErrNotFound
		}
		return fiber.ErrInternalServerError
	}

	h.writeAuditLog(c, "update_user", "user", id, nil)

	user, err := h.userRepo.FindByID(c.Context(), id)
	if err != nil {
		log.Printf("[ADMIN] UpdateUser FindByID error for id=%s: %v", id, err)
		return fiber.ErrInternalServerError
	}
	return c.JSON(user)
}

// DELETE /admin/users/:id
func (h *AdminHandler) DeleteUser(c *fiber.Ctx) error {
	id := c.Params("id")

	// Admin kendini silemesin
	adminID := c.Locals("userID").(string)
	if id == adminID {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "kendi hesabınızı silemezsiniz"})
	}

	if err := h.userRepo.Delete(c.Context(), id); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return fiber.ErrNotFound
		}
		return fiber.ErrInternalServerError
	}

	h.writeAuditLog(c, "delete_user", "user", id, nil)
	return c.JSON(fiber.Map{"status": "deleted"})
}
