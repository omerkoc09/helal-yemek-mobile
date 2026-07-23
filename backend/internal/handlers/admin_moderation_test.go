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

// Admin arayüzleri geniş olduğu için fake'ler arayüzü GÖMER: yalnızca testin
// kullandığı metotlar override edilir, kalanı çağrılırsa nil-pointer panic
// olur. Bu kasıtlı — "stub'lamadığın bir şeyi çağırdın" sinyali verir ve
// onlarca boş metot yazmaktan kurtarır.

type fakeAdminVenueStore struct {
	adminVenueStore // gömülü: override edilmeyenler çağrılırsa panic

	approveErr error
	rejectErr  error

	gotID      string
	gotAdminID string
	gotPeriod  int
	gotNote    *string
}

func (f *fakeAdminVenueStore) Approve(_ context.Context, id, adminID string, periodDays int) error {
	f.gotID, f.gotAdminID, f.gotPeriod = id, adminID, periodDays
	return f.approveErr
}

func (f *fakeAdminVenueStore) Reject(_ context.Context, id, adminID string, note *string) error {
	f.gotID, f.gotAdminID, f.gotNote = id, adminID, note
	return f.rejectErr
}

type fakeAdminGuideStore struct {
	adminGuideStore

	// ApproveApplication artık atomik: statü+rol+şehir repo transaction'ında.
	// Fake yalnızca sonuç/hata döndürür; atomiklik integration testinde sınanır.
	approveUserID string
	approveErr    error

	updateErr error // UpdateStatus (reddetme akışı) için

	gotApproveID  string
	gotApproveAdm string
	gotStatus     models.ApplicationStatus
	gotNote       *string
}

func (f *fakeAdminGuideStore) ApproveApplication(_ context.Context, appID, adminID string) (string, error) {
	f.gotApproveID, f.gotApproveAdm = appID, adminID
	if f.approveErr != nil {
		return "", f.approveErr
	}
	if f.approveUserID == "" {
		return "user-1", nil
	}
	return f.approveUserID, nil
}

func (f *fakeAdminGuideStore) UpdateStatus(_ context.Context, _, _ string, status models.ApplicationStatus, note *string) error {
	f.gotStatus, f.gotNote = status, note
	return f.updateErr
}

type fakeAdminUserStore struct {
	adminUserStore

	roleErr error
	cityErr error

	gotRoleUserID string
	gotRole       models.Role
	gotCityUserID string
	gotCity       string
}

func (f *fakeAdminUserStore) UpdateRole(_ context.Context, id string, role models.Role) error {
	f.gotRoleUserID, f.gotRole = id, role
	return f.roleErr
}

func (f *fakeAdminUserStore) SetGuideCity(_ context.Context, userID, city string) error {
	f.gotCityUserID, f.gotCity = userID, city
	return f.cityErr
}

type fakeAdminAuditStore struct {
	adminAuditStore
	logs []*models.AuditLog
}

func (f *fakeAdminAuditStore) Create(_ context.Context, l *models.AuditLog) error {
	f.logs = append(f.logs, l)
	return nil
}

// --- helper ---

func setupAdminApp(vs adminVenueStore, gs adminGuideStore, us adminUserStore,
	as adminAuditStore, adminID string) *fiber.App {
	app := fiber.New()
	h := &AdminHandler{
		venueRepo:              vs,
		guideRepo:              gs,
		userRepo:               us,
		auditRepo:              as,
		verificationPeriodDays: 180,
	}
	app.Use(func(c *fiber.Ctx) error {
		if adminID != "" {
			c.Locals("userID", adminID)
			c.Locals("userRole", "admin")
		}
		return c.Next()
	})
	app.Put("/admin/venues/:id/approve", h.ApproveVenue)
	app.Put("/admin/venues/:id/reject", h.RejectVenue)
	app.Put("/admin/applications/:id/approve", h.ApproveApplication)
	app.Put("/admin/applications/:id/reject", h.RejectApplication)
	return app
}

