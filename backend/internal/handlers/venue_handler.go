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
	venueRepo              *repository.VenueRepo
	storageService         *services.StorageService
	placesService          *services.PlacesService
	verifLogRepo           *repository.VerificationLogRepo
	verificationPeriodDays int
}

func NewVenueHandler(
	venueRepo *repository.VenueRepo,
	storageService *services.StorageService,
	placesService *services.PlacesService,
	verifLogRepo *repository.VerificationLogRepo,
	verificationPeriodDays int,
) *VenueHandler {
	return &VenueHandler{
		venueRepo:              venueRepo,
		storageService:         storageService,
		placesService:          placesService,
		verifLogRepo:           verifLogRepo,
		verificationPeriodDays: verificationPeriodDays,
	}
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
		lat := c.QueryFloat("lat", 0)
		lng := c.QueryFloat("lng", 0)
		limit := c.QueryInt("limit", 10)
		venues, err := h.venueRepo.FindByCity(c.Context(), city, lat, lng, limit)
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

// ListByCategory godoc
// GET /api/v1/venues/by-category/:categoryId?lat=41.0&lng=29.0&radius=5000
func (h *VenueHandler) ListByCategory(c *fiber.Ctx) error {
	categoryID, err := c.ParamsInt("categoryId")
	if err != nil || categoryID <= 0 {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "geçerli bir kategori ID gereklidir",
		})
	}

	latStr := c.Query("lat")
	lngStr := c.Query("lng")
	if latStr == "" || lngStr == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "lat ve lng parametreleri zorunludur",
		})
	}

	lat := c.QueryFloat("lat", 0)
	lng := c.QueryFloat("lng", 0)
	radius := c.QueryFloat("radius", 5000)

	venues, err := h.venueRepo.FindByFoodCategory(c.Context(), categoryID, lat, lng, radius)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "mekanlar listelenemedi"})
	}

	return c.JSON(fiber.Map{"data": venues, "count": len(venues)})
}

// PlacePreview godoc
// GET /api/v1/venues/place-preview?place_id=ChIJ...  (Guide + Admin)
// GET /api/v1/venues/place-preview?lat=41.0&lng=29.0 (place_id yoksa koordinatla)
// Mekan adı, şehir ve semt bilgilerini döner.
func (h *VenueHandler) PlacePreview(c *fiber.Ctx) error {
	if h.placesService == nil {
		return c.Status(fiber.StatusServiceUnavailable).JSON(fiber.Map{
			"error": "places servisi kullanılamıyor",
		})
	}

	placeID := c.Query("place_id")

	// ChIJ place_id varsa Place Details API'yi kullan
	if strings.HasPrefix(placeID, "ChIJ") {
		components, err := h.placesService.GetAddressComponents(placeID)
		if err != nil || components == nil {
			return c.Status(fiber.StatusUnprocessableEntity).JSON(fiber.Map{
				"error": "mekan bilgileri alınamadı",
			})
		}
		photoURLs := h.placesService.BuildPhotoURLs(components.PhotoReferences, 800)
		return c.JSON(fiber.Map{
			"name":       components.Name,
			"city":       components.City,
			"district":   components.District,
			"photo_urls": photoURLs,
		})
	}

	// ChIJ yoksa: ad + koordinatla place_id bul, ardından adres detaylarını çek
	latStr := c.Query("lat")
	lngStr := c.Query("lng")
	if latStr == "" || lngStr == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "place_id (ChIJ formatı) veya lat+lng parametresi gereklidir",
		})
	}
	lat := c.QueryFloat("lat", 0)
	lng := c.QueryFloat("lng", 0)
	name := c.Query("name") // URL'den parse edilen mekan adı

	if name == "" {
		return c.Status(fiber.StatusUnprocessableEntity).JSON(fiber.Map{
			"error": "mekan adı bulunamadı, il/ilçe bilgisi çekilemiyor",
		})
	}

	resolved := h.placesService.ResolvePlaceID(name, lat, lng)
	if resolved == "" {
		return c.Status(fiber.StatusUnprocessableEntity).JSON(fiber.Map{
			"error": "mekan bulunamadı",
		})
	}

	components, err := h.placesService.GetAddressComponents(resolved)
	if err != nil || components == nil {
		return c.Status(fiber.StatusUnprocessableEntity).JSON(fiber.Map{
			"error": "mekan adres bilgileri alınamadı",
		})
	}

	photoURLs := h.placesService.BuildPhotoURLs(components.PhotoReferences, 800)
	return c.JSON(fiber.Map{
		"name":       components.Name,
		"city":       components.City,
		"district":   components.District,
		"photo_urls": photoURLs,
	})
}

