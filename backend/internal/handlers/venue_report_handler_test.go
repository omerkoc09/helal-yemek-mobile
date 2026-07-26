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

// --- fakeReportStore ---

type fakeReportStore struct {
	reports    []models.VenueReport
	createErr  error
	listErr    error
	resolveErr error

	gotCreated *models.VenueReport
	gotResolve string
}

func (f *fakeReportStore) Create(_ context.Context, rp *models.VenueReport) error {
	f.gotCreated = rp
	return f.createErr
}

func (f *fakeReportStore) List(_ context.Context) ([]models.VenueReport, error) {
	return f.reports, f.listErr
}

func (f *fakeReportStore) Resolve(_ context.Context, id string) error {
	f.gotResolve = id
	return f.resolveErr
}

// --- helper ---

func setupReportApp(store reportStore, userID string) *fiber.App {
	app := fiber.New()
	h := &VenueReportHandler{reportRepo: store}
	app.Use(func(c *fiber.Ctx) error {
		if userID != "" {
			c.Locals("userID", userID)
		}
		return c.Next()
	})
	app.Post("/venues/:id/reports", h.Create)
	app.Get("/admin/venue-reports", h.AdminList)
	app.Put("/admin/venue-reports/:id/resolve", h.AdminResolve)
	return app
}

// --- Create: sebep doğrulaması ---

func TestVenueReportCreateReasonValidation(t *testing.T) {
	tests := []struct {
		name       string
		body       string
		wantStatus int
	}{
		// Açıklama gerektirmeyen sebepler tek başına yeterli.
		{name: "closed — açıklamasız kabul", body: `{"reason":"closed"}`, wantStatus: fiber.StatusCreated},
		{name: "wrong_address — açıklamasız kabul", body: `{"reason":"wrong_address"}`, wantStatus: fiber.StatusCreated},

		// Bu üç sebep için açıklama zorunlu: aksi halde admin ne olduğunu bilemez.
		{name: "trust_criteria — açıklamasız reddedilir", body: `{"reason":"trust_criteria"}`, wantStatus: fiber.StatusBadRequest},
		{name: "wrong_food — açıklamasız reddedilir", body: `{"reason":"wrong_food"}`, wantStatus: fiber.StatusBadRequest},
		{name: "other — açıklamasız reddedilir", body: `{"reason":"other"}`, wantStatus: fiber.StatusBadRequest},
		// Boşluktan ibaret açıklama da yok sayılmalı.
		{name: "other — sadece boşluk reddedilir", body: `{"reason":"other","description":"   "}`, wantStatus: fiber.StatusBadRequest},
		{name: "other — geçerli açıklama kabul", body: `{"reason":"other","description":"mekan taşınmış"}`, wantStatus: fiber.StatusCreated},
		{name: "trust_criteria — geçerli açıklama kabul", body: `{"reason":"trust_criteria","description":"alkol servisi var"}`, wantStatus: fiber.StatusCreated},

		{name: "tanımsız sebep", body: `{"reason":"uydurma"}`, wantStatus: fiber.StatusBadRequest},
		{name: "sebep boş", body: `{"reason":""}`, wantStatus: fiber.StatusBadRequest},
		{name: "bozuk JSON", body: `{bozuk`, wantStatus: fiber.StatusBadRequest},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			store := &fakeReportStore{}
			resp := doJSON(t, setupReportApp(store, "u1"), http.MethodPost, "/venues/v1/reports", tt.body)
			if resp.StatusCode != tt.wantStatus {
				t.Fatalf("beklenen %d, alınan %d", tt.wantStatus, resp.StatusCode)
			}
		})
	}
}

func TestVenueReportCreateAuthAndBinding(t *testing.T) {
	t.Run("giriş yapılmamış", func(t *testing.T) {
		resp := doJSON(t, setupReportApp(&fakeReportStore{}, ""), http.MethodPost, "/venues/v1/reports", `{"reason":"closed"}`)
		if resp.StatusCode != fiber.StatusUnauthorized {
			t.Fatalf("beklenen 401, alınan %d", resp.StatusCode)
		}
	})

	t.Run("rapor mekana ve kullanıcıya bağlanır", func(t *testing.T) {
		store := &fakeReportStore{}
		doJSON(t, setupReportApp(store, "u5"), http.MethodPost, "/venues/v42/reports", `{"reason":"closed"}`)
		if store.gotCreated.VenueID != "v42" || store.gotCreated.UserID != "u5" {
			t.Fatalf("bağlama yanlış: %+v", store.gotCreated)
		}
	})

	t.Run("db hatası — 500", func(t *testing.T) {
		store := &fakeReportStore{createErr: errors.New("db")}
		resp := doJSON(t, setupReportApp(store, "u1"), http.MethodPost, "/venues/v1/reports", `{"reason":"closed"}`)
		if resp.StatusCode != fiber.StatusInternalServerError {
			t.Fatalf("beklenen 500, alınan %d", resp.StatusCode)
		}
	})
}

// --- Admin uçları ---

func TestVenueReportAdminList(t *testing.T) {
	t.Run("başarılı", func(t *testing.T) {
		store := &fakeReportStore{reports: []models.VenueReport{{ID: "rp1"}}}
		resp := doJSON(t, setupReportApp(store, "admin1"), http.MethodGet, "/admin/venue-reports", "")
		if resp.StatusCode != fiber.StatusOK {
			t.Fatalf("beklenen 200, alınan %d", resp.StatusCode)
		}
	})

	t.Run("db hatası", func(t *testing.T) {
		store := &fakeReportStore{listErr: errors.New("db")}
		resp := doJSON(t, setupReportApp(store, "admin1"), http.MethodGet, "/admin/venue-reports", "")
		if resp.StatusCode != fiber.StatusInternalServerError {
			t.Fatalf("beklenen 500, alınan %d", resp.StatusCode)
		}
	})
}

func TestVenueReportAdminResolve(t *testing.T) {
	tests := []struct {
		name       string
		resolveErr error
		wantStatus int
	}{
		{name: "başarılı", wantStatus: fiber.StatusNoContent},
		{name: "rapor bulunamadı", resolveErr: repository.ErrNotFound, wantStatus: fiber.StatusNotFound},
		{name: "db hatası", resolveErr: errors.New("db"), wantStatus: fiber.StatusInternalServerError},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			store := &fakeReportStore{resolveErr: tt.resolveErr}
			resp := doJSON(t, setupReportApp(store, "admin1"), http.MethodPut, "/admin/venue-reports/rp9/resolve", "")
			if resp.StatusCode != tt.wantStatus {
				t.Fatalf("beklenen %d, alınan %d", tt.wantStatus, resp.StatusCode)
			}
			if tt.resolveErr == nil && store.gotResolve != "rp9" {
				t.Fatalf("resolve edilen id %q, beklenen rp9", store.gotResolve)
			}
		})
	}
}