// --- Mekan moderasyonu ---

func TestAdminApproveVenue(t *testing.T) {
	tests := []struct {
		name       string
		adminID    string
		approveErr error
		wantStatus int
	}{
		{name: "başarılı", adminID: "a1", wantStatus: fiber.StatusOK},
		{name: "giriş yapılmamış", adminID: "", wantStatus: fiber.StatusUnauthorized},
		{name: "mekan bulunamadı", adminID: "a1", approveErr: repository.ErrNotFound, wantStatus: fiber.StatusNotFound},
		{name: "db hatası", adminID: "a1", approveErr: errors.New("db"), wantStatus: fiber.StatusInternalServerError},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			vs := &fakeAdminVenueStore{approveErr: tt.approveErr}
			app := setupAdminApp(vs, &fakeAdminGuideStore{}, &fakeAdminUserStore{}, &fakeAdminAuditStore{}, tt.adminID)
			resp := doJSON(t, app, http.MethodPut, "/admin/venues/v1/approve", "")
			if resp.StatusCode != tt.wantStatus {
				t.Fatalf("beklenen %d, alınan %d", tt.wantStatus, resp.StatusCode)
			}
		})
	}
}

func TestAdminApproveVenueRecordsWhoAndPeriod(t *testing.T) {
	vs := &fakeAdminVenueStore{}
	audit := &fakeAdminAuditStore{}
	app := setupAdminApp(vs, &fakeAdminGuideStore{}, &fakeAdminUserStore{}, audit, "admin-9")
	doJSON(t, app, http.MethodPut, "/admin/venues/v42/approve", "")

	// Onaylayan admin kaydedilmeli — kim onayladı sorusunun cevabı.
	if vs.gotID != "v42" || vs.gotAdminID != "admin-9" {
		t.Fatalf("venue/admin yanlış: %s/%s", vs.gotID, vs.gotAdminID)
	}
	// Doğrulama periyodu config'den gelmeli; sabit kodlanırsa prod ayarı etkisiz kalır.
	if vs.gotPeriod != 180 {
		t.Fatalf("periyot %d, beklenen 180", vs.gotPeriod)
	}
	if len(audit.logs) != 1 || audit.logs[0].Action != "approve_venue" || audit.logs[0].TargetID != "v42" {
		t.Fatalf("denetim kaydı yanlış: %+v", audit.logs)
	}
}

func TestAdminRejectVenue(t *testing.T) {
	t.Run("gövdesiz istek kabul edilir", func(t *testing.T) {
		// Reddetme notu opsiyonel; boş gövde 400 üretmemeli.
		vs := &fakeAdminVenueStore{}
		app := setupAdminApp(vs, &fakeAdminGuideStore{}, &fakeAdminUserStore{}, &fakeAdminAuditStore{}, "a1")
		resp := doJSON(t, app, http.MethodPut, "/admin/venues/v1/reject", "")
		if resp.StatusCode != fiber.StatusOK {
			t.Fatalf("beklenen 200, alınan %d", resp.StatusCode)
		}
	})

	t.Run("not repo'ya ve denetim kaydına geçer", func(t *testing.T) {
		vs := &fakeAdminVenueStore{}
		audit := &fakeAdminAuditStore{}
		app := setupAdminApp(vs, &fakeAdminGuideStore{}, &fakeAdminUserStore{}, audit, "a1")
		doJSON(t, app, http.MethodPut, "/admin/venues/v1/reject", `{"note":"adres hatalı"}`)
		if vs.gotNote == nil || *vs.gotNote != "adres hatalı" {
			t.Fatalf("not repo'ya geçmedi: %v", vs.gotNote)
		}
		if len(audit.logs) != 1 || audit.logs[0].Action != "reject_venue" {
			t.Fatalf("denetim kaydı yanlış: %+v", audit.logs)
		}
	})

	t.Run("mekan bulunamadı", func(t *testing.T) {
		vs := &fakeAdminVenueStore{rejectErr: repository.ErrNotFound}
		app := setupAdminApp(vs, &fakeAdminGuideStore{}, &fakeAdminUserStore{}, &fakeAdminAuditStore{}, "a1")
		resp := doJSON(t, app, http.MethodPut, "/admin/venues/v1/reject", "")
		if resp.StatusCode != fiber.StatusNotFound {
			t.Fatalf("beklenen 404, alınan %d", resp.StatusCode)
		}
	})
}

