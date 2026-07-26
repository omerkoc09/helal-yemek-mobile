package handlers

import (
	"errors"
	"strconv"
	"strings"

	"github.com/gofiber/fiber/v2"
	"github.com/omerkoc/caiz-mi/internal/repository"
)

// GET /admin/food-categories
func (h *AdminHandler) ListFoodCategories(c *fiber.Ctx) error {
	categories, err := h.venueRepo.GetAllFoodCategoriesWithItems(c.Context())
	if err != nil {
		return fiber.ErrInternalServerError
	}
	return c.JSON(categories)
}

// POST /admin/food-categories
func (h *AdminHandler) CreateFoodCategory(c *fiber.Ctx) error {
	var req struct {
		Name string `json:"name"`
	}
	if err := c.BodyParser(&req); err != nil {
		return fiber.ErrBadRequest
	}
	req.Name = strings.TrimSpace(req.Name)
	if req.Name == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "name zorunludur"})
	}

	cat, err := h.venueRepo.CreateFoodCategory(c.Context(), slugifyKey(req.Name), req.Name)
	if err != nil {
		if errors.Is(err, repository.ErrAlreadyExists) {
			return c.Status(fiber.StatusConflict).JSON(fiber.Map{"error": "bu isimde bir kategori zaten mevcut"})
		}
		return fiber.ErrInternalServerError
	}

	h.writeAuditLog(c, "create_food_category", "food_category", strconv.Itoa(cat.ID), nil)
	return c.Status(fiber.StatusCreated).JSON(cat)
}

// POST /admin/food-categories/:id/image
func (h *AdminHandler) UploadFoodCategoryImage(c *fiber.Ctx) error {
	id, err := c.ParamsInt("id")
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "geçersiz kategori ID"})
	}

	fileHeader, err := c.FormFile("image")
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "image alanı gereklidir"})
	}

	file, err := fileHeader.Open()
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "dosya açılamadı"})
	}
	defer file.Close()

	oldImageURL, err := h.venueRepo.GetFoodCategoryImageURL(c.Context(), id)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return fiber.ErrNotFound
		}
		return fiber.ErrInternalServerError
	}

	url, err := h.storageService.Upload(c.Context(), file, fileHeader.Filename)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": err.Error()})
	}

	if err := h.venueRepo.SetFoodCategoryImage(c.Context(), id, url); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return fiber.ErrNotFound
		}
		return fiber.ErrInternalServerError
	}

	if oldImageURL != nil && *oldImageURL != "" {
		_ = h.storageService.Delete(c.Context(), *oldImageURL)
	}

	h.writeAuditLog(c, "update_food_category_image", "food_category", strconv.Itoa(id), nil)
	return c.JSON(fiber.Map{"image_url": url})
}

// PUT /admin/food-categories/:id
func (h *AdminHandler) UpdateFoodCategory(c *fiber.Ctx) error {
	id, err := c.ParamsInt("id")
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "geçersiz kategori ID"})
	}

	var req struct {
		Name string `json:"name"`
	}
	if err := c.BodyParser(&req); err != nil {
		return fiber.ErrBadRequest
	}
	req.Name = strings.TrimSpace(req.Name)
	if req.Name == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "name zorunludur"})
	}

	if err := h.venueRepo.UpdateFoodCategory(c.Context(), id, req.Name); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return fiber.ErrNotFound
		}
		return fiber.ErrInternalServerError
	}

	h.writeAuditLog(c, "update_food_category", "food_category", strconv.Itoa(id), nil)
	return c.JSON(fiber.Map{"status": "updated"})
}

// DELETE /admin/food-categories/:id
func (h *AdminHandler) DeleteFoodCategory(c *fiber.Ctx) error {
	id, err := c.ParamsInt("id")
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "geçersiz kategori ID"})
	}

	if err := h.venueRepo.DeleteFoodCategory(c.Context(), id); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return fiber.ErrNotFound
		}
		return fiber.ErrInternalServerError
	}

	h.writeAuditLog(c, "delete_food_category", "food_category", strconv.Itoa(id), nil)
	return c.JSON(fiber.Map{"status": "deleted"})
}

// GET /admin/trust-criteria
func (h *AdminHandler) ListTrustCriteria(c *fiber.Ctx) error {
	criteria, err := h.venueRepo.GetAllCriteria(c.Context())
	if err != nil {
		return fiber.ErrInternalServerError
	}
	return c.JSON(criteria)
}

