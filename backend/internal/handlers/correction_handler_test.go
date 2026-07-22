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

type fakeCorrectionStore struct {
	pending   []models.CorrectionSuggestion
	found     *models.CorrectionSuggestion
	createErr error
	listErr   error
	findErr   error
	updateErr error

	gotCreated *models.CorrectionSuggestion
	gotStatus  models.CorrectionStatus
	gotAdminID string
}

func (f *fakeCorrectionStore) Create(_ context.Context, cs *models.CorrectionSuggestion) error {
	f.gotCreated = cs
	return f.createErr
}

func (f *fakeCorrectionStore) ListPending(_ context.Context) ([]models.CorrectionSuggestion, error) {
	return f.pending, f.listErr
}

func (f *fakeCorrectionStore) FindByID(_ context.Context, _ string) (*models.CorrectionSuggestion, error) {
	if f.findErr != nil {
		return nil, f.findErr
	}
	if f.found == nil {
		return &models.CorrectionSuggestion{ID: "c1"}, nil
	}
	return f.found, nil
}

func (f *fakeCorrectionStore) UpdateStatus(_ context.Context, _, adminID string, status models.CorrectionStatus, _ *string) error {
	f.gotAdminID, f.gotStatus = adminID, status
	return f.updateErr
}

type fakeAuditLogger struct {
	logs []*models.AuditLog
	err  error
}

func (f *fakeAuditLogger) Create(_ context.Context, l *models.AuditLog) error {
	f.logs = append(f.logs, l)
	return f.err
}

// --- helper ---

func setupCorrectionApp(store correctionStore, audit auditLogger, userID string) *fiber.App {
	app := fiber.New()
	h := &CorrectionHandler{correctionRepo: store, auditRepo: audit}
	app.Use(func(c *fiber.Ctx) error {
		if userID != "" {
			c.Locals("userID", userID)
		}
		return c.Next()
	})
	app.Post("/venues/:id/corrections", h.Create)
	app.Get("/admin/corrections", h.ListPending)
	app.Put("/admin/corrections/:id", h.Review)
	return app
}

// --- Create ---

func TestCorrectionCreate(t *testing.T) {
	tests := []struct {
		name       string
		userID     string
		body       string
		createErr  error
		wantStatus int
	}{
		{name: "başarılı", userID: "u1", body: `{"field_name":"name","new_value":"Yeni Ad"}`, wantStatus: fiber.StatusCreated},
		{name: "giriş yapılmamış", userID: "", body: `{"field_name":"name","new_value":"x"}`, wantStatus: fiber.StatusUnauthorized},
		{name: "bozuk JSON", userID: "u1", body: `{bozuk`, wantStatus: fiber.StatusBadRequest},
		{name: "field_name boş", userID: "u1", body: `{"field_name":"","new_value":"x"}`, wantStatus: fiber.StatusBadRequest},
		{name: "new_value boş", userID: "u1", body: `{"field_name":"name","new_value":""}`, wantStatus: fiber.StatusBadRequest},
		{name: "db hatası", userID: "u1", body: `{"field_name":"name","new_value":"x"}`, createErr: errors.New("db"), wantStatus: fiber.StatusInternalServerError},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			store := &fakeCorrectionStore{createErr: tt.createErr}
			app := setupCorrectionApp(store, &fakeAuditLogger{}, tt.userID)
			resp := doJSON(t, app, http.MethodPost, "/venues/v1/corrections", tt.body)
			if resp.StatusCode != tt.wantStatus {
				t.Fatalf("beklenen %d, alınan %d", tt.wantStatus, resp.StatusCode)
			}
		})
	}
}

func TestCorrectionCreateStartsPending(t *testing.T) {
	store := &fakeCorrectionStore{}
	app := setupCorrectionApp(store, &fakeAuditLogger{}, "u3")
	doJSON(t, app, http.MethodPost, "/venues/v8/corrections", `{"field_name":"name","new_value":"Yeni"}`)

	// Öneri her zaman pending başlamalı — istemci status göndererek
	// kendi önerisini onaylı hâle getirememeli.
	if store.gotCreated.Status != models.CorrectionStatusPending {
		t.Fatalf("başlangıç durumu %q, beklenen pending", store.gotCreated.Status)
	}
	if store.gotCreated.VenueID != "v8" || store.gotCreated.SuggestedBy != "u3" {
		t.Fatalf("bağlama yanlış: %+v", store.gotCreated)
	}
}

// --- ListPending ---

func TestCorrectionListPending(t *testing.T) {
	t.Run("başarılı", func(t *testing.T) {
		store := &fakeCorrectionStore{pending: []models.CorrectionSuggestion{{ID: "c1"}}}
		resp := doJSON(t, setupCorrectionApp(store, &fakeAuditLogger{}, "a1"), http.MethodGet, "/admin/corrections", "")
		if resp.StatusCode != fiber.StatusOK {
			t.Fatalf("beklenen 200, alınan %d", resp.StatusCode)
		}
	})

	t.Run("db hatası", func(t *testing.T) {
		store := &fakeCorrectionStore{listErr: errors.New("db")}
		resp := doJSON(t, setupCorrectionApp(store, &fakeAuditLogger{}, "a1"), http.MethodGet, "/admin/corrections", "")
		if resp.StatusCode != fiber.StatusInternalServerError {
			t.Fatalf("beklenen 500, alınan %d", resp.StatusCode)
		}
	})
}

