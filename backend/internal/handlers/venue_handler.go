package handlers

import (
	"errors"
	"strings"

	"github.com/gofiber/fiber/v2"

	"github.com/omerkoc/caiz-mi/internal/models"
	"github.com/omerkoc/caiz-mi/internal/repository"
	"github.com/omerkoc/caiz-mi/internal/services"
)

type VenueHandler struct {
	venueRepo      *repository.VenueRepo
	storageService *services.StorageService
}

func NewVenueHandler(venueRepo *repository.VenueRepo, storageService *services.StorageService) *VenueHandler {
	return &VenueHandler{venueRepo: venueRepo, storageService: storageService}
}

// List godoc
// GET /api/v1/venues?q=keyword
// GET /api/v1/venues?lat=41.0&lng=29.0&radius=5000
// GET /api/v1/venues?city=Istanbul
func (h *VenueHandler) List(c *fiber.Ctx) error {
	q := c.Query("q")

	if q != "" {
		venues, err := h.venueRepo.SearchByText(c.Context(), q)
		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "arama başarısız"})
		}
		return c.JSON(fiber.Map{"data": venues, "count": len(venues)})
	}

	city := c.Query("city")

	if city != "" {
		venues, err := h.venueRepo.FindByCity(c.Context(), city)
		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "mekanlar listelenemedi"})
		}
		return c.JSON(fiber.Map{"data": venues, "count": len(venues)})
	}

	latStr := c.Query("lat")
	lngStr := c.Query("lng")
	if latStr == "" || lngStr == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "city veya lat+lng parametresi gereklidir",
		})
	}
	lat := c.QueryFloat("lat", 0)
	lng := c.QueryFloat("lng", 0)
	radius := c.QueryFloat("radius", 5000)

	venues, err := h.venueRepo.FindNearby(c.Context(), lat, lng, radius)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "mekanlar listelenemedi"})
	}
	return c.JSON(fiber.Map{"data": venues, "count": len(venues)})
}

// Detail godoc
// GET /api/v1/venues/:id
func (h *VenueHandler) Detail(c *fiber.Ctx) error {
	id := c.Params("id")
	venue, err := h.venueRepo.FindByID(c.Context(), id)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "mekan bulunamadı"})
		}
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "mekan detayı alınamadı"})
	}
	return c.JSON(venue)
}

// Create godoc
// POST /api/v1/venues  (Guide + Admin)
func (h *VenueHandler) Create(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)

	var req struct {
		Name             string   `json:"name"`
		Address          string   `json:"address"`
		City             string   `json:"city"`
		Latitude         float64  `json:"latitude"`
		Longitude        float64  `json:"longitude"`
		Notes            *string  `json:"notes"`
		CriteriaIDs      []int    `json:"criteria_ids"`
		FoodItemIDs      []int    `json:"food_item_ids"`
		FoodHalalMode    string   `json:"food_halal_mode"`
		ExcludedProducts []string `json:"excluded_products"`
	}
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "geçersiz istek gövdesi"})
	}

	if req.Name == "" || req.Address == "" || req.City == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "ad, adres ve şehir zorunludur",
		})
	}
	if req.Latitude == 0 || req.Longitude == 0 {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "geçerli koordinat (latitude, longitude) zorunludur",
		})
	}

	// food_halal_mode varsayılan değer
	if req.FoodHalalMode == "" {
		req.FoodHalalMode = "selected"
	}
	if req.FoodHalalMode != "all" && req.FoodHalalMode != "except" && req.FoodHalalMode != "selected" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "food_halal_mode 'all', 'except' veya 'selected' olmalıdır",
		})
	}

	venue := &models.Venue{
		Name:             req.Name,
		Address:          req.Address,
		City:             req.City,
		Latitude:         req.Latitude,
		Longitude:        req.Longitude,
		Notes:            req.Notes,
		AddedBy:          userID,
		FoodHalalMode:    req.FoodHalalMode,
		ExcludedProducts: req.ExcludedProducts,
	}

	if err := h.venueRepo.Create(c.Context(), venue); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "mekan eklenemedi"})
	}

	// Admin eklediği mekanlar otomatik onaylı olsun
	role, _ := c.Locals("userRole").(string)
	if role == "admin" {
		_ = h.venueRepo.Approve(c.Context(), venue.ID, userID)
		venue.Status = "approved"
	}

	if len(req.CriteriaIDs) > 0 {
		if err := h.venueRepo.SetCriteria(c.Context(), venue.ID, req.CriteriaIDs); err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "kriterler kaydedilemedi"})
		}
		criteria, _ := h.venueRepo.GetCriteriaByVenueID(c.Context(), venue.ID)
		venue.Criteria = criteria
	} else {
		venue.Criteria = []models.HalalCriteria{}
	}

	// Yemek çeşitlerini mod bazlı kaydet
	switch venue.FoodHalalMode {
	case "all":
		venue.FoodItems = []models.FoodItem{}
		venue.ExcludedProducts = []string{}
	case "except":
		// Sakıncalı ürünler zaten venue'da kayıtlı; yemek çeşitleri kaydedilmez
		venue.FoodItems = []models.FoodItem{}
	default: // "selected"
		venue.ExcludedProducts = []string{}
		if len(req.FoodItemIDs) > 0 {
			if err := h.venueRepo.SetVenueFoodItems(c.Context(), venue.ID, req.FoodItemIDs); err != nil {
				return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "yemek çeşitleri kaydedilemedi"})
			}
			foodItems, _ := h.venueRepo.GetFoodItemsByVenueID(c.Context(), venue.ID)
			venue.FoodItems = foodItems
		} else {
			venue.FoodItems = []models.FoodItem{}
		}
	}
	venue.Photos = []models.VenuePhoto{}

	return c.Status(fiber.StatusCreated).JSON(venue)
}

