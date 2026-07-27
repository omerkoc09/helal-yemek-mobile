package handlers

import (
	"errors"

	"github.com/gofiber/fiber/v2"
	"github.com/omerkoc/caiz-mi/internal/models"
	"github.com/omerkoc/caiz-mi/internal/repository"
)

// canViewUnapproved — onaylı olmayan bir mekanın detayını görme yetkisi.
// Admin her mekanı görür; rehber yalnızca kendi eklediği mekanı görür.
// Anonim viewer'da getUserID hata döner ve yetki verilmez.
func (h *VenueHandler) canViewUnapproved(c *fiber.Ctx, addedBy string) bool {
	if getUserRole(c) == string(models.RoleAdmin) {
		return true
	}
	userID, err := getUserID(c)
	return err == nil && userID == addedBy
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

	// Onaylı olmayan mekan (pending / rejected / suspended) herkese kapalıdır:
	// yeni eklenen mekan admin onaylayana kadar uygulamada görünmemelidir.
	// İstisna: mekanı ekleyen rehber kendi bekleyen mekanını my-venues
	// üzerinden açabilmeli, admin ise her durumu görebilmeli.
	if venue.Status != models.VenueStatusApproved && !h.canViewUnapproved(c, venue.AddedBy) {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "mekan bulunamadı"})
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
	categories, err := h.venueRepo.GetAllFoodCategories(c.Context())
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "yemek kategorileri listelenemedi"})
	}
	return c.JSON(categories)
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
