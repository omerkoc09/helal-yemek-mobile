package handlers

import (
	"context"
	"errors"
	"net/http"
	"strings"
	"testing"

	"github.com/gofiber/fiber/v2"
	"golang.org/x/crypto/bcrypt"

	"github.com/omerkoc/itimat-mobile/internal/models"
	"github.com/omerkoc/itimat-mobile/internal/repository"
)

// --- kullanıcı yönetimi için genişletilmiş fake'ler ---

type fakeAdminUserMgmtStore struct {
	adminUserStore

	existing  *models.User
	findErr   error
	updateErr error
	deleteErr error
	passErr   error

	gotUpdateID   string
	gotRole       *models.Role
	gotGuideCity  *string
	gotDeleteID   string
	gotPassHash   string
	clearCityCall int
}

func (f *fakeAdminUserMgmtStore) FindByID(_ context.Context, _ string) (*models.User, error) {
	if f.findErr != nil {
		return nil, f.findErr
	}
	if f.existing == nil {
		return &models.User{ID: "u1", Role: models.RoleTraveler}, nil
	}
	return f.existing, nil
}

func (f *fakeAdminUserMgmtStore) Update(_ context.Context, id string, _, _, _, _ *string,
	role *models.Role, _ *bool, guideCity *string) error {
	f.gotUpdateID, f.gotRole, f.gotGuideCity = id, role, guideCity
	return f.updateErr
}

func (f *fakeAdminUserMgmtStore) Delete(_ context.Context, id string) error {
	f.gotDeleteID = id
	return f.deleteErr
}

func (f *fakeAdminUserMgmtStore) UpdatePassword(_ context.Context, _, hashed string) error {
	f.gotPassHash = hashed
	return f.passErr
}

func (f *fakeAdminUserMgmtStore) ClearGuideCity(_ context.Context, _ string) error {
	f.clearCityCall++
	return nil
}

type fakeAdminGuideCancelStore struct {
	adminGuideStore
	cancelCalls int
}

func (f *fakeAdminGuideCancelStore) CancelOpenByUserID(_ context.Context, _ string) error {
	f.cancelCalls++
	return nil
}

func setupAdminUserApp(us adminUserStore, gs adminGuideStore, adminID string) *fiber.App {
	app := fiber.New()
	h := &AdminHandler{
		userRepo:               us,
		guideRepo:              gs,
		auditRepo:              &fakeAdminAuditStore{},
		verificationPeriodDays: 180,
	}
	app.Use(func(c *fiber.Ctx) error {
		if adminID != "" {
			c.Locals("userID", adminID)
			c.Locals("userRole", "admin")
		}
		return c.Next()
	})
	app.Put("/admin/users/:id", h.UpdateUser)
	app.Delete("/admin/users/:id", h.DeleteUser)
	app.Put("/admin/users/:id/password", h.UpdateUserPassword)
	return app
}

// --- UpdateUser: şehir normalizasyonu ---

func TestAdminUpdateUserGuideCity(t *testing.T) {
	t.Run("şehir kanonik hale getirilir", func(t *testing.T) {
		us := &fakeAdminUserMgmtStore{}
		app := setupAdminUserApp(us, &fakeAdminGuideCancelStore{}, "a1")
		resp := doJSON(t, app, http.MethodPut, "/admin/users/u1", `{"guide_city":"istanbul"}`)
		if resp.StatusCode != fiber.StatusOK {
			t.Fatalf("beklenen 200, alınan %d", resp.StatusCode)
		}
		if us.gotGuideCity == nil || *us.gotGuideCity != "İstanbul" {
			t.Fatalf("şehir normalize edilmedi: %v", us.gotGuideCity)
		}
	})

	t.Run("boş şehir temizleme sinyali olarak geçer", func(t *testing.T) {
		us := &fakeAdminUserMgmtStore{}
		app := setupAdminUserApp(us, &fakeAdminGuideCancelStore{}, "a1")
		doJSON(t, app, http.MethodPut, "/admin/users/u1", `{"guide_city":"  "}`)
		if us.gotGuideCity == nil || *us.gotGuideCity != "" {
			t.Fatalf("boş şehir beklendi, alınan: %v", us.gotGuideCity)
		}
	})

	t.Run("geçersiz şehir 400", func(t *testing.T) {
		app := setupAdminUserApp(&fakeAdminUserMgmtStore{}, &fakeAdminGuideCancelStore{}, "a1")
		resp := doJSON(t, app, http.MethodPut, "/admin/users/u1", `{"guide_city":"Gotham"}`)
		if resp.StatusCode != fiber.StatusBadRequest {
			t.Fatalf("beklenen 400, alınan %d", resp.StatusCode)
		}
	})
}

// --- UpdateUser: rehberlikten düşürme (demote) ---