// UploadPhoto godoc
// POST /api/v1/venues/:id/photos  (Guide + Admin)
func (h *VenueHandler) UploadPhoto(c *fiber.Ctx) error {
	venueID := c.Params("id")
	userID := c.Locals("userID").(string)

	// Mekanın var olup olmadığını kontrol et
	if _, err := h.venueRepo.FindByID(c.Context(), venueID); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "mekan bulunamadı"})
		}
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "mekan doğrulanamadı"})
	}

	fileHeader, err := c.FormFile("photo")
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "photo alanı gereklidir"})
	}

	file, err := fileHeader.Open()
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "dosya açılamadı"})
	}
	defer file.Close()

	url, err := h.storageService.Upload(c.Context(), file, fileHeader.Filename)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": err.Error()})
	}

	photo := &models.VenuePhoto{
		VenueID:    venueID,
		URL:        url,
		UploadedBy: userID,
	}
	if err := h.venueRepo.AddPhoto(c.Context(), photo); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "fotoğraf kaydedilemedi"})
	}

	return c.Status(fiber.StatusCreated).JSON(photo)
}

// DeletePhoto godoc
// DELETE /api/v1/venues/:id/photos/:photoId  (Guide/Admin)
func (h *VenueHandler) DeletePhoto(c *fiber.Ctx) error {
	venueID := c.Params("id")
	photoID := c.Params("photoId")

	photo, err := h.venueRepo.FindPhotoByID(c.Context(), photoID)
	if err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "fotoğraf bulunamadı"})
	}

	if err := h.venueRepo.DeletePhoto(c.Context(), photoID, venueID); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "fotoğraf silinemedi"})
	}

	// Fiziksel dosyayı da sil
	_ = h.storageService.Delete(c.Context(), photo.URL)

	return c.SendStatus(fiber.StatusNoContent)
}

// ConfirmVenue godoc
// POST /api/v1/venues/:id/confirm  (Guide)
func (h *VenueHandler) ConfirmVenue(c *fiber.Ctx) error {
	venueID := c.Params("id")
	guideID := c.Locals("userID").(string)

	if err := h.venueRepo.ConfirmVenue(c.Context(), venueID, guideID); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "mekan bulunamadı"})
		}
		msg := err.Error()
		if strings.Contains(msg, "doğrulamışsınız") ||
			strings.Contains(msg, "kendi eklediğiniz") ||
			strings.Contains(msg, "yalnızca onaylı") {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": msg})
		}
		return fiber.ErrInternalServerError
	}
	return c.JSON(fiber.Map{"status": "confirmed"})
}

