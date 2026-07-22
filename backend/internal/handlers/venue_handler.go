package handlers

import (
	"context"
	"errors"
	"log"
	"strings"

	"github.com/gofiber/fiber/v2"

	"github.com/omerkoc/caiz-mi/internal/models"
	"github.com/omerkoc/caiz-mi/internal/repository"
	"github.com/omerkoc/caiz-mi/internal/services"
)

// guideCityGetter — VenueHandler'ın guide_city sorgusunda ihtiyaç duyduğu minimal arayüz.
// *repository.UserRepo bu arayüzü otomatik olarak karşılar; testte sahte (fake) uygulamalar kullanılabilir.
type guideCityGetter interface {
	GetGuideCity(ctx context.Context, userID string) (*string, error)
}

// directionClickCreator — yol tarifi tıklamasını kaydeden minimal arayüz.
// *repository.DirectionClickRepo bu arayüzü otomatik olarak karşılar; testte sahte uygulamalar kullanılabilir.
type directionClickCreator interface {
	Create(ctx context.Context, venueID string, userID *string) error
}

// venueStore — VenueHandler'ın VenueRepo'dan kullandığı metotlar.
//
// Arayüzün bu kadar geniş olması bir tasarım sinyali: VenueHandler 20 endpoint
// ile mekan CRUD, fotoğraf, kriter, yemek kalemi, onaylama ve doğrulama
// sorumluluklarını birlikte taşıyor. Handler mantıksal parçalara bölündüğünde
// bu arayüz de doğal olarak küçük parçalara ayrılmalı (bkz. docs/progress.md).
type venueStore interface {
	// Okuma / listeleme
	FindByID(ctx context.Context, id string) (*models.Venue, error)
	FindByCity(ctx context.Context, city string, lat, lng float64, limit int) ([]models.Venue, error)
	FindByFoodCategory(ctx context.Context, categoryID int) ([]models.Venue, error)
	FindByGooglePlaceID(ctx context.Context, placeID string) (*models.Venue, error)
	FindNearby(ctx context.Context, lat, lng, radiusMeters float64) ([]models.Venue, error)
	FindNearbyApproved(ctx context.Context, lat, lng, radiusMeters float64, limit int) ([]models.Venue, error)
	FindPopular(ctx context.Context, lat, lng, radiusMeters float64, limit int) ([]models.Venue, error)
	FindDistinctCities(ctx context.Context) ([]string, error)
	SearchByText(ctx context.Context, query string) ([]models.Venue, error)

	// Yazma
	Create(ctx context.Context, v *models.Venue) error
	UpdateVenue(ctx context.Context, id string, name, city, district *string, lat, lng *float64, notes *string, googlePlaceID *string) error
	Approve(ctx context.Context, id, adminID string, periodDays int) error
	ResetToPending(ctx context.Context, id string) error

	// Fotoğraf
	AddPhoto(ctx context.Context, photo *models.VenuePhoto) error
	DeletePhoto(ctx context.Context, photoID, venueID string) error
	FindPhotoByID(ctx context.Context, photoID string) (*models.VenuePhoto, error)
	GetPhotosByVenueID(ctx context.Context, venueID string) ([]models.VenuePhoto, error)

	// Kriter ve yemek
	GetAllCriteria(ctx context.Context) ([]models.HalalCriteria, error)
	GetCriteriaByVenueID(ctx context.Context, venueID string) ([]models.HalalCriteria, error)
	SetCriteria(ctx context.Context, venueID string, criteriaIDs []int) error
	GetAllFoodCategoriesWithItems(ctx context.Context) ([]models.FoodCategory, error)
	GetFoodItemsByVenueID(ctx context.Context, venueID string) ([]models.FoodItem, error)
	SetVenueFoodItems(ctx context.Context, venueID string, foodItemIDs []int) error
	CreateCustomFoodItem(ctx context.Context, categoryID int, key, name string) (*models.FoodItem, error)
	SetFoodHalalMode(ctx context.Context, venueID string, mode string) error
	SetExcludedProducts(ctx context.Context, venueID string, products []string) error

	// Onaylama / dönemsel doğrulama
	ConfirmVenue(ctx context.Context, venueID, guideID, guideCity string) error
	HasConfirmed(ctx context.Context, venueID, guideID string) (bool, error)
	VerifyByGuide(ctx context.Context, venueID, guideID string, periodDays int) ([]string, error)
}

// verificationLogger — doğrulama/onay eylemlerinin iz kaydını yazar.
type verificationLogger interface {
	Create(ctx context.Context, venueID, guideID, action string) error
}

// confirmationResetNotifier — dönemsel onayı sıfırlanan rehberleri bilgilendirir.
type confirmationResetNotifier interface {
	SendConfirmationReset(ctx context.Context, guideID, venueID, venueName string) error
}