// ListNearby godoc
// GET /api/v1/venues/nearby?lat=41.0&lng=29.0&radius=10000&limit=10
func (h *VenueHandler) ListNearby(c *fiber.Ctx) error {
	latStr := c.Query("lat")
	lngStr := c.Query("lng")
	if latStr == "" || lngStr == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "lat ve lng parametreleri zorunludur",
		})
	}
	lat := c.QueryFloat("lat", 0)
	lng := c.QueryFloat("lng", 0)
	radius := c.QueryFloat("radius", 10000)
	limit := c.QueryInt("limit", 10)

	venues, err := h.venueRepo.FindNearbyApproved(c.Context(), lat, lng, radius, limit)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "mekanlar listelenemedi"})
	}
	return c.JSON(fiber.Map{"data": venues, "count": len(venues)})
}

// ListPopular godoc
// GET /api/v1/venues/popular?lat=41.0&lng=29.0&radius=10000&limit=10
func (h *VenueHandler) ListPopular(c *fiber.Ctx) error {
	latStr := c.Query("lat")
	lngStr := c.Query("lng")
	if latStr == "" || lngStr == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "lat ve lng parametreleri zorunludur",
		})
	}
	lat := c.QueryFloat("lat", 0)
	lng := c.QueryFloat("lng", 0)
	radius := c.QueryFloat("radius", 10000)
	limit := c.QueryInt("limit", 10)

	venues, err := h.venueRepo.FindPopular(c.Context(), lat, lng, radius, limit)
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
	userID, err := getUserID(c)
	if err != nil {
		return err
	}

	var req struct {
		Name             string   `json:"name"`
		Address          string   `json:"address"`
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

	// address alanı yoksa district'i fallback olarak kullan
	address := req.Address
	if address == "" {
		address = district
	}

	venue := &models.Venue{
		Name:             req.Name,
		Address:          address,
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
		if storedURL, err := h.storageService.DownloadAndStore(c.Context(), req.GooglePhotoURL); err == nil {
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

// UploadPhoto godoc
// POST /api/v1/venues/:id/photos  (Guide + Admin)
func (h *VenueHandler) UploadPhoto(c *fiber.Ctx) error {
	venueID := c.Params("id")
	userID, err := getUserID(c)
	if err != nil {
		return err
	}

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
	guideID, err := getUserID(c)
	if err != nil {
		return err
	}

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
		Address          *string   `json:"address"`
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

	if err := h.venueRepo.UpdateVenue(c.Context(), venueID, req.Name, req.Address, req.City, req.District,
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

// ListCities godoc
// GET /api/v1/venues/cities
func (h *VenueHandler) ListCities(c *fiber.Ctx) error {
	cities, err := h.venueRepo.FindDistinctCities(c.Context())
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "şehirler listelenemedi"})
	}
	return c.JSON(fiber.Map{"data": cities})
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

// PUT /api/v1/venues/:id/verify
// Rehber kendi mekanının hâlâ helal olduğunu teyit eder.
func (h *VenueHandler) Verify(c *fiber.Ctx) error {
	venueID := c.Params("id")
	guideID, err := getUserID(c)
	if err != nil {
		return err
	}

	if err := h.venueRepo.VerifyByGuide(c.Context(), venueID, guideID, h.verificationPeriodDays); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return fiber.ErrNotFound
		}
		return fiber.ErrInternalServerError
	}

	_ = h.verifLogRepo.Create(c.Context(), venueID, guideID, "verified")

	return c.JSON(fiber.Map{"status": "verified"})
}
