package handlers

import (
	"context"
	"errors"
	"fmt"
	"io"
	"log"
	"net/url"
	"strconv"
	"strings"

	"github.com/gofiber/fiber/v2"
	"github.com/omerkoc/itimat-mobile/internal/models"
	"github.com/omerkoc/itimat-mobile/internal/repository"
	"github.com/omerkoc/itimat-mobile/internal/services"
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

// existingVenueFor — verilen place_id'ye ait mekan zaten kayıtlıysa özetini döner.
//
// Neden preview yanıtında: istemci link adımında ayrı bir check-duplicate çağrısı
// da yapıyor, ama o çağrı başarısız olursa akış sessizce devam ediyor ve rehber
// hatayı ancak son adımda (409) görüyordu. Preview zaten her linkte çağrıldığı
// için duplicate bilgisini buraya da koymak engeli tek çağrıya bağımlı olmaktan
// çıkarır. Bulunamazsa nil döner — JSON'da null olur.
func (h *VenueHandler) existingVenueFor(c *fiber.Ctx, placeID string) fiber.Map {
	if placeID == "" {
		return nil
	}
	venue, err := h.venueRepo.FindByGooglePlaceID(c.Context(), placeID)
	if err != nil || venue == nil {
		return nil
	}
	return fiber.Map{
		"id":                 venue.ID,
		"name":               venue.Name,
		"city":               venue.City,
		"latitude":           venue.Latitude,
		"longitude":          venue.Longitude,
		"status":             venue.Status,
		"added_by":           venue.AddedBy,
		"confirmation_count": venue.ConfirmationCount,
		"badge":              venue.Badge,
	}
}

// resolveGooglePhotoURLs — istekten indirilecek fotoğraf listesini üretir.
//
// Yeni istemci `google_photo_urls` (sıralı, İLKİ kapak) gönderir; eski istemcinin
// tekil `google_photo_url` alanı tek elemanlı listeye çevrilir. Boş değerler
// ayıklanır, tekrarlananlar atlanır (aynı fotoğraf iki kez indirilmesin) ve
// liste maxGooglePhotosPerVenue ile sınırlanır.
func resolveGooglePhotoURLs(urls []string, legacyURL string) []string {
	if len(urls) == 0 && legacyURL != "" {
		urls = []string{legacyURL}
	}

	resolved := make([]string, 0, len(urls))
	seen := make(map[string]struct{}, len(urls))
	for _, u := range urls {
		if u == "" {
			continue
		}
		if _, dup := seen[u]; dup {
			continue
		}
		seen[u] = struct{}{}
		resolved = append(resolved, u)
		if len(resolved) == maxGooglePhotosPerVenue {
			break
		}
	}

	return resolved
}

// storeVenuePhoto — seçilen Google fotoğrafını kalıcı depoya yazar.
//
// İstemciye verilen adres GÖRELİ bir proxy yoludur (`/api/v1/places/photo?ref=...`),
// çünkü API anahtarı istemciye gitmesin diye fotoğraflar sunucu üzerinden geçiriliyor.
// Bu adres seçim olarak geri geldiğinde doğrudan indirilemez: SSRF guard https + Google
// host şartı arar ve göreli yolu haklı olarak reddeder. Sonuç: mekan sessizce
// fotoğrafsız oluşuyordu (proxy'ye geçişten beri, 2026-07-11'den sonra hiçbir mekanda
// fotoğraf yok).
//
// Çözüm: proxy yolundan photo_reference'ı çıkarıp fotoğrafı Places'ten sunucu tarafında
// indiriyoruz. Guard zayıflatılmıyor — adres kullanıcıdan gelmiyor, biz üretiyoruz.
// Tam URL gelen durum (eski istemciler, admin panel) eski yoldan devam eder.
func (h *VenueHandler) storeVenuePhoto(ctx context.Context, photoURL string) (string, error) {
	ref, width, ok := parsePlacePhotoProxyURL(photoURL)
	if !ok {
		return h.storageService.DownloadAndStore(ctx, photoURL)
	}
	if h.placesService == nil {
		return "", fmt.Errorf("places servisi kullanılamıyor")
	}

	fetchCtx, cancel := context.WithTimeout(context.Background(), photoFetchTimeout)
	defer cancel()

	body, contentType, err := h.placesService.FetchPhoto(fetchCtx, ref, width)
	if err != nil {
		return "", err
	}
	defer body.Close()

	return h.storageService.StoreStream(ctx, io.LimitReader(body, maxPhotoBytes), contentType)
}

// parsePlacePhotoProxyURL — kendi foto proxy adresimizden photo_reference ve genişliği
// çıkarır. Adres göreli ("/api/v1/places/photo?ref=..&w=..") ya da tam URL olabilir.
func parsePlacePhotoProxyURL(raw string) (ref string, width int, ok bool) {
	u, err := url.Parse(raw)
	if err != nil || !strings.HasSuffix(u.Path, services.PhotoProxyPath) {
		return "", 0, false
	}
	ref = u.Query().Get("ref")
	if ref == "" {
		return "", 0, false
	}
	width = defaultPhotoWidth
	if w, err := strconv.Atoi(u.Query().Get("w")); err == nil && w > 0 {
		width = w
	}
	return ref, width, true
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
		GooglePhotoURL   string   `json:"google_photo_url"`  // eski istemciler (tek fotoğraf)
		GooglePhotoURLs  []string `json:"google_photo_urls"` // yeni: çoklu seçim, ilki kapak
		Notes            *string  `json:"notes"`
		CriteriaIDs      []int    `json:"criteria_ids"`
		CategoryIDs      []int    `json:"category_ids"`
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
		req.FoodHalalMode = "all"
	}
	if req.FoodHalalMode != "all" && req.FoodHalalMode != "except" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "food_halal_mode 'all' veya 'except' olmalıdır",
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
		venue.TrustCriteria = criteria
	} else {
		venue.TrustCriteria = []models.TrustCriteria{}
	}

	// Mutfak kategorilerini kaydet (her iki modda da zorunlu)
	if len(req.CategoryIDs) == 0 {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "en az bir mutfak kategorisi seçilmelidir"})
	}
	if err := h.venueRepo.SetVenueCategories(c.Context(), venue.ID, req.CategoryIDs); err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "mutfak kategorileri kaydedilemedi"})
	}
	categories, _ := h.venueRepo.GetCategoriesByVenueID(c.Context(), venue.ID)
	venue.Categories = categories

	// ExcludedProducts sadece except modunda anlamlı
	if venue.FoodHalalMode != "except" {
		venue.ExcludedProducts = []string{}
	}

	photoURLs := resolveGooglePhotoURLs(req.GooglePhotoURLs, req.GooglePhotoURL)

	venue.Photos = []models.VenuePhoto{}
	for _, photoURL := range photoURLs {
		if h.storageService == nil {
			break
		}
		storedURL, err := h.storeVenuePhoto(c.Context(), photoURL)
		if err != nil {
			// Hata mekan oluşturmayı engellemiyor (fotoğraf opsiyonel), ama iz
			// bırakmadan yutulmamalı: SSRF guard'ın reddi de, allowlist'teki bir
			// boşluk da (ör. Google yeni CDN host'u) buradan görünür.
			log.Printf("[VENUE] google fotoğrafı alınamadı: %v", err)
			continue
		}
		photo := &models.VenuePhoto{
			VenueID:    venue.ID,
			URL:        storedURL,
			UploadedBy: userID,
			// Kapak = başarıyla kaydedilen İLK fotoğraf. Seçim sırasındaki ilk
			// fotoğrafın indirilmesi başarısız olursa kapak sonrakine kayar.
			IsPrimary: len(venue.Photos) == 0,
		}
		if err := h.venueRepo.AddPhoto(c.Context(), photo); err == nil {
			venue.Photos = append(venue.Photos, *photo)
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
		CategoryIDs      *[]int    `json:"category_ids"`
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

	if req.CategoryIDs != nil {
		if err := h.venueRepo.SetVenueCategories(c.Context(), venueID, *req.CategoryIDs); err != nil {
			return fiber.ErrInternalServerError
		}
	}

	if req.FoodHalalMode != nil {
		mode := *req.FoodHalalMode
		if mode != "all" && mode != "except" {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
				"error": "food_halal_mode 'all' veya 'except' olmalıdır",
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

	updated, err := h.venueRepo.FindByID(c.Context(), venueID)
	if err != nil {
		return fiber.ErrInternalServerError
	}
	return c.JSON(updated)
}