type VenueHandler struct {
	venueRepo              venueStore
	userRepo               guideCityGetter
	storageService         *services.StorageService
	placesService          *services.PlacesService
	verifLogRepo           verificationLogger
	directionRepo          directionClickCreator
	notifService           confirmationResetNotifier
	verificationPeriodDays int
}

func NewVenueHandler(
	venueRepo *repository.VenueRepo,
	userRepo *repository.UserRepo,
	storageService *services.StorageService,
	placesService *services.PlacesService,
	verifLogRepo *repository.VerificationLogRepo,
	directionRepo *repository.DirectionClickRepo,
	notifService *services.NotificationService,
	verificationPeriodDays int,
) *VenueHandler {
	h := &VenueHandler{
		venueRepo:              venueRepo,
		userRepo:               userRepo,
		storageService:         storageService,
		placesService:          placesService,
		verifLogRepo:           verifLogRepo,
		directionRepo:          directionRepo,
		verificationPeriodDays: verificationPeriodDays,
	}
	// notifService arayüz alanı olduğu için doğrudan atanamaz: nil bir
	// *NotificationService atandığında alan "tipli nil" olur ve
	// `h.notifService != nil` kontrolü YANLIŞLIKLA true döner, çağrı panic eder.
	// Açık kontrolle alanın gerçekten nil kalması sağlanıyor.
	if notifService != nil {
		h.notifService = notifService
	}
	return h
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
// GET /api/v1/venues/by-category/:categoryId
func (h *VenueHandler) ListByCategory(c *fiber.Ctx) error {
	categoryID, err := c.ParamsInt("categoryId")
	if err != nil || categoryID <= 0 {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "geçerli bir kategori ID gereklidir",
		})
	}

	venues, err := h.venueRepo.FindByFoodCategory(c.Context(), categoryID)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "mekanlar listelenemedi"})
	}

	return c.JSON(fiber.Map{"data": venues, "count": len(venues)})
}

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
		allowed, guideCity := h.cityAllowanceFor(c, components.City)
		return c.JSON(fiber.Map{
			"place_id":     placeID,
			"name":         components.Name,
			"city":         components.City,
			"district":     components.District,
			"photo_urls":   photoURLs,
			"city_allowed": allowed,
			"guide_city":   guideCity,
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
	allowed, guideCity := h.cityAllowanceFor(c, components.City)
	return c.JSON(fiber.Map{
		"place_id":     resolved,
		"name":         components.Name,
		"city":         components.City,
		"district":     components.District,
		"photo_urls":   photoURLs,
		"city_allowed": allowed,
		"guide_city":   guideCity,
	})
}

// PreviewLocationFromLink godoc
// POST /api/v1/venues/preview-location  (Guide + Admin)
// Bir Google Maps linkini parse edip koordinat + (mümkünse) gerçek place_id ve
// mekan bilgilerini (isim/şehir/ilçe/foto) önizleme olarak döndürür.
// Kısa linkleri (maps.app.goo.gl) backend'de redirect takibiyle çözer.
func (h *VenueHandler) PreviewLocationFromLink(c *fiber.Ctx) error {
	if h.placesService == nil {
		return c.Status(fiber.StatusServiceUnavailable).JSON(fiber.Map{
			"error": "places servisi kullanılamıyor",
		})
	}

	var req struct {
		MapsLink string `json:"maps_link"`
	}
	if err := c.BodyParser(&req); err != nil {
		return fiber.ErrBadRequest
	}

	coords, err := services.ParseMapsLink(req.MapsLink)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "Google Maps linki çözümlenemedi. Lütfen geçerli bir konum linki yapıştırın.",
		})
	}

	// place_id'yi belirle: linkte ChIJ varsa onu, yoksa isim+koordinatla çöz.
	placeID := coords.PlaceID
	if placeID == "" && coords.PlaceName != "" {
		placeID = h.placesService.ResolvePlaceID(coords.PlaceName, coords.Latitude, coords.Longitude)
	}

	resp := fiber.Map{
		"latitude":  coords.Latitude,
		"longitude": coords.Longitude,
		"place_id":  placeID,
		"name":      coords.PlaceName,
	}

	// place_id bulunduysa Places API'den zengin bilgileri ekle.
	if placeID != "" {
		if components, err := h.placesService.GetAddressComponents(placeID); err == nil && components != nil {
			resp["name"] = components.Name
			resp["city"] = components.City
			resp["district"] = components.District
			resp["photo_urls"] = h.placesService.BuildPhotoURLs(components.PhotoReferences, 800)
		}
	}

	venueCity, _ := resp["city"].(string) // place_id yoksa boş kalır
	allowed, guideCity := h.cityAllowanceFor(c, venueCity)
	resp["city_allowed"] = allowed
	resp["guide_city"] = guideCity
	return c.JSON(resp)
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
// radius=0 gönderilirse yarıçap kısıtı uygulanmaz; konumu uzak olan mekanlar da
// listeye girer. lat/lng mesafe hesabı için yine zorunludur.
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

	// Giriş yapmış viewer için: bu kullanıcı mekanı bu dönemde doğruladı mı?
	// (OptionalAuth — token yoksa anonim, confirmed_by_me nil kalır.)
	// Ekleyen kendi mekanını doğrulayamaz; onun için de false anlamlıdır.
	if userID, uErr := getUserID(c); uErr == nil && userID != venue.AddedBy {
		if confirmed, hErr := h.venueRepo.HasConfirmed(c.Context(), id, userID); hErr == nil {
			venue.ConfirmedByMe = &confirmed
		}
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

	// Tek fotoğraf politikası: yeni fotoğraf yüklenince mevcut fotoğraflar silinir.
	if existing, err := h.venueRepo.GetPhotosByVenueID(c.Context(), venueID); err == nil {
		for _, old := range existing {
			if err := h.venueRepo.DeletePhoto(c.Context(), old.ID, venueID); err == nil {
				_ = h.storageService.Delete(c.Context(), old.URL)
			}
		}
	}

	photo := &models.VenuePhoto{
		VenueID:    venueID,
		URL:        url,
		UploadedBy: userID,
		IsPrimary:  true,
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

	guideCity := ""
	if getUserRole(c) == string(models.RoleGuide) {
		gc, gcErr := h.userRepo.GetGuideCity(c.Context(), guideID)
		if gcErr != nil {
			return fiber.ErrInternalServerError
		}
		if gc != nil {
			guideCity = *gc
		}
	}

	if err := h.venueRepo.ConfirmVenue(c.Context(), venueID, guideID, guideCity); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "mekan bulunamadı"})
		}
		msg := err.Error()
		if strings.Contains(msg, "doğrulamışsınız") ||
			strings.Contains(msg, "kendi eklediğiniz") ||
			strings.Contains(msg, "yalnızca onaylı") ||
			strings.Contains(msg, "rehberi olduğunuz") {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": msg})
		}
		return fiber.ErrInternalServerError
	}
	return c.JSON(fiber.Map{"status": "confirmed"})
}

