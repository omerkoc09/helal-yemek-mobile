package handlers

import (
	"net/http"
	"testing"

	"github.com/gofiber/fiber/v2"

	"github.com/omerkoc/caiz-mi/internal/services"
)

func setupPhotoProxyApp(places *services.PlacesService) *fiber.App {
	app := fiber.New()
	h := &VenueHandler{placesService: places}
	app.Get("/places/photo", h.PlacePhotoProxy)
	return app
}

func TestPlacePhotoProxyValidation(t *testing.T) {
	// Anahtarsız PlacesService: FetchPhoto ağa çıkmadan hata döner, böylece
	// doğrulama dallarını ağ bağımlılığı olmadan test edebiliyoruz.
	withKeyless := services.NewPlacesService("")

	t.Run("places servisi yoksa 503", func(t *testing.T) {
		app := setupPhotoProxyApp(nil)
		resp := doJSON(t, app, http.MethodGet, "/places/photo?ref=abc", "")
		if resp.StatusCode != fiber.StatusServiceUnavailable {
			t.Fatalf("beklenen 503, alınan %d", resp.StatusCode)
		}
	})

	t.Run("ref eksikse 400", func(t *testing.T) {
		app := setupPhotoProxyApp(withKeyless)
		resp := doJSON(t, app, http.MethodGet, "/places/photo", "")
		if resp.StatusCode != fiber.StatusBadRequest {
			t.Fatalf("beklenen 400, alınan %d", resp.StatusCode)
		}
	})

	t.Run("google hatasında 502", func(t *testing.T) {
		// Anahtar tanımsız olduğu için FetchPhoto hata verir; handler bunu
		// 502'ye çevirmeli (kendi hatamız değil, yukarı akış hatası).
		app := setupPhotoProxyApp(withKeyless)
		resp := doJSON(t, app, http.MethodGet, "/places/photo?ref=abc", "")
		if resp.StatusCode != fiber.StatusBadGateway {
			t.Fatalf("beklenen 502, alınan %d", resp.StatusCode)
		}
	})
}

func TestPhotoWidthBounds(t *testing.T) {
	// Genişlik sınırları sabitlerle ifade ediliyor; üst sınır olmadan biri
	// w=100000 isteyerek Places kotasını ve bant genişliğini tüketebilirdi.
	if minPhotoWidth >= maxPhotoWidth {
		t.Fatal("alt sınır üst sınırdan küçük olmalı")
	}
	if defaultPhotoWidth < minPhotoWidth || defaultPhotoWidth > maxPhotoWidth {
		t.Fatalf("varsayılan genişlik (%d) sınırların dışında", defaultPhotoWidth)
	}
}
