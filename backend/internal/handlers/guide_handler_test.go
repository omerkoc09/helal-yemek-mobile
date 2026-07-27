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

// --- fakes ---

type fakeGuideStore struct {
	hasPending    bool
	hasPendingErr error
	createErr     error
	latest        *models.GuideApplication
	latestErr     error

	gotCreated *models.GuideApplication
}

func (f *fakeGuideStore) HasPendingApplication(_ context.Context, _ string) (bool, error) {
	return f.hasPending, f.hasPendingErr
}

func (f *fakeGuideStore) Create(_ context.Context, app *models.GuideApplication) error {
	f.gotCreated = app
	return f.createErr
}

func (f *fakeGuideStore) FindLatestByUserID(_ context.Context, _ string) (*models.GuideApplication, error) {
	return f.latest, f.latestErr
}

type fakeGuideVenueLister struct {
	venues []models.Venue
	err    error

	// confirmed — FindConfirmedBy'ın döneceği liste; venues'tan ayrı tutulur ki
	// "eklediklerim" ile "doğruladıklarım" karışmasın.
	confirmed    []models.Venue
	confirmedErr error

	gotUserID          string
	gotConfirmedUserID string
}

func (f *fakeGuideVenueLister) FindByAddedBy(_ context.Context, userID string) ([]models.Venue, error) {
	f.gotUserID = userID
	return f.venues, f.err
}

func (f *fakeGuideVenueLister) FindConfirmedBy(_ context.Context, guideID string) ([]models.Venue, error) {
	f.gotConfirmedUserID = guideID
	return f.confirmed, f.confirmedErr
}

// --- helper ---

func setupGuideApp(gs guideStore, vl guideVenueLister, userID, role string) *fiber.App {
	app := fiber.New()
	h := &GuideHandler{guideRepo: gs, venueRepo: vl}
	app.Use(func(c *fiber.Ctx) error {
		if userID != "" {
			c.Locals("userID", userID)
		}
		if role != "" {
			c.Locals("userRole", role)
		}
		return c.Next()
	})
	app.Post("/guide/apply", h.Apply)
	app.Get("/guide/my-venues", h.MyVenues)
	app.Get("/guide/my-confirmations", h.MyConfirmations)
	app.Get("/guide/my-application", h.MyApplication)
	return app
}

// --- Apply ---

func TestGuideApply(t *testing.T) {
	const validBody = `{"city":"İstanbul","terms_accepted":true}`

	tests := []struct {
		name       string
		userID     string
		role       string
		body       string
		store      *fakeGuideStore
		wantStatus int
	}{
		{name: "başarılı başvuru", userID: "u1", role: "traveler", body: validBody, store: &fakeGuideStore{}, wantStatus: fiber.StatusCreated},
		{name: "giriş yapılmamış", userID: "", role: "", body: validBody, store: &fakeGuideStore{}, wantStatus: fiber.StatusUnauthorized},
		// Zaten guide olan tekrar başvuramaz.
		{name: "guide rolü başvuramaz", userID: "u1", role: "guide", body: validBody, store: &fakeGuideStore{}, wantStatus: fiber.StatusBadRequest},
		{name: "admin rolü başvuramaz", userID: "u1", role: "admin", body: validBody, store: &fakeGuideStore{}, wantStatus: fiber.StatusBadRequest},
		{name: "bozuk JSON", userID: "u1", role: "traveler", body: `{bozuk`, store: &fakeGuideStore{}, wantStatus: fiber.StatusBadRequest},
		{name: "şartlar kabul edilmemiş", userID: "u1", role: "traveler", body: `{"city":"İstanbul","terms_accepted":false}`, store: &fakeGuideStore{}, wantStatus: fiber.StatusBadRequest},
		{name: "geçersiz şehir", userID: "u1", role: "traveler", body: `{"city":"Gotham","terms_accepted":true}`, store: &fakeGuideStore{}, wantStatus: fiber.StatusBadRequest},
		{name: "şehir boş", userID: "u1", role: "traveler", body: `{"city":"","terms_accepted":true}`, store: &fakeGuideStore{}, wantStatus: fiber.StatusBadRequest},
		// Mükerrer başvuru 409 dönmeli.
		{name: "bekleyen başvuru var", userID: "u1", role: "traveler", body: validBody, store: &fakeGuideStore{hasPending: true}, wantStatus: fiber.StatusConflict},
		{name: "pending sorgusu hata verirse 500", userID: "u1", role: "traveler", body: validBody, store: &fakeGuideStore{hasPendingErr: errors.New("db")}, wantStatus: fiber.StatusInternalServerError},
		{name: "kayıt hatası 500", userID: "u1", role: "traveler", body: validBody, store: &fakeGuideStore{createErr: errors.New("db")}, wantStatus: fiber.StatusInternalServerError},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			app := setupGuideApp(tt.store, &fakeGuideVenueLister{}, tt.userID, tt.role)
			resp := doJSON(t, app, http.MethodPost, "/guide/apply", tt.body)
			if resp.StatusCode != tt.wantStatus {
				t.Fatalf("beklenen %d, alınan %d", tt.wantStatus, resp.StatusCode)
			}
		})
	}
}