// --- Rehber başvurusu: yetki yükseltme ---

func TestAdminApproveApplicationGrantsGuideRole(t *testing.T) {
	// Onay artık atomik: handler tek ApproveApplication çağırıyor, statü+rol+
	// şehir repo transaction'ında birlikte uygulanıyor. Handler seviyesinde
	// doğrulanan: doğru başvuru id + admin id geçiliyor ve denetim kaydı yazılıyor.
	// Atomikliğin kendisi repository integration testinde sınanır.
	gs := &fakeAdminGuideStore{approveUserID: "user-7"}
	audit := &fakeAdminAuditStore{}
	app := setupAdminApp(&fakeAdminVenueStore{}, gs, &fakeAdminUserStore{}, audit, "admin-3")

	resp := doJSON(t, app, http.MethodPut, "/admin/applications/app1/approve", "")
	if resp.StatusCode != fiber.StatusOK {
		t.Fatalf("beklenen 200, alınan %d", resp.StatusCode)
	}
	if gs.gotApproveID != "app1" || gs.gotApproveAdm != "admin-3" {
		t.Fatalf("ApproveApplication yanlış argümanlarla çağrıldı: id=%s adm=%s",
			gs.gotApproveID, gs.gotApproveAdm)
	}
	if len(audit.logs) != 1 || audit.logs[0].Action != "approve_guide_application" {
		t.Fatalf("denetim kaydı yanlış: %+v", audit.logs)
	}
}

func TestAdminApproveApplicationErrors(t *testing.T) {
	tests := []struct {
		name       string
		adminID    string
		gs         *fakeAdminGuideStore
		wantStatus int
	}{
		{name: "giriş yapılmamış", adminID: "", gs: &fakeAdminGuideStore{}, wantStatus: fiber.StatusUnauthorized},
		{name: "başvuru bulunamadı", adminID: "a1", gs: &fakeAdminGuideStore{approveErr: repository.ErrNotFound}, wantStatus: fiber.StatusNotFound},
		// Aynı başvuru iki admin tarafından işlenirse ikincisi 409 almalı.
		{name: "başvuru zaten incelenmiş — 409", adminID: "a1", gs: &fakeAdminGuideStore{approveErr: repository.ErrAlreadyReviewed}, wantStatus: fiber.StatusConflict},
		// Transaction içinde herhangi bir adım (rol/şehir) patlarsa 500;
		// atomik olduğu için kısmi durum kalmaz.
		{name: "transaction hatası — 500", adminID: "a1", gs: &fakeAdminGuideStore{approveErr: errors.New("db")}, wantStatus: fiber.StatusInternalServerError},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			app := setupAdminApp(&fakeAdminVenueStore{}, tt.gs, &fakeAdminUserStore{}, &fakeAdminAuditStore{}, tt.adminID)
			resp := doJSON(t, app, http.MethodPut, "/admin/applications/app1/approve", "")
			if resp.StatusCode != tt.wantStatus {
				t.Fatalf("beklenen %d, alınan %d", tt.wantStatus, resp.StatusCode)
			}
		})
	}
}

