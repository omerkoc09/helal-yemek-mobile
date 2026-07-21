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

	app       *models.GuideApplication
	findErr   error
	updateErr error

	gotStatus models.ApplicationStatus
	gotNote   *string
}

func (f *fakeAdminGuideStore) FindByID(_ context.Context, _ string) (*models.GuideApplication, error) {
	if f.findErr != nil {
		return nil, f.findErr
	}
	if f.app == nil {
		return &models.GuideApplication{ID: "app1", UserID: "u1", City: "Ankara"}, nil
	}
	return f.app, nil
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
	// Bu akış kullanıcıya guide yetkisi veriyor; yanlış çalışırsa ya yetki
	// verilmez ya da yanlış kişiye verilir.
	gs := &fakeAdminGuideStore{app: &models.GuideApplication{ID: "app1", UserID: "user-7", City: "İzmir"}}
	us := &fakeAdminUserStore{}
	audit := &fakeAdminAuditStore{}
	app := setupAdminApp(&fakeAdminVenueStore{}, gs, us, audit, "a1")

	resp := doJSON(t, app, http.MethodPut, "/admin/applications/app1/approve", "")
	if resp.StatusCode != fiber.StatusOK {
		t.Fatalf("beklenen 200, alınan %d", resp.StatusCode)
	}
	if gs.gotStatus != models.ApplicationStatusApproved {
		t.Fatalf("başvuru durumu %q, beklenen approved", gs.gotStatus)
	}
	// Rol, başvurudaki kullanıcıya verilmeli — URL'deki başvuru id'sine değil.
	if us.gotRoleUserID != "user-7" || us.gotRole != models.RoleGuide {
		t.Fatalf("rol ataması yanlış: user=%s role=%s", us.gotRoleUserID, us.gotRole)
	}
	// Şehir başvurudaki beyandan alınmalı.
	if us.gotCityUserID != "user-7" || us.gotCity != "İzmir" {
		t.Fatalf("şehir ataması yanlış: user=%s city=%s", us.gotCityUserID, us.gotCity)
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
		us         *fakeAdminUserStore
		wantStatus int
	}{
		{name: "giriş yapılmamış", adminID: "", gs: &fakeAdminGuideStore{}, us: &fakeAdminUserStore{}, wantStatus: fiber.StatusUnauthorized},
		{name: "başvuru bulunamadı", adminID: "a1", gs: &fakeAdminGuideStore{findErr: repository.ErrNotFound}, us: &fakeAdminUserStore{}, wantStatus: fiber.StatusNotFound},
		{name: "başvuru arama db hatası", adminID: "a1", gs: &fakeAdminGuideStore{findErr: errors.New("db")}, us: &fakeAdminUserStore{}, wantStatus: fiber.StatusInternalServerError},
		// Aynı başvuru iki admin tarafından işlenirse ikincisi 409 almalı.
		{name: "başvuru zaten incelenmiş — 409", adminID: "a1", gs: &fakeAdminGuideStore{updateErr: repository.ErrNotFound}, us: &fakeAdminUserStore{}, wantStatus: fiber.StatusConflict},
		{name: "durum güncelleme db hatası", adminID: "a1", gs: &fakeAdminGuideStore{updateErr: errors.New("db")}, us: &fakeAdminUserStore{}, wantStatus: fiber.StatusInternalServerError},
		// Rol verilemezse istek başarısız olmalı — sessizce "onaylandı" denmemeli.
		{name: "rol atama hatası — 500", adminID: "a1", gs: &fakeAdminGuideStore{}, us: &fakeAdminUserStore{roleErr: errors.New("db")}, wantStatus: fiber.StatusInternalServerError},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			app := setupAdminApp(&fakeAdminVenueStore{}, tt.gs, tt.us, &fakeAdminAuditStore{}, tt.adminID)
			resp := doJSON(t, app, http.MethodPut, "/admin/applications/app1/approve", "")
			if resp.StatusCode != tt.wantStatus {
				t.Fatalf("beklenen %d, alınan %d", tt.wantStatus, resp.StatusCode)
			}
		})
	}
}

func TestAdminApproveApplicationCityFailureIsTolerated(t *testing.T) {
	// MEVCUT DAVRANIŞ: guide_city yazılamazsa istek yine 200 döner ve kullanıcı
	// guide olarak kalır — yani rolü var ama şehri yok. Bu kısmi durum, şehir
	// kısıtına dayanan akışları etkiler (ConfirmVenue, Create).
	// Test bu davranışı sabitliyor; değiştirilmesi bilinçli bir karar olmalı.
	gs := &fakeAdminGuideStore{}
	us := &fakeAdminUserStore{cityErr: errors.New("db")}
	app := setupAdminApp(&fakeAdminVenueStore{}, gs, us, &fakeAdminAuditStore{}, "a1")

	resp := doJSON(t, app, http.MethodPut, "/admin/applications/app1/approve", "")
	if resp.StatusCode != fiber.StatusOK {
		t.Fatalf("beklenen 200 (şehir hatası tolere edilir), alınan %d", resp.StatusCode)
	}
	// Rol yine de verilmiş olmalı.
	if us.gotRole != models.RoleGuide {
		t.Fatal("şehir hatasına rağmen rol verilmeliydi")
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