func TestGuideApplyNormalizesCityAndStampsTerms(t *testing.T) {
	store := &fakeGuideStore{}
	app := setupGuideApp(store, &fakeGuideVenueLister{}, "u1", "traveler")
	// Küçük harfli/eksik girdi normalize edilerek kaydedilmeli.
	resp := doJSON(t, app, http.MethodPost, "/guide/apply", `{"city":"istanbul","terms_accepted":true}`)
	if resp.StatusCode != fiber.StatusCreated {
		t.Fatalf("beklenen 201, alınan %d", resp.StatusCode)
	}
	if store.gotCreated.City != "İstanbul" {
		t.Fatalf("şehir normalize edilmedi: %q", store.gotCreated.City)
	}
	if store.gotCreated.UserID != "u1" {
		t.Fatalf("userID %q, beklenen u1", store.gotCreated.UserID)
	}
	// Şartların kabul zamanı damgalanmalı — sonradan ihtilafta kanıt.
	if store.gotCreated.TermsAcceptedAt == nil {
		t.Fatal("TermsAcceptedAt damgalanmalıydı")
	}
}

// --- MyVenues ---

func TestGuideMyVenues(t *testing.T) {
	t.Run("başarılı — yalnızca kendi mekanları", func(t *testing.T) {
		vl := &fakeGuideVenueLister{venues: []models.Venue{{ID: "v1"}}}
		resp := doJSON(t, setupGuideApp(&fakeGuideStore{}, vl, "u7", "guide"), http.MethodGet, "/guide/my-venues", "")
		if resp.StatusCode != fiber.StatusOK {
			t.Fatalf("beklenen 200, alınan %d", resp.StatusCode)
		}
		if vl.gotUserID != "u7" {
			t.Fatalf("sorgu userID %q ile yapıldı, beklenen u7", vl.gotUserID)
		}
	})

	t.Run("giriş yapılmamış", func(t *testing.T) {
		resp := doJSON(t, setupGuideApp(&fakeGuideStore{}, &fakeGuideVenueLister{}, "", ""), http.MethodGet, "/guide/my-venues", "")
		if resp.StatusCode != fiber.StatusUnauthorized {
			t.Fatalf("beklenen 401, alınan %d", resp.StatusCode)
		}
	})

	t.Run("db hatası", func(t *testing.T) {
		vl := &fakeGuideVenueLister{err: errors.New("db")}
		resp := doJSON(t, setupGuideApp(&fakeGuideStore{}, vl, "u1", "guide"), http.MethodGet, "/guide/my-venues", "")
		if resp.StatusCode != fiber.StatusInternalServerError {
			t.Fatalf("beklenen 500, alınan %d", resp.StatusCode)
		}
	})
}

// --- MyApplication ---

func TestGuideMyApplication(t *testing.T) {
	tests := []struct {
		name       string
		userID     string
		store      *fakeGuideStore
		wantStatus int
	}{
		{name: "başvuru var", userID: "u1", store: &fakeGuideStore{latest: &models.GuideApplication{Status: "pending"}}, wantStatus: fiber.StatusOK},
		{name: "giriş yapılmamış", userID: "", store: &fakeGuideStore{}, wantStatus: fiber.StatusUnauthorized},
		// Başvuru yokluğu 404; mobil bunu "hiç başvurmamış" olarak yorumluyor.
		{name: "başvuru yok — 404", userID: "u1", store: &fakeGuideStore{latestErr: repository.ErrNotFound}, wantStatus: fiber.StatusNotFound},
		{name: "db hatası — 500", userID: "u1", store: &fakeGuideStore{latestErr: errors.New("db")}, wantStatus: fiber.StatusInternalServerError},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			app := setupGuideApp(tt.store, &fakeGuideVenueLister{}, tt.userID, "traveler")
			resp := doJSON(t, app, http.MethodGet, "/guide/my-application", "")
			if resp.StatusCode != tt.wantStatus {
				t.Fatalf("beklenen %d, alınan %d", tt.wantStatus, resp.StatusCode)
			}
		})
	}
}