func TestAdminApproveApplicationCityFailureIsNotTolerated(t *testing.T) {
	// DAVRANIŞ DEĞİŞTİ (2026-07-23, ürün kararı): şehir yazılamazsa artık istek
	// BAŞARISIZ oluyor ve hiçbir kısmi değişiklik kalmıyor. Eskiden 200 dönüp
	// kullanıcı "guide ama şehirsiz" kalıyordu; bu, şehir kısıtına dayanan
	// akışları (ConfirmVenue, Create) sessizce bozuyordu.
	//
	// Atomiklik repo transaction'ında sağlanıyor; handler seviyesinde bu senaryo
	// approveErr olarak temsil edilir (transaction rollback -> hata döner).
	gs := &fakeAdminGuideStore{approveErr: errors.New("guide_city yazılamadı")}
	app := setupAdminApp(&fakeAdminVenueStore{}, gs, &fakeAdminUserStore{}, &fakeAdminAuditStore{}, "a1")

	resp := doJSON(t, app, http.MethodPut, "/admin/applications/app1/approve", "")
	if resp.StatusCode != fiber.StatusInternalServerError {
		t.Fatalf("beklenen 500 (kısmi başarı tolere EDİLMEZ), alınan %d", resp.StatusCode)
	}
}

func TestAdminRejectApplication(t *testing.T) {
	t.Run("başarılı — not iletilir", func(t *testing.T) {
		gs := &fakeAdminGuideStore{}
		audit := &fakeAdminAuditStore{}
		app := setupAdminApp(&fakeAdminVenueStore{}, gs, &fakeAdminUserStore{}, audit, "a1")
		resp := doJSON(t, app, http.MethodPut, "/admin/applications/app1/reject", `{"note":"eksik bilgi"}`)
		if resp.StatusCode != fiber.StatusOK {
			t.Fatalf("beklenen 200, alınan %d", resp.StatusCode)
		}
		if gs.gotStatus != models.ApplicationStatusRejected {
			t.Fatalf("durum %q, beklenen rejected", gs.gotStatus)
		}
		if gs.gotNote == nil || *gs.gotNote != "eksik bilgi" {
			t.Fatalf("not iletilmedi: %v", gs.gotNote)
		}
		if len(audit.logs) != 1 || audit.logs[0].Action != "reject_guide_application" {
			t.Fatalf("denetim kaydı yanlış: %+v", audit.logs)
		}
	})

	t.Run("reddetme rol vermez", func(t *testing.T) {
		// Reddedilen başvuruda UpdateRole ÇAĞRILMAMALI. Çağrılsaydı fake'in
		// gömülü arayüzü nil olduğundan panic olurdu; burada açıkça kontrol ediyoruz.
		us := &fakeAdminUserStore{}
		app := setupAdminApp(&fakeAdminVenueStore{}, &fakeAdminGuideStore{}, us, &fakeAdminAuditStore{}, "a1")
		doJSON(t, app, http.MethodPut, "/admin/applications/app1/reject", `{"note":"x"}`)
		if us.gotRoleUserID != "" {
			t.Fatalf("reddetmede rol atanmamalıydı, atanan: %s", us.gotRoleUserID)
		}
	})

	t.Run("bozuk JSON", func(t *testing.T) {
		app := setupAdminApp(&fakeAdminVenueStore{}, &fakeAdminGuideStore{}, &fakeAdminUserStore{}, &fakeAdminAuditStore{}, "a1")
		resp := doJSON(t, app, http.MethodPut, "/admin/applications/app1/reject", `{bozuk`)
		if resp.StatusCode != fiber.StatusBadRequest {
			t.Fatalf("beklenen 400, alınan %d", resp.StatusCode)
		}
	})

	t.Run("başvuru bulunamadı", func(t *testing.T) {
		gs := &fakeAdminGuideStore{updateErr: repository.ErrNotFound}
		app := setupAdminApp(&fakeAdminVenueStore{}, gs, &fakeAdminUserStore{}, &fakeAdminAuditStore{}, "a1")
		resp := doJSON(t, app, http.MethodPut, "/admin/applications/app1/reject", `{"note":"x"}`)
		if resp.StatusCode != fiber.StatusNotFound {
			t.Fatalf("beklenen 404, alınan %d", resp.StatusCode)
		}
	})
}
