package handlers

import (
	"strings"

	"github.com/gofiber/fiber/v2"
	"github.com/omerkoc/itimat-mobile/internal/services"
)

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
