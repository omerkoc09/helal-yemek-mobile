package handlers

import (
	"context"
	"errors"
	"net/http"
	"testing"

	"github.com/gofiber/fiber/v2"

	"github.com/omerkoc/caiz-mi/internal/models"
	"github.com/omerkoc/caiz-mi/internal/repository"
)

// --- fakeReviewStore ---

type fakeReviewStore struct {
	reviews   []models.Review
	listErr   error
	createErr error
	updateErr error
	deleteErr error

	// Son çağrının argümanları.
	gotCreated *models.Review
	gotUpdated *models.Review
	gotDelID   string
	gotDelUser string
	gotIsAdmin bool
}

func (f *fakeReviewStore) ListByVenue(_ context.Context, _ string) ([]models.Review, error) {
	return f.reviews, f.listErr
}

func (f *fakeReviewStore) Create(_ context.Context, rv *models.Review) error {
	f.gotCreated = rv
	return f.createErr
}

func (f *fakeReviewStore) Update(_ context.Context, rv *models.Review) error {
	f.gotUpdated = rv
	return f.updateErr
}

func (f *fakeReviewStore) Delete(_ context.Context, id, userID string, isAdmin bool) error {
	f.gotDelID, f.gotDelUser, f.gotIsAdmin = id, userID, isAdmin
	return f.deleteErr
}

// --- helper ---

func setupReviewApp(store reviewStore, userID, role string) *fiber.App {
	app := fiber.New()
	h := &ReviewHandler{reviewRepo: store}
	app.Use(func(c *fiber.Ctx) error {
		if userID != "" {
			c.Locals("userID", userID)
		}
		if role != "" {
			c.Locals("userRole", role)
		}
		return c.Next()
	})
	app.Get("/venues/:id/reviews", h.List)
	app.Post("/venues/:id/reviews", h.Create)
	app.Put("/venues/:id/reviews/:reviewId", h.Update)
	app.Delete("/venues/:id/reviews/:reviewId", h.Delete)
	return app
}

// --- List ---

func TestReviewList(t *testing.T) {
	t.Run("başarılı", func(t *testing.T) {
		store := &fakeReviewStore{reviews: []models.Review{{ID: "r1", Rating: 5}}}
		resp := doJSON(t, setupReviewApp(store, "", ""), http.MethodGet, "/venues/v1/reviews", "")
		if resp.StatusCode != fiber.StatusOK {
			t.Fatalf("beklenen 200, alınan %d", resp.StatusCode)
		}
	})

	t.Run("repo hatası — 500", func(t *testing.T) {
		store := &fakeReviewStore{listErr: errors.New("db")}
		resp := doJSON(t, setupReviewApp(store, "", ""), http.MethodGet, "/venues/v1/reviews", "")
		if resp.StatusCode != fiber.StatusInternalServerError {
			t.Fatalf("beklenen 500, alınan %d", resp.StatusCode)
		}
	})
}

// --- Create ---

func TestReviewCreate(t *testing.T) {
	tests := []struct {
		name       string
		userID     string
		body       string
		createErr  error
		wantStatus int
	}{
		{name: "başarılı", userID: "u1", body: `{"rating":4}`, wantStatus: fiber.StatusCreated},
		{name: "giriş yapılmamış", userID: "", body: `{"rating":4}`, wantStatus: fiber.StatusUnauthorized},
		{name: "bozuk JSON", userID: "u1", body: `{bozuk`, wantStatus: fiber.StatusBadRequest},
		{name: "puan 0 — sınır altı", userID: "u1", body: `{"rating":0}`, wantStatus: fiber.StatusBadRequest},
		{name: "puan 6 — sınır üstü", userID: "u1", body: `{"rating":6}`, wantStatus: fiber.StatusBadRequest},
		{name: "puan 1 — alt sınır kabul", userID: "u1", body: `{"rating":1}`, wantStatus: fiber.StatusCreated},
		{name: "puan 5 — üst sınır kabul", userID: "u1", body: `{"rating":5}`, wantStatus: fiber.StatusCreated},
		// Aynı mekana ikinci yorum: UNIQUE ihlali 409 dönmeli, 500 değil.
		{name: "mükerrer yorum — 409", userID: "u1", body: `{"rating":4}`, createErr: errors.New("duplicate key value violates unique constraint"), wantStatus: fiber.StatusConflict},
		{name: "diğer db hatası — 500", userID: "u1", body: `{"rating":4}`, createErr: errors.New("connection lost"), wantStatus: fiber.StatusInternalServerError},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			store := &fakeReviewStore{createErr: tt.createErr}
			resp := doJSON(t, setupReviewApp(store, tt.userID, ""), http.MethodPost, "/venues/v1/reviews", tt.body)
			if resp.StatusCode != tt.wantStatus {
				t.Fatalf("beklenen %d, alınan %d", tt.wantStatus, resp.StatusCode)
			}
		})
	}
}