func TestAdminUpdateUserDemote(t *testing.T) {
	traveler := models.RoleTraveler
	guide := models.RoleGuide

	t.Run("guide'dan traveler'a düşünce şehir temizlenir ve başvurular kapanır", func(t *testing.T) {
		// Aksi halde kullanıcı guide değil ama guide_city'si duruyor olur ve
		// yeniden başvuramaz (açık başvurusu kapanmadığı için).
		us := &fakeAdminUserMgmtStore{existing: &models.User{ID: "u1", Role: guide}}
		gs := &fakeAdminGuideCancelStore{}
		app := setupAdminUserApp(us, gs, "a1")
		doJSON(t, app, http.MethodPut, "/admin/users/u1", `{"role":"traveler"}`)

		if us.clearCityCall != 1 {
			t.Fatalf("guide_city temizlenmeliydi, çağrı: %d", us.clearCityCall)
		}
		if gs.cancelCalls != 1 {
			t.Fatalf("açık başvurular kapatılmalıydı, çağrı: %d", gs.cancelCalls)
		}
	})

	t.Run("guide olarak kalıyorsa temizlik yapılmaz", func(t *testing.T) {
		us := &fakeAdminUserMgmtStore{existing: &models.User{ID: "u1", Role: guide}}
		gs := &fakeAdminGuideCancelStore{}
		app := setupAdminUserApp(us, gs, "a1")
		doJSON(t, app, http.MethodPut, "/admin/users/u1", `{"role":"guide"}`)

		if us.clearCityCall != 0 || gs.cancelCalls != 0 {
			t.Fatalf("guide kalırken temizlik yapılmamalıydı: city=%d cancel=%d", us.clearCityCall, gs.cancelCalls)
		}
	})

	t.Run("zaten guide değilse temizlik yapılmaz", func(t *testing.T) {
		us := &fakeAdminUserMgmtStore{existing: &models.User{ID: "u1", Role: traveler}}
		gs := &fakeAdminGuideCancelStore{}
		app := setupAdminUserApp(us, gs, "a1")
		doJSON(t, app, http.MethodPut, "/admin/users/u1", `{"role":"admin"}`)

		if us.clearCityCall != 0 || gs.cancelCalls != 0 {
			t.Fatalf("traveler'dan yükseltmede temizlik yapılmamalıydı")
		}
	})

	t.Run("rol gönderilmemişse temizlik yapılmaz", func(t *testing.T) {
		us := &fakeAdminUserMgmtStore{existing: &models.User{ID: "u1", Role: guide}}
		gs := &fakeAdminGuideCancelStore{}
		app := setupAdminUserApp(us, gs, "a1")
		doJSON(t, app, http.MethodPut, "/admin/users/u1", `{"name":"Yeni Ad"}`)

		if us.clearCityCall != 0 || gs.cancelCalls != 0 {
			t.Fatalf("rol değişmediğinde temizlik yapılmamalıydı")
		}
	})
}

func TestAdminUpdateUserErrors(t *testing.T) {
	t.Run("bozuk JSON", func(t *testing.T) {
		app := setupAdminUserApp(&fakeAdminUserMgmtStore{}, &fakeAdminGuideCancelStore{}, "a1")
		resp := doJSON(t, app, http.MethodPut, "/admin/users/u1", `{bozuk`)
		if resp.StatusCode != fiber.StatusBadRequest {
			t.Fatalf("beklenen 400, alınan %d", resp.StatusCode)
		}
	})

	t.Run("kullanıcı bulunamadı", func(t *testing.T) {
		us := &fakeAdminUserMgmtStore{updateErr: repository.ErrNotFound}
		app := setupAdminUserApp(us, &fakeAdminGuideCancelStore{}, "a1")
		resp := doJSON(t, app, http.MethodPut, "/admin/users/u1", `{"name":"x"}`)
		if resp.StatusCode != fiber.StatusNotFound {
			t.Fatalf("beklenen 404, alınan %d", resp.StatusCode)
		}
	})

	t.Run("db hatası", func(t *testing.T) {
		us := &fakeAdminUserMgmtStore{updateErr: errors.New("db")}
		app := setupAdminUserApp(us, &fakeAdminGuideCancelStore{}, "a1")
		resp := doJSON(t, app, http.MethodPut, "/admin/users/u1", `{"name":"x"}`)
		if resp.StatusCode != fiber.StatusInternalServerError {
			t.Fatalf("beklenen 500, alınan %d", resp.StatusCode)
		}
	})
}

// --- DeleteUser ---