// --- Review ---

func TestCorrectionReview(t *testing.T) {
	tests := []struct {
		name       string
		userID     string
		body       string
		store      *fakeCorrectionStore
		wantStatus int
	}{
		{name: "approve", userID: "a1", body: `{"action":"approve"}`, store: &fakeCorrectionStore{}, wantStatus: fiber.StatusOK},
		{name: "reject", userID: "a1", body: `{"action":"reject"}`, store: &fakeCorrectionStore{}, wantStatus: fiber.StatusOK},
		{name: "giriş yapılmamış", userID: "", body: `{"action":"approve"}`, store: &fakeCorrectionStore{}, wantStatus: fiber.StatusUnauthorized},
		{name: "bozuk JSON", userID: "a1", body: `{bozuk`, store: &fakeCorrectionStore{}, wantStatus: fiber.StatusBadRequest},
		// Tanımsız action sessizce approve'a düşmemeli.
		{name: "geçersiz action", userID: "a1", body: `{"action":"belki"}`, store: &fakeCorrectionStore{}, wantStatus: fiber.StatusBadRequest},
		{name: "action boş", userID: "a1", body: `{"action":""}`, store: &fakeCorrectionStore{}, wantStatus: fiber.StatusBadRequest},
		{name: "öneri bulunamadı", userID: "a1", body: `{"action":"approve"}`, store: &fakeCorrectionStore{findErr: repository.ErrNotFound}, wantStatus: fiber.StatusNotFound},
		{name: "arama db hatası", userID: "a1", body: `{"action":"approve"}`, store: &fakeCorrectionStore{findErr: errors.New("db")}, wantStatus: fiber.StatusInternalServerError},
		{name: "güncelleme db hatası", userID: "a1", body: `{"action":"approve"}`, store: &fakeCorrectionStore{updateErr: errors.New("db")}, wantStatus: fiber.StatusInternalServerError},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			app := setupCorrectionApp(tt.store, &fakeAuditLogger{}, tt.userID)
			resp := doJSON(t, app, http.MethodPut, "/admin/corrections/c1", tt.body)
			if resp.StatusCode != tt.wantStatus {
				t.Fatalf("beklenen %d, alınan %d", tt.wantStatus, resp.StatusCode)
			}
		})
	}
}

func TestCorrectionReviewMapsActionToStatus(t *testing.T) {
	t.Run("approve -> approved", func(t *testing.T) {
		store := &fakeCorrectionStore{}
		doJSON(t, setupCorrectionApp(store, &fakeAuditLogger{}, "a1"), http.MethodPut, "/admin/corrections/c1", `{"action":"approve"}`)
		if store.gotStatus != models.CorrectionStatusApproved {
			t.Fatalf("durum %q, beklenen approved", store.gotStatus)
		}
		if store.gotAdminID != "a1" {
			t.Fatalf("adminID %q, beklenen a1", store.gotAdminID)
		}
	})

	t.Run("reject -> rejected", func(t *testing.T) {
		store := &fakeCorrectionStore{}
		doJSON(t, setupCorrectionApp(store, &fakeAuditLogger{}, "a1"), http.MethodPut, "/admin/corrections/c1", `{"action":"reject"}`)
		if store.gotStatus != models.CorrectionStatusRejected {
			t.Fatalf("durum %q, beklenen rejected", store.gotStatus)
		}
	})
}

func TestCorrectionReviewWritesAuditLog(t *testing.T) {
	// Admin kararları denetlenebilir olmalı: kim, neyi, ne zaman onayladı.
	t.Run("approve denetim kaydı", func(t *testing.T) {
		audit := &fakeAuditLogger{}
		doJSON(t, setupCorrectionApp(&fakeCorrectionStore{}, audit, "a1"), http.MethodPut, "/admin/corrections/c9", `{"action":"approve"}`)
		if len(audit.logs) != 1 {
			t.Fatalf("1 denetim kaydı bekleniyordu, %d bulundu", len(audit.logs))
		}
		l := audit.logs[0]
		if l.Action != "approve_correction" || l.TargetID != "c9" || l.AdminID != "a1" {
			t.Fatalf("denetim kaydı yanlış: %+v", l)
		}
	})

	t.Run("reject denetim kaydı", func(t *testing.T) {
		audit := &fakeAuditLogger{}
		doJSON(t, setupCorrectionApp(&fakeCorrectionStore{}, audit, "a1"), http.MethodPut, "/admin/corrections/c9", `{"action":"reject"}`)
		if len(audit.logs) != 1 || audit.logs[0].Action != "reject_correction" {
			t.Fatalf("reject denetim kaydı yanlış: %+v", audit.logs)
		}
	})

	// Denetim kaydı yazılamazsa istek yine de başarılı dönmeli (mevcut davranış):
	// admin kararı kaybolmamalı. Bu testi kırmak davranış değişikliğini haber verir.
	t.Run("denetim hatası isteği düşürmez", func(t *testing.T) {
		audit := &fakeAuditLogger{err: errors.New("audit db")}
		resp := doJSON(t, setupCorrectionApp(&fakeCorrectionStore{}, audit, "a1"), http.MethodPut, "/admin/corrections/c1", `{"action":"approve"}`)
		if resp.StatusCode != fiber.StatusOK {
			t.Fatalf("beklenen 200, alınan %d", resp.StatusCode)
		}
	})
}
