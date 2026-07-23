package handlers

import (
	"errors"
	"log"
	"strings"

	"github.com/gofiber/fiber/v2"
	"github.com/omerkoc/caiz-mi/internal/models"
	"github.com/omerkoc/caiz-mi/internal/repository"
	"github.com/omerkoc/caiz-mi/internal/services"
)

// PlacePreview godoc
// GET /api/v1/venues/place-preview?place_id=ChIJ...  (Guide + Admin)
// GET /api/v1/venues/place-preview?lat=41.0&lng=29.0 (place_id yoksa koordinatla)
// Mekan adı, şehir ve semt bilgilerini döner.
// cityAllowanceFor — preview yanıtı için şehir-uygunluk bayrağını ve rehberin şehrini hesaplar.
// Guide olmayan roller için her zaman (true, nil) döner.
func (h *VenueHandler) cityAllowanceFor(c *fiber.Ctx, venueCity string) (bool, *string) {
	if getUserRole(c) != string(models.RoleGuide) {
		return true, nil
	}
	userID, err := getUserID(c)
	if err != nil {
		return true, nil
	}
	guideCity, err := h.userRepo.GetGuideCity(c.Context(), userID)
	if err != nil {
		return true, nil // okunamadıysa engelleme; Create katmanı yine korur
	}
	allowed, _ := services.CheckCityAllowed(guideCity, venueCity)
	return allowed, guideCity
}

// Create godoc
// POST /api/v1/venues  (Guide + Admin)
func (h *VenueHandler) Create(c *fiber.Ctx) error {
	userID, err := getUserID(c)
	if err != nil {
		return err
	}

	var req struct {
		Name             string   `json:"name"`
		City             string   `json:"city"`
		District         string   `json:"district"`
		Latitude         float64  `json:"latitude"`
		Longitude        float64  `json:"longitude"`
		GooglePlaceID    *string  `json:"google_place_id"`
		GooglePhotoURL   string   `json:"google_photo_url"`
		Notes            *string  `json:"notes"`
		CriteriaIDs      []int    `json:"criteria_ids"`
		FoodItemIDs      []int    `json:"food_item_ids"`
		FoodHalalMode    string   `json:"food_halal_mode"`
		ExcludedProducts []string `json:"excluded_products"`
	}
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "geçersiz istek gövdesi"})
	}

	if req.Name == "" || req.City == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "ad ve şehir zorunludur",
		})
	}
	if req.Latitude < -90 || req.Latitude > 90 || req.Longitude < -180 || req.Longitude > 180 {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "geçerli koordinat (latitude: -90..90, longitude: -180..180) zorunludur",
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

	// Google Place ID: istemci ChIJ... formatında gönderdiyse kullan.
	// 0x... (hex) formatı Maps URL'lerinde görünür ama Places API'de geçersizdir,
	// bu durumda Places API ile doğru ChIJ ID'sini resolve et.
	googlePlaceID := req.GooglePlaceID
	needsResolve := googlePlaceID == nil || *googlePlaceID == "" ||
		strings.HasPrefix(*googlePlaceID, "0x")
	if needsResolve && h.placesService != nil {
		if resolved := h.placesService.ResolvePlaceID(req.Name, req.Latitude, req.Longitude); resolved != "" {
			googlePlaceID = &resolved
		} else if needsResolve && googlePlaceID != nil && strings.HasPrefix(*googlePlaceID, "0x") {
			// Hex ID kullanılamaz, temizle
			googlePlaceID = nil
		}
	}

	// ChIJ place_id varsa city/district/name'i Places API'den otomatik doldur.
	// Flutter zaten preview'da gösterip teyit ettirmiş olacak; bu backend güvencesidir.
	city := req.City
	district := req.District
	if googlePlaceID != nil && strings.HasPrefix(*googlePlaceID, "ChIJ") && h.placesService != nil {
		if components, err := h.placesService.GetAddressComponents(*googlePlaceID); err == nil && components != nil {
			if components.City != "" {
				city = components.City
			}
			if components.District != "" {
				district = components.District
			}
		}
	}

	// Şehir kısıtı: rehber yalnızca kendi guide_city'sindeki mekanı ekleyebilir.
	// Admin muaftır. Belirsizlikte (guide_city NULL / şehir çözülemez) izin verilir.
	if getUserRole(c) == string(models.RoleGuide) {
		guideCity, gcErr := h.userRepo.GetGuideCity(c.Context(), userID)
		if gcErr != nil {
			return fiber.ErrInternalServerError
		}
		if allowed, resolved := services.CheckCityAllowed(guideCity, city); !allowed {
			return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
				"error": "Yalnızca rehberi olduğunuz şehirde mekan ekleyebilirsiniz. Bu mekan " +
					resolved + "'da görünüyor.",
			})
		}
	}

	venue := &models.Venue{
		Name:             req.Name,
		City:             city,
		Latitude:         req.Latitude,
		Longitude:        req.Longitude,
		GooglePlaceID:    googlePlaceID,
		Notes:            req.Notes,
		AddedBy:          userID,
		FoodHalalMode:    req.FoodHalalMode,
		ExcludedProducts: req.ExcludedProducts,
	}
	if district != "" {
		venue.District = &district
	}

	if err := h.venueRepo.Create(c.Context(), venue); err != nil {
		if errors.Is(err, repository.ErrAlreadyExists) {
			return c.Status(fiber.StatusConflict).JSON(fiber.Map{"error": "bu mekan zaten sisteme eklenmiş"})
		}
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "mekan eklenemedi"})
	}

	// Admin eklediği mekanlar otomatik onaylı olsun
	role := getUserRole(c)
	if role == "admin" {
		_ = h.venueRepo.Approve(c.Context(), venue.ID, userID, h.verificationPeriodDays)
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

	// Yemek çeşitlerini kaydet (tüm modlarda zorunlu)
	if len(req.FoodItemIDs) == 0 {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "en az bir yemek çeşidi seçilmelidir"})
	}
	if err := h.venueRepo.SetVenueFoodItems(c.Context(), venue.ID, req.FoodItemIDs); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "yemek çeşitleri kaydedilemedi"})
	}
	foodItems, _ := h.venueRepo.GetFoodItemsByVenueID(c.Context(), venue.ID)
	venue.FoodItems = foodItems

	// ExcludedProducts sadece except modunda anlamlı
	if venue.FoodHalalMode != "except" {
		venue.ExcludedProducts = []string{}
	}

	venue.Photos = []models.VenuePhoto{}
	if req.GooglePhotoURL != "" && h.storageService != nil {
		storedURL, err := h.storageService.DownloadAndStore(c.Context(), req.GooglePhotoURL)
		if err != nil {
			// Hata mekan oluşturmayı engellemiyor (fotoğraf opsiyonel), ama iz
			// bırakmadan yutulmamalı: SSRF guard'ın reddi de, allowlist'teki bir
			// boşluk da (ör. Google yeni CDN host'u) buradan görünür.
			log.Printf("[VENUE] google fotoğrafı alınamadı: %v", err)
		}
		if err == nil {
			photo := &models.VenuePhoto{
				VenueID:    venue.ID,
				URL:        storedURL,
				UploadedBy: userID,
				IsPrimary:  true,
			}
			if err := h.venueRepo.AddPhoto(c.Context(), photo); err == nil {
				venue.Photos = []models.VenuePhoto{*photo}
			}
		}
	}

	return c.Status(fiber.StatusCreated).JSON(venue)
}