// Update godoc
// PUT /api/v1/venues/:id  (Guide — kendi mekanı)
func (h *VenueHandler) Update(c *fiber.Ctx) error {
	venueID := c.Params("id")
	userID := c.Locals("userID").(string)
	role, _ := c.Locals("userRole").(string)

	venue, err := h.venueRepo.FindByID(c.Context(), venueID)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "mekan bulunamadı"})
		}
		return fiber.ErrInternalServerError
	}

	// Sadece mekanı ekleyen guide veya admin güncelleyebilir
	if venue.AddedBy != userID && role != "admin" {
		return c.Status(fiber.StatusForbidden).JSON(fiber.Map{"error": "bu mekanı güncelleme yetkiniz yok"})
	}

	var req struct {
		Name             *string   `json:"name"`
		Address          *string   `json:"address"`
		City             *string   `json:"city"`
		Latitude         *float64  `json:"latitude"`
		Longitude        *float64  `json:"longitude"`
		Notes            *string   `json:"notes"`
		CriteriaIDs      *[]int    `json:"criteria_ids"`
		FoodItemIDs      *[]int    `json:"food_item_ids"`
		FoodHalalMode    *string   `json:"food_halal_mode"`
		ExcludedProducts *[]string `json:"excluded_products"`
	}
	if err := c.BodyParser(&req); err != nil {
		return fiber.ErrBadRequest
	}

	if err := h.venueRepo.UpdateVenue(c.Context(), venueID, req.Name, req.Address, req.City,
		req.Latitude, req.Longitude, req.Notes); err != nil {
		return fiber.ErrInternalServerError
	}

	if req.CriteriaIDs != nil {
		if err := h.venueRepo.SetCriteria(c.Context(), venueID, *req.CriteriaIDs); err != nil {
			return fiber.ErrInternalServerError
		}
	}

	if req.FoodItemIDs != nil {
		if err := h.venueRepo.SetVenueFoodItems(c.Context(), venueID, *req.FoodItemIDs); err != nil {
			return fiber.ErrInternalServerError
		}
	}

	if req.FoodHalalMode != nil {
		if err := h.venueRepo.SetFoodHalalMode(c.Context(), venueID, *req.FoodHalalMode); err != nil {
			return fiber.ErrInternalServerError
		}
	}
	if req.ExcludedProducts != nil {
		if err := h.venueRepo.SetExcludedProducts(c.Context(), venueID, *req.ExcludedProducts); err != nil {
			return fiber.ErrInternalServerError
		}
	}

	// Guide düzenlemesi sonrası onaylı mekanı tekrar onaya gönder
	if role != "admin" && venue.Status == models.VenueStatusApproved {
		_ = h.venueRepo.ResetToPending(c.Context(), venueID)
	}

	updated, err := h.venueRepo.FindByID(c.Context(), venueID)
	if err != nil {
		return fiber.ErrInternalServerError
	}
	return c.JSON(updated)
}

// ListFoodCategories godoc
// GET /api/v1/food-categories
func (h *VenueHandler) ListFoodCategories(c *fiber.Ctx) error {
	categories, err := h.venueRepo.GetAllFoodCategoriesWithItems(c.Context())
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "yemek kategorileri listelenemedi"})
	}
	return c.JSON(categories)
}

// CreateCustomFoodItem godoc
// POST /api/v1/food-categories/:id/items
func (h *VenueHandler) CreateCustomFoodItem(c *fiber.Ctx) error {
	categoryID, err := c.ParamsInt("id")
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "geçersiz kategori ID"})
	}

	var req struct {
		LabelTR string `json:"label_tr"`
	}
	if err := c.BodyParser(&req); err != nil || req.LabelTR == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "label_tr zorunludur"})
	}

	// key oluştur: küçük harf, boşlukları _ ile değiştir
	key := strings.ToLower(strings.ReplaceAll(req.LabelTR, " ", "_"))

	item, err := h.venueRepo.CreateCustomFoodItem(c.Context(), categoryID, key, req.LabelTR)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "yemek çeşidi eklenemedi"})
	}
	return c.Status(fiber.StatusCreated).JSON(item)
}

// ListCriteria godoc
// GET /api/v1/criteria
func (h *VenueHandler) ListCriteria(c *fiber.Ctx) error {
	criteria, err := h.venueRepo.GetAllCriteria(c.Context())
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "kriterler listelenemedi"})
	}
	return c.JSON(criteria)
}
