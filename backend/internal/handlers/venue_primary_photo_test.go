package handlers

import (
	"context"
	"net/http"
	"testing"

	"github.com/gofiber/fiber/v2"

	"github.com/omerkoc/itimat-mobile/internal/models"
	"github.com/omerkoc/itimat-mobile/internal/repository"
)

// primaryPhotoStore — kapak akışını izleyen fake. Yalnızca bu testin ihtiyaç
// duyduğu davranışı taşır; geri kalanı gömülü fakeVenueStore'dan gelir.
type primaryPhotoStore struct {
	fakeVenueStore

	photos []models.VenuePhoto

	setPrimaryCalledWith string
	setPrimaryErr        error
}

func (s *primaryPhotoStore) SetPrimaryPhoto(_ context.Context, photoID, _ string) error {
	s.setPrimaryCalledWith = photoID
	if s.setPrimaryErr != nil {
		return s.setPrimaryErr
	}
	for i := range s.photos {
		s.photos[i].IsPrimary = s.photos[i].ID == photoID
	}
	return nil
}

func (s *primaryPhotoStore) PromoteAnyPhotoToPrimary(context.Context, string) error {
	return nil
}

func (s *primaryPhotoStore) GetPhotosByVenueID(context.Context, string) ([]models.VenuePhoto, error) {
	return s.photos, nil
}

func (s *primaryPhotoStore) FindPhotoByID(_ context.Context, photoID string) (*models.VenuePhoto, error) {
	for i := range s.photos {
		if s.photos[i].ID == photoID {
			return &s.photos[i], nil
		}
	}
	return nil, repository.ErrNotFound
}

func (s *primaryPhotoStore) DeletePhoto(context.Context, string, string) error { return nil }

func setupPrimaryPhotoApp(store *primaryPhotoStore) *fiber.App {
	app := fiber.New()
	h := &VenueHandler{venueRepo: store}
	app.Put("/venues/:id/photos/:photoId/primary", h.SetPrimaryPhoto)
	return app
}

func TestSetPrimaryPhoto(t *testing.T) {
	t.Run("kapak değişir ve güncel liste döner", func(t *testing.T) {
		store := &primaryPhotoStore{photos: []models.VenuePhoto{
			{ID: "p1", VenueID: "v1", IsPrimary: true},
			{ID: "p2", VenueID: "v1"},
		}}
		app := setupPrimaryPhotoApp(store)

		resp := doJSON(t, app, http.MethodPut, "/venues/v1/photos/p2/primary", "")
		if resp.StatusCode != fiber.StatusOK {
			t.Fatalf("beklenen 200, alınan %d", resp.StatusCode)
		}
		if store.setPrimaryCalledWith != "p2" {
			t.Fatalf("beklenen p2, çağrılan %q", store.setPrimaryCalledWith)
		}
		// Tekillik: yalnızca bir fotoğraf kapak kalmalı.
		if store.photos[0].IsPrimary || !store.photos[1].IsPrimary {
			t.Fatalf("kapak tekilliği bozuldu: %+v", store.photos)
		}
	})

	t.Run("başka mekanın fotoğrafı için 404", func(t *testing.T) {
		// Repo katmanı venue_id eşleşmezse ErrNotFound döner; handler bunu
		// 500'e değil 404'e çevirmeli (istemci hatası).
		store := &primaryPhotoStore{setPrimaryErr: repository.ErrNotFound}
		app := setupPrimaryPhotoApp(store)

		resp := doJSON(t, app, http.MethodPut, "/venues/v1/photos/yabanci/primary", "")
		if resp.StatusCode != fiber.StatusNotFound {
			t.Fatalf("beklenen 404, alınan %d", resp.StatusCode)
		}
	})
}

// Not: DeletePhoto'daki kapak devri handler testine uygun değil — handler
// fiziksel silme için storageService'e gidiyor ve o bağımlılık burada
// kurulamıyor (nil ile panikliyor). Devir mantığının kendisi SQL seviyesinde,
// gerçek veritabanına karşı doğrulandı (PromoteAnyPhotoToPrimary).
