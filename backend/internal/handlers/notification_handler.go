package handlers

import (
	"github.com/gofiber/fiber/v2"

	"github.com/omerkoc/caiz-mi/internal/models"
	"github.com/omerkoc/caiz-mi/internal/repository"
)

type NotificationHandler struct {
	notifRepo *repository.NotificationRepo
}

func NewNotificationHandler(notifRepo *repository.NotificationRepo) *NotificationHandler {
	return &NotificationHandler{notifRepo: notifRepo}
}

// GET /api/v1/notifications?page=1&limit=20
func (h *NotificationHandler) List(c *fiber.Ctx) error {
	userID, err := getUserID(c)
	if err != nil {
		return err
	}
	page := max(c.QueryInt("page", 1), 1)
	limit := min(c.QueryInt("limit", 20), 100)
	offset := (page - 1) * limit

	items, err := h.notifRepo.ListByUserID(c.Context(), userID, limit, offset)
	if err != nil {
		return fiber.ErrInternalServerError
	}
	if items == nil {
		items = []*models.Notification{} // nil yerine boş dizi döndür
	}
	return c.JSON(fiber.Map{"data": items, "page": page, "limit": limit})
}

// GET /api/v1/notifications/unread-count
func (h *NotificationHandler) UnreadCount(c *fiber.Ctx) error {
	userID, err := getUserID(c)
	if err != nil {
		return err
	}
	count, err := h.notifRepo.UnreadCount(c.Context(), userID)
	if err != nil {
		return fiber.ErrInternalServerError
	}
	return c.JSON(fiber.Map{"count": count})
}

// PUT /api/v1/notifications/:id/read
func (h *NotificationHandler) MarkRead(c *fiber.Ctx) error {
	userID, err := getUserID(c)
	if err != nil {
		return err
	}
	id := c.Params("id")
	if err := h.notifRepo.MarkRead(c.Context(), id, userID); err != nil {
		return fiber.ErrNotFound
	}
	return c.JSON(fiber.Map{"status": "ok"})
}

// PUT /api/v1/notifications/read-all
func (h *NotificationHandler) MarkAllRead(c *fiber.Ctx) error {
	userID, err := getUserID(c)
	if err != nil {
		return err
	}
	if err := h.notifRepo.MarkAllRead(c.Context(), userID); err != nil {
		return fiber.ErrInternalServerError
	}
	return c.JSON(fiber.Map{"status": "ok"})
}