// CheckDuplicate godoc
// GET /api/v1/venues/check-duplicate?google_place_id=...  (Guide/Admin)
// Mekan eklemeden önce erken duplicate uyarısı için.
func (h *VenueHandler) CheckDuplicate(c *fiber.Ctx) error {
	placeID := c.Query("google_place_id")
	if placeID == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "google_place_id zorunludur"})
	}

	venue, err := h.venueRepo.FindByGooglePlaceID(c.Context(), placeID)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return c.JSON(fiber.Map{"exists": false})
		}
		return fiber.ErrInternalServerError
	}

	return c.JSON(fiber.Map{
		"exists": true,
		"venue": fiber.Map{
			"id":                 venue.ID,
			"name":               venue.Name,
			"city":               venue.City,
			"confirmation_count": venue.ConfirmationCount,
			"badge":              venue.Badge,
		},
	})
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

// TrackDirectionClick godoc
// POST /api/v1/venues/:id/direction-click
// Yol tarifi butonuna basıldığını kaydeder. Auth opsiyonel — token varsa user_id,
// yoksa anonim (NULL). Fire-and-forget; her zaman 204 döner.
func (h *VenueHandler) TrackDirectionClick(c *fiber.Ctx) error {
	venueID := c.Params("id")

	var userID *string
	if uid, ok := c.Locals("userID").(string); ok && uid != "" {
		userID = &uid
	}

	// Hata olsa bile kullanıcı akışını bozmamak için sessizce yut; yine de 204 dön.
	_ = h.directionRepo.Create(c.Context(), venueID, userID)

	return c.SendStatus(fiber.StatusNoContent)
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

	dropped, err := h.venueRepo.VerifyByGuide(c.Context(), venueID, guideID, h.verificationPeriodDays)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return fiber.ErrNotFound
		}
		return fiber.ErrInternalServerError
	}

	_ = h.verifLogRepo.Create(c.Context(), venueID, guideID, "verified")

	// Düşen rehberlere bildirim (fire-and-forget; mekan adını detaydan al).
	if len(dropped) > 0 && h.notifService != nil {
		venueName := ""
		if v, vErr := h.venueRepo.FindByID(c.Context(), venueID); vErr == nil {
			venueName = v.Name
		}
		for _, gid := range dropped {
			_ = h.notifService.SendConfirmationReset(c.Context(), gid, venueID, venueName)
		}
	}

	return c.JSON(fiber.Map{"status": "verified"})
}
