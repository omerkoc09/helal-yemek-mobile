package handlers

import (
	"context"
	"errors"
	"net/http"
	"testing"

	"github.com/gofiber/fiber/v2"

	"github.com/omerkoc/itimat-mobile/internal/models"
	"github.com/omerkoc/itimat-mobile/internal/repository"
)

// --- fakeFavoriteStore ---

type fakeFavoriteStore struct {
	venues    []models.Venue
	listErr   error
	addErr    error
	removeErr error

	gotUserID  string
	gotVenueID string
}

func (f *fakeFavoriteStore) ListByUser(_ context.Context, userID string) ([]models.Venue, error) {
	f.gotUserID = userID
	return f.venues, f.listErr
}

func (f *fakeFavoriteStore) Add(_ context.Context, userID, venueID string) error {
	f.gotUserID, f.gotVenueID = userID, venueID
	return f.addErr
}

func (f *fakeFavoriteStore) Remove(_ context.Context, userID, venueID string) error {
	f.gotUserID, f.gotVenueID = userID, venueID
	return f.removeErr
}

// --- helper ---

func setupFavoriteApp(store favoriteStore, userID string) *fiber.App {
	app := fiber.New()
	h := &FavoriteHandler{favoriteRepo: store}
	app.Use(func(c *fiber.Ctx) error {
		if userID != "" {
			c.Locals("userID", userID)
		}
		return c.Next()
	})
	app.Get("/favorites", h.List)
	app.Post("/favorites/:venueId", h.Add)
	app.Delete("/favorites/:venueId", h.Remove)
	return app
}

func TestFavoriteList(t *testing.T) {
	tests := []struct {
		name       string
		userID     string
		listErr    error
		wantStatus int
	}{
		{name: "başarılı", userID: "u1", wantStatus: fiber.StatusOK},
		{name: "giriş yapılmamış", userID: "", wantStatus: fiber.StatusUnauthorized},
		{name: "db hatası", userID: "u1", listErr: errors.New("db"), wantStatus: fiber.StatusInternalServerError},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			store := &fakeFavoriteStore{venues: []models.Venue{{ID: "v1"}}, listErr: tt.listErr}
			resp := doJSON(t, setupFavoriteApp(store, tt.userID), http.MethodGet, "/favorites", "")
			if resp.StatusCode != tt.wantStatus {
				t.Fatalf("beklenen %d, alınan %d", tt.wantStatus, resp.StatusCode)
			}
		})
	}
}

func TestFavoriteAdd(t *testing.T) {
	tests := []struct {
		name       string
		userID     string
		addErr     error
		wantStatus int
	}{
		{name: "başarılı", userID: "u1", wantStatus: fiber.StatusCreated},
		{name: "giriş yapılmamış", userID: "", wantStatus: fiber.StatusUnauthorized},
		{name: "db hatası", userID: "u1", addErr: errors.New("db"), wantStatus: fiber.StatusInternalServerError},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			store := &fakeFavoriteStore{addErr: tt.addErr}
			resp := doJSON(t, setupFavoriteApp(store, tt.userID), http.MethodPost, "/favorites/v9", "")
			if resp.StatusCode != tt.wantStatus {
				t.Fatalf("beklenen %d, alınan %d", tt.wantStatus, resp.StatusCode)
			}
		})
	}
}

func TestFavoriteRemove(t *testing.T) {
	tests := []struct {
		name       string
		userID     string
		removeErr  error
		wantStatus int
	}{
		{name: "başarılı", userID: "u1", wantStatus: fiber.StatusNoContent},
		{name: "giriş yapılmamış", userID: "", wantStatus: fiber.StatusUnauthorized},
		{name: "favori kaydı yok", userID: "u1", removeErr: repository.ErrNotFound, wantStatus: fiber.StatusNotFound},
		{name: "db hatası", userID: "u1", removeErr: errors.New("db"), wantStatus: fiber.StatusInternalServerError},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			store := &fakeFavoriteStore{removeErr: tt.removeErr}
			resp := doJSON(t, setupFavoriteApp(store, tt.userID), http.MethodDelete, "/favorites/v9", "")
			if resp.StatusCode != tt.wantStatus {
				t.Fatalf("beklenen %d, alınan %d", tt.wantStatus, resp.StatusCode)
			}
		})
	}
}

func TestFavoriteScopesToCurrentUser(t *testing.T) {
	// Favori işlemleri her zaman context'teki kullanıcıya bağlanmalı;
	// aksi halde bir kullanıcı başkasının favorisini değiştirebilir.
	t.Run("Add", func(t *testing.T) {
		store := &fakeFavoriteStore{}
		doJSON(t, setupFavoriteApp(store, "u7"), http.MethodPost, "/favorites/v9", "")
		if store.gotUserID != "u7" || store.gotVenueID != "v9" {
			t.Fatalf("userID=%q venueID=%q, beklenen u7/v9", store.gotUserID, store.gotVenueID)
		}
	})

	t.Run("Remove", func(t *testing.T) {
		store := &fakeFavoriteStore{}
		doJSON(t, setupFavoriteApp(store, "u7"), http.MethodDelete, "/favorites/v9", "")
		if store.gotUserID != "u7" || store.gotVenueID != "v9" {
			t.Fatalf("userID=%q venueID=%q, beklenen u7/v9", store.gotUserID, store.gotVenueID)
		}
	})
}