func TestReviewCreateBindsVenueAndUser(t *testing.T) {
	store := &fakeReviewStore{}
	resp := doJSON(t, setupReviewApp(store, "u1", ""), http.MethodPost, "/venues/v42/reviews", `{"rating":3}`)
	if resp.StatusCode != fiber.StatusCreated {
		t.Fatalf("beklenen 201, alınan %d", resp.StatusCode)
	}
	// Yorum, URL'deki mekana ve context'teki kullanıcıya bağlanmalı —
	// istemciden gelen gövdeye değil.
	if store.gotCreated.VenueID != "v42" {
		t.Fatalf("venueID %q, beklenen v42", store.gotCreated.VenueID)
	}
	if store.gotCreated.UserID != "u1" {
		t.Fatalf("userID %q, beklenen u1", store.gotCreated.UserID)
	}
}

// --- Update ---

func TestReviewUpdate(t *testing.T) {
	tests := []struct {
		name       string
		userID     string
		body       string
		updateErr  error
		wantStatus int
	}{
		{name: "başarılı", userID: "u1", body: `{"rating":4}`, wantStatus: fiber.StatusOK},
		{name: "giriş yapılmamış", userID: "", body: `{"rating":4}`, wantStatus: fiber.StatusUnauthorized},
		{name: "bozuk JSON", userID: "u1", body: `{bozuk`, wantStatus: fiber.StatusBadRequest},
		{name: "geçersiz puan", userID: "u1", body: `{"rating":9}`, wantStatus: fiber.StatusBadRequest},
		{name: "yorum bulunamadı", userID: "u1", body: `{"rating":4}`, updateErr: repository.ErrNotFound, wantStatus: fiber.StatusNotFound},
		{name: "db hatası", userID: "u1", body: `{"rating":4}`, updateErr: errors.New("db"), wantStatus: fiber.StatusInternalServerError},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			store := &fakeReviewStore{updateErr: tt.updateErr}
			resp := doJSON(t, setupReviewApp(store, tt.userID, ""), http.MethodPut, "/venues/v1/reviews/r1", tt.body)
			if resp.StatusCode != tt.wantStatus {
				t.Fatalf("beklenen %d, alınan %d", tt.wantStatus, resp.StatusCode)
			}
		})
	}
}

func TestReviewUpdateScopesToOwner(t *testing.T) {
	store := &fakeReviewStore{}
	doJSON(t, setupReviewApp(store, "u1", ""), http.MethodPut, "/venues/v1/reviews/r9", `{"rating":2}`)
	// Sahiplik kontrolü repo'ya devrediliyor; handler kendi userID'sini
	// geçmeli ki başkasının yorumu güncellenemesin.
	if store.gotUpdated.ID != "r9" || store.gotUpdated.UserID != "u1" {
		t.Fatalf("repo'ya giden kayıt yanlış: %+v", store.gotUpdated)
	}
}

// --- Delete ---

func TestReviewDelete(t *testing.T) {
	tests := []struct {
		name       string
		userID     string
		deleteErr  error
		wantStatus int
	}{
		{name: "başarılı", userID: "u1", wantStatus: fiber.StatusNoContent},
		{name: "giriş yapılmamış", userID: "", wantStatus: fiber.StatusUnauthorized},
		{name: "yorum bulunamadı", userID: "u1", deleteErr: repository.ErrNotFound, wantStatus: fiber.StatusNotFound},
		{name: "db hatası", userID: "u1", deleteErr: errors.New("db"), wantStatus: fiber.StatusInternalServerError},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			store := &fakeReviewStore{deleteErr: tt.deleteErr}
			resp := doJSON(t, setupReviewApp(store, tt.userID, ""), http.MethodDelete, "/venues/v1/reviews/r1", "")
			if resp.StatusCode != tt.wantStatus {
				t.Fatalf("beklenen %d, alınan %d", tt.wantStatus, resp.StatusCode)
			}
		})
	}
}

func TestReviewDeletePassesAdminFlag(t *testing.T) {
	// Admin, başkasının yorumunu silebilmeli; bu yetki repo'ya isAdmin
	// bayrağıyla taşınıyor. Rol yanlış aktarılırsa admin yetkisi sessizce kaybolur.
	t.Run("admin rolü true geçirir", func(t *testing.T) {
		store := &fakeReviewStore{}
		doJSON(t, setupReviewApp(store, "u1", "admin"), http.MethodDelete, "/venues/v1/reviews/r1", "")
		if !store.gotIsAdmin {
			t.Fatal("admin rolünde isAdmin=true geçilmeliydi")
		}
	})

	t.Run("normal kullanıcı false geçirir", func(t *testing.T) {
		store := &fakeReviewStore{}
		doJSON(t, setupReviewApp(store, "u1", "traveler"), http.MethodDelete, "/venues/v1/reviews/r1", "")
		if store.gotIsAdmin {
			t.Fatal("traveler rolünde isAdmin=false olmalıydı")
		}
	})

	t.Run("guide rolü admin sayılmaz", func(t *testing.T) {
		store := &fakeReviewStore{}
		doJSON(t, setupReviewApp(store, "u1", "guide"), http.MethodDelete, "/venues/v1/reviews/r1", "")
		if store.gotIsAdmin {
			t.Fatal("guide rolünde isAdmin=false olmalıydı")
		}
	})
}