func TestAdminDeleteUser(t *testing.T) {
	t.Run("admin kendini silemez", func(t *testing.T) {
		// Kendini silme, sistemin son admin'siz kalmasına yol açabilir.
		us := &fakeAdminUserMgmtStore{}
		app := setupAdminUserApp(us, &fakeAdminGuideCancelStore{}, "admin-1")
		resp := doJSON(t, app, http.MethodDelete, "/admin/users/admin-1", "")
		if resp.StatusCode != fiber.StatusBadRequest {
			t.Fatalf("beklenen 400, alınan %d", resp.StatusCode)
		}
		if us.gotDeleteID != "" {
			t.Fatal("repo'ya silme çağrısı gitmemeliydi")
		}
	})

	t.Run("başka kullanıcı silinebilir", func(t *testing.T) {
		us := &fakeAdminUserMgmtStore{}
		app := setupAdminUserApp(us, &fakeAdminGuideCancelStore{}, "admin-1")
		resp := doJSON(t, app, http.MethodDelete, "/admin/users/u9", "")
		if resp.StatusCode != fiber.StatusOK {
			t.Fatalf("beklenen 200, alınan %d", resp.StatusCode)
		}
		if us.gotDeleteID != "u9" {
			t.Fatalf("silinen id %q, beklenen u9", us.gotDeleteID)
		}
	})

	t.Run("giriş yapılmamış", func(t *testing.T) {
		app := setupAdminUserApp(&fakeAdminUserMgmtStore{}, &fakeAdminGuideCancelStore{}, "")
		resp := doJSON(t, app, http.MethodDelete, "/admin/users/u9", "")
		if resp.StatusCode != fiber.StatusUnauthorized {
			t.Fatalf("beklenen 401, alınan %d", resp.StatusCode)
		}
	})

	t.Run("kullanıcı bulunamadı", func(t *testing.T) {
		us := &fakeAdminUserMgmtStore{deleteErr: repository.ErrNotFound}
		app := setupAdminUserApp(us, &fakeAdminGuideCancelStore{}, "admin-1")
		resp := doJSON(t, app, http.MethodDelete, "/admin/users/u9", "")
		if resp.StatusCode != fiber.StatusNotFound {
			t.Fatalf("beklenen 404, alınan %d", resp.StatusCode)
		}
	})
}

// --- UpdateUserPassword ---

func TestAdminUpdateUserPassword(t *testing.T) {
	t.Run("şifre hash'lenerek saklanır", func(t *testing.T) {
		// En kritik kontrol: düz metin şifre veritabanına gitmemeli.
		us := &fakeAdminUserMgmtStore{}
		app := setupAdminUserApp(us, &fakeAdminGuideCancelStore{}, "a1")
		resp := doJSON(t, app, http.MethodPut, "/admin/users/u1/password", `{"password":"yeniSifre123"}`)
		if resp.StatusCode != fiber.StatusOK {
			t.Fatalf("beklenen 200, alınan %d", resp.StatusCode)
		}
		if us.gotPassHash == "yeniSifre123" {
			t.Fatal("şifre DÜZ METİN olarak saklandı")
		}
		if !strings.HasPrefix(us.gotPassHash, "$2a$") && !strings.HasPrefix(us.gotPassHash, "$2b$") {
			t.Fatalf("bcrypt hash beklendi, alınan: %q", us.gotPassHash)
		}
		// Hash gerçekten bu şifreyi doğrulamalı.
		if err := bcrypt.CompareHashAndPassword([]byte(us.gotPassHash), []byte("yeniSifre123")); err != nil {
			t.Fatalf("hash şifreyi doğrulamıyor: %v", err)
		}
	})

	t.Run("kısa şifre reddedilir", func(t *testing.T) {
		app := setupAdminUserApp(&fakeAdminUserMgmtStore{}, &fakeAdminGuideCancelStore{}, "a1")
		resp := doJSON(t, app, http.MethodPut, "/admin/users/u1/password", `{"password":"12345"}`)
		if resp.StatusCode != fiber.StatusBadRequest {
			t.Fatalf("beklenen 400, alınan %d", resp.StatusCode)
		}
	})

	t.Run("6 karakter sınırda kabul", func(t *testing.T) {
		us := &fakeAdminUserMgmtStore{}
		app := setupAdminUserApp(us, &fakeAdminGuideCancelStore{}, "a1")
		resp := doJSON(t, app, http.MethodPut, "/admin/users/u1/password", `{"password":"123456"}`)
		if resp.StatusCode != fiber.StatusOK {
			t.Fatalf("beklenen 200, alınan %d", resp.StatusCode)
		}
	})

	t.Run("bozuk JSON", func(t *testing.T) {
		app := setupAdminUserApp(&fakeAdminUserMgmtStore{}, &fakeAdminGuideCancelStore{}, "a1")
		resp := doJSON(t, app, http.MethodPut, "/admin/users/u1/password", `{bozuk`)
		if resp.StatusCode != fiber.StatusBadRequest {
			t.Fatalf("beklenen 400, alınan %d", resp.StatusCode)
		}
	})

	t.Run("kullanıcı bulunamadı", func(t *testing.T) {
		us := &fakeAdminUserMgmtStore{passErr: repository.ErrNotFound}
		app := setupAdminUserApp(us, &fakeAdminGuideCancelStore{}, "a1")
		resp := doJSON(t, app, http.MethodPut, "/admin/users/u1/password", `{"password":"123456"}`)
		if resp.StatusCode != fiber.StatusNotFound {
			t.Fatalf("beklenen 404, alınan %d", resp.StatusCode)
		}
	})
}