// Update godoc
// PUT /api/v1/venues/:id  (Guide — kendi mekanı)
func (h *VenueHandler) Update(c *fiber.Ctx) error {
	venueID := c.Params("id")
	userID, err := getUserID(c)
	if err != nil {
		return err
	}
	role := getUserRole(c)

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
		City             *string   `json:"city"`
		District         *string   `json:"district"`
		Latitude         *float64  `json:"latitude"`
		Longitude        *float64  `json:"longitude"`
		GooglePlaceID    *string   `json:"google_place_id"`
		Notes            *string   `json:"notes"`
		CriteriaIDs      *[]int    `json:"criteria_ids"`
		FoodItemIDs      *[]int    `json:"food_item_ids"`
		FoodHalalMode    *string   `json:"food_halal_mode"`
		ExcludedProducts *[]string `json:"excluded_products"`
	}
	if err := c.BodyParser(&req); err != nil {
		return fiber.ErrBadRequest
	}

	// Koordinat değişmişse veya hex place_id gelmiş ise Places API ile resolve et
	googlePlaceID := req.GooglePlaceID
	if googlePlaceID != nil && strings.HasPrefix(*googlePlaceID, "0x") {
		name := venue.Name
		if req.Name != nil {
			name = *req.Name
		}
		lat := venue.Latitude
		if req.Latitude != nil {
			lat = *req.Latitude
		}
		lng := venue.Longitude
		if req.Longitude != nil {
			lng = *req.Longitude
		}
		if h.placesService != nil {
			if resolved := h.placesService.ResolvePlaceID(name, lat, lng); resolved != "" {
				googlePlaceID = &resolved
			} else {
				googlePlaceID = nil
			}
		} else {
			googlePlaceID = nil
		}
	}

	// ChIJ place_id varsa city/district'i Places API'den otomatik doldur
	if googlePlaceID != nil && strings.HasPrefix(*googlePlaceID, "ChIJ") && h.placesService != nil {
		if components, err := h.placesService.GetAddressComponents(*googlePlaceID); err == nil && components != nil {
			if components.City != "" {
				req.City = &components.City
			}
			if components.District != "" {
				req.District = &components.District
			}
		}
	}

	if err := h.venueRepo.UpdateVenue(c.Context(), venueID, req.Name, req.City, req.District,
		req.Latitude, req.Longitude, req.Notes, googlePlaceID); err != nil {
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
		mode := *req.FoodHalalMode
		if mode != "all" && mode != "except" && mode != "selected" {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
				"error": "food_halal_mode 'all', 'except' veya 'selected' olmalıdır",
			})
		}
		if err := h.venueRepo.SetFoodHalalMode(c.Context(), venueID, mode); err != nil {
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

// CreateCustomFoodItem godoc
// POST /api/v1/food-categories/:id/items
func (h *VenueHandler) CreateCustomFoodItem(c *fiber.Ctx) error {
	categoryID, err := c.ParamsInt("id")
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "geçersiz kategori ID"})
	}

	var req struct {
		Name string `json:"name"`
	}
	if err := c.BodyParser(&req); err != nil || req.Name == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "name zorunludur"})
	}

	// key oluştur: küçük harf, boşlukları _ ile değiştir
	key := strings.ToLower(strings.ReplaceAll(req.Name, " ", "_"))

	item, err := h.venueRepo.CreateCustomFoodItem(c.Context(), categoryID, key, req.Name)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "yemek çeşidi eklenemedi"})
	}
	return c.Status(fiber.StatusCreated).JSON(item)
}