// POST /admin/trust-criteria
func (h *AdminHandler) CreateTrustCriteria(c *fiber.Ctx) error {
	var req struct {
		Name        string  `json:"name"`
		Description *string `json:"description"`
	}
	if err := c.BodyParser(&req); err != nil {
		return fiber.ErrBadRequest
	}
	req.Name = strings.TrimSpace(req.Name)
	if req.Name == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "name zorunludur"})
	}

	criteria, err := h.venueRepo.CreateTrustCriteria(c.Context(), slugifyKey(req.Name), req.Name, req.Description)
	if err != nil {
		if errors.Is(err, repository.ErrAlreadyExists) {
			return c.Status(fiber.StatusConflict).JSON(fiber.Map{"error": "bu isimde bir kriter zaten mevcut"})
		}
		return fiber.ErrInternalServerError
	}

	h.writeAuditLog(c, "create_trust_criteria", "trust_criteria", strconv.Itoa(criteria.ID), nil)
	return c.Status(fiber.StatusCreated).JSON(criteria)
}

// PUT /admin/trust-criteria/:id
func (h *AdminHandler) UpdateTrustCriteria(c *fiber.Ctx) error {
	id, err := c.ParamsInt("id")
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "geçersiz kriter ID"})
	}

	var req struct {
		Name        string  `json:"name"`
		Description *string `json:"description"`
	}
	if err := c.BodyParser(&req); err != nil {
		return fiber.ErrBadRequest
	}
	req.Name = strings.TrimSpace(req.Name)
	if req.Name == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "name zorunludur"})
	}

	if err := h.venueRepo.UpdateTrustCriteria(c.Context(), id, req.Name, req.Description); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return fiber.ErrNotFound
		}
		return fiber.ErrInternalServerError
	}

	h.writeAuditLog(c, "update_trust_criteria", "trust_criteria", strconv.Itoa(id), nil)
	return c.JSON(fiber.Map{"status": "updated"})
}

// DELETE /admin/trust-criteria/:id
func (h *AdminHandler) DeleteTrustCriteria(c *fiber.Ctx) error {
	id, err := c.ParamsInt("id")
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "geçersiz kriter ID"})
	}

	if err := h.venueRepo.DeleteTrustCriteria(c.Context(), id); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return fiber.ErrNotFound
		}
		return fiber.ErrInternalServerError
	}

	h.writeAuditLog(c, "delete_trust_criteria", "trust_criteria", strconv.Itoa(id), nil)
	return c.JSON(fiber.Map{"status": "deleted"})
}

// POST /admin/food-categories/:id/items
func (h *AdminHandler) CreateFoodItem(c *fiber.Ctx) error {
	categoryID, err := c.ParamsInt("id")
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "geçersiz kategori ID"})
	}

	var req struct {
		Name string `json:"name"`
	}
	if err := c.BodyParser(&req); err != nil || strings.TrimSpace(req.Name) == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "name zorunludur"})
	}
	req.Name = strings.TrimSpace(req.Name)

	item, err := h.venueRepo.CreateCustomFoodItem(c.Context(), categoryID, slugifyKey(req.Name), req.Name)
	if err != nil {
		return fiber.ErrInternalServerError
	}

	h.writeAuditLog(c, "create_food_item", "food_item", strconv.Itoa(item.ID), nil)
	return c.Status(fiber.StatusCreated).JSON(item)
}

// PUT /admin/food-items/:id
func (h *AdminHandler) UpdateFoodItem(c *fiber.Ctx) error {
	id, err := c.ParamsInt("id")
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "geçersiz yemek çeşidi ID"})
	}

	var req struct {
		Name string `json:"name"`
	}
	if err := c.BodyParser(&req); err != nil {
		return fiber.ErrBadRequest
	}
	req.Name = strings.TrimSpace(req.Name)
	if req.Name == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "name zorunludur"})
	}

	if err := h.venueRepo.UpdateFoodItem(c.Context(), id, req.Name); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return fiber.ErrNotFound
		}
		return fiber.ErrInternalServerError
	}

	h.writeAuditLog(c, "update_food_item", "food_item", strconv.Itoa(id), nil)
	return c.JSON(fiber.Map{"status": "updated"})
}

// DELETE /admin/food-items/:id
func (h *AdminHandler) DeleteFoodItem(c *fiber.Ctx) error {
	id, err := c.ParamsInt("id")
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "geçersiz yemek çeşidi ID"})
	}

	if err := h.venueRepo.DeleteFoodItem(c.Context(), id); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return fiber.ErrNotFound
		}
		return fiber.ErrInternalServerError
	}

	h.writeAuditLog(c, "delete_food_item", "food_item", strconv.Itoa(id), nil)
	return c.JSON(fiber.Map{"status": "deleted"})
}
