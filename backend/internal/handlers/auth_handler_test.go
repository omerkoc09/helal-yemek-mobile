package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gofiber/fiber/v2"

	"github.com/omerkoc/itimat-mobile/internal/models"
	"github.com/omerkoc/itimat-mobile/internal/repository"
	"github.com/omerkoc/itimat-mobile/internal/services"
	jwtpkg "github.com/omerkoc/itimat-mobile/pkg/jwt"
)

// --- fakeAuthService ---

type fakeAuthService struct {
	tokens *jwtpkg.TokenPair
	user   *models.User
	err    error

	// Son çağrının argümanları — handler'ın gövdeyi doğru aktardığını doğrulamak için.
	gotEmail    string
	gotPassword string
	gotName     string
	gotSurname  string
	gotPhone    string
	gotToken    string
	gotUserID   string

	resetErr  error
	deleteErr error
	gotCode   string
}

func (f *fakeAuthService) Register(_ context.Context, email, password, name, surname, phone string) (*jwtpkg.TokenPair, error) {
	f.gotEmail, f.gotPassword, f.gotName, f.gotSurname, f.gotPhone = email, password, name, surname, phone
	return f.tokens, f.err
}

func (f *fakeAuthService) Login(_ context.Context, email, password string) (*jwtpkg.TokenPair, error) {
	f.gotEmail, f.gotPassword = email, password
	return f.tokens, f.err
}

func (f *fakeAuthService) LoginWithGoogle(_ context.Context, idToken string) (*jwtpkg.TokenPair, error) {
	f.gotToken = idToken
	return f.tokens, f.err
}

func (f *fakeAuthService) RefreshTokens(_ context.Context, refreshToken string) (*jwtpkg.TokenPair, error) {
	f.gotToken = refreshToken
	return f.tokens, f.err
}

func (f *fakeAuthService) GetUser(_ context.Context, userID string) (*models.User, error) {
	f.gotUserID = userID
	return f.user, f.err
}

func (f *fakeAuthService) UpdateProfile(_ context.Context, userID string, name, surname, phone *string) (*models.User, error) {
	f.gotUserID = userID
	if name != nil {
		f.gotName = *name
	}
	if surname != nil {
		f.gotSurname = *surname
	}
	if phone != nil {
		f.gotPhone = *phone
	}
	return f.user, f.err
}

func (f *fakeAuthService) RequestPasswordReset(_ context.Context, email string) error {
	f.gotEmail = email
	return f.resetErr
}

func (f *fakeAuthService) ResetPassword(_ context.Context, email, code, newPassword string) error {
	f.gotEmail, f.gotCode, f.gotPassword = email, code, newPassword
	return f.resetErr
}

func (f *fakeAuthService) DeleteAccount(_ context.Context, userID string) error {
	f.gotUserID = userID
	return f.deleteErr
}

// --- test helpers ---

func setupAuthApp(svc AuthServiceInterface, userID string) *fiber.App {
	app := fiber.New()
	h := NewAuthHandler(svc)
	app.Use(func(c *fiber.Ctx) error {
		if userID != "" {
			c.Locals("userID", userID)
		}
		return c.Next()
	})
	app.Post("/auth/register", h.Register)
	app.Post("/auth/login", h.Login)
	app.Post("/auth/google", h.GoogleLogin)
	app.Post("/auth/refresh", h.Refresh)
	app.Get("/auth/me", h.Me)
	app.Put("/auth/profile", h.UpdateProfile)
	app.Delete("/auth/me", h.DeleteAccount)
	return app
}

func doJSON(t *testing.T, app *fiber.App, method, path, body string) *http.Response {
	t.Helper()
	req := httptest.NewRequest(method, path, strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	resp, err := app.Test(req, -1)
	if err != nil {
		t.Fatalf("istek başarısız: %v", err)
	}
	return resp
}

func fakeTokens() *jwtpkg.TokenPair {
	return &jwtpkg.TokenPair{AccessToken: "access-abc", RefreshToken: "refresh-xyz"}
}

// --- Register ---

func TestAuthRegister(t *testing.T) {
	tests := []struct {
		name       string
		body       string
		svcErr     error
		wantStatus int
	}{
		{name: "başarılı kayıt", body: `{"email":"a@b.com","password":"pw123456","name":"Ali","surname":"Veli","phone":"555"}`, wantStatus: fiber.StatusCreated},
		{name: "bozuk JSON", body: `{bozuk`, wantStatus: fiber.StatusBadRequest},
		{name: "email eksik", body: `{"email":"","password":"pw","name":"Ali","surname":"Veli","phone":"555"}`, wantStatus: fiber.StatusBadRequest},
		{name: "şifre eksik", body: `{"email":"a@b.com","password":"","name":"Ali","surname":"Veli","phone":"555"}`, wantStatus: fiber.StatusBadRequest},
		{name: "telefon eksik", body: `{"email":"a@b.com","password":"pw","name":"Ali","surname":"Veli","phone":""}`, wantStatus: fiber.StatusBadRequest},
		{name: "servis hatası — email zaten kayıtlı", body: `{"email":"a@b.com","password":"pw","name":"Ali","surname":"Veli","phone":"555"}`, svcErr: errors.New("email zaten kayıtlı"), wantStatus: fiber.StatusBadRequest},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			svc := &fakeAuthService{tokens: fakeTokens(), err: tt.svcErr}
			resp := doJSON(t, setupAuthApp(svc, ""), http.MethodPost, "/auth/register", tt.body)
			if resp.StatusCode != tt.wantStatus {
				t.Fatalf("beklenen %d, alınan %d", tt.wantStatus, resp.StatusCode)
			}
		})
	}
}

func TestAuthRegisterPassesFieldsThrough(t *testing.T) {
	svc := &fakeAuthService{tokens: fakeTokens()}
	resp := doJSON(t, setupAuthApp(svc, ""), http.MethodPost, "/auth/register",
		`{"email":"a@b.com","password":"pw123456","name":"Ali","surname":"Veli","phone":"5551112233"}`)

	if resp.StatusCode != fiber.StatusCreated {
		t.Fatalf("beklenen 201, alınan %d", resp.StatusCode)
	}
	if svc.gotEmail != "a@b.com" || svc.gotPassword != "pw123456" ||
		svc.gotName != "Ali" || svc.gotSurname != "Veli" || svc.gotPhone != "5551112233" {
		t.Fatalf("alanlar servise doğru aktarılmadı: %+v", svc)
	}

	// Token'lar gövdede dönmeli — istemci bunlara güveniyor.
	body, _ := io.ReadAll(resp.Body)
	var got jwtpkg.TokenPair
	if err := json.Unmarshal(body, &got); err != nil {
		t.Fatalf("yanıt çözümlenemedi: %v", err)
	}
	if got.AccessToken != "access-abc" || got.RefreshToken != "refresh-xyz" {
		t.Fatalf("token'lar yanıtta yok: %+v", got)
	}
}

// --- Login ---

func TestAuthLogin(t *testing.T) {
	tests := []struct {
		name       string
		body       string
		svcErr     error
		wantStatus int
	}{
		{name: "başarılı giriş", body: `{"email":"a@b.com","password":"pw"}`, wantStatus: fiber.StatusOK},
		{name: "bozuk JSON", body: `{bozuk`, wantStatus: fiber.StatusBadRequest},
		{name: "email eksik", body: `{"email":"","password":"pw"}`, wantStatus: fiber.StatusBadRequest},
		{name: "şifre eksik", body: `{"email":"a@b.com","password":""}`, wantStatus: fiber.StatusBadRequest},
		// Hatalı kimlik 401 dönmeli, 400 değil: istemci bu ikisini farklı ele alıyor.
		{name: "hatalı kimlik bilgisi", body: `{"email":"a@b.com","password":"yanlis"}`, svcErr: errors.New("geçersiz kimlik"), wantStatus: fiber.StatusUnauthorized},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			svc := &fakeAuthService{tokens: fakeTokens(), err: tt.svcErr}
			resp := doJSON(t, setupAuthApp(svc, ""), http.MethodPost, "/auth/login", tt.body)
			if resp.StatusCode != tt.wantStatus {
				t.Fatalf("beklenen %d, alınan %d", tt.wantStatus, resp.StatusCode)
			}
		})
	}
}

// --- Sosyal giriş (Google) ---

func TestAuthSocialLogin(t *testing.T) {
	tests := []struct {
		name       string
		path       string
		body       string
		svcErr     error
		wantStatus int
		wantToken  string
	}{
		{name: "google başarılı", path: "/auth/google", body: `{"id_token":"g-token"}`, wantStatus: fiber.StatusOK, wantToken: "g-token"},
		{name: "google token boş", path: "/auth/google", body: `{"id_token":""}`, wantStatus: fiber.StatusBadRequest},
		{name: "google bozuk JSON", path: "/auth/google", body: `{bozuk`, wantStatus: fiber.StatusBadRequest},
		{name: "google doğrulama hatası", path: "/auth/google", body: `{"id_token":"g-token"}`, svcErr: errors.New("token geçersiz"), wantStatus: fiber.StatusUnauthorized},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			svc := &fakeAuthService{tokens: fakeTokens(), err: tt.svcErr}
			resp := doJSON(t, setupAuthApp(svc, ""), http.MethodPost, tt.path, tt.body)
			if resp.StatusCode != tt.wantStatus {
				t.Fatalf("beklenen %d, alınan %d", tt.wantStatus, resp.StatusCode)
			}
			if tt.wantToken != "" && svc.gotToken != tt.wantToken {
				t.Fatalf("servise giden token %q, beklenen %q", svc.gotToken, tt.wantToken)
			}
		})
	}
}

// --- Refresh ---

func TestAuthRefresh(t *testing.T) {
	tests := []struct {
		name       string
		body       string
		svcErr     error
		wantStatus int
	}{
		{name: "başarılı yenileme", body: `{"refresh_token":"r-token"}`, wantStatus: fiber.StatusOK},
		{name: "token boş", body: `{"refresh_token":""}`, wantStatus: fiber.StatusBadRequest},
		{name: "bozuk JSON", body: `{bozuk`, wantStatus: fiber.StatusBadRequest},
		{name: "süresi dolmuş token", body: `{"refresh_token":"r-token"}`, svcErr: errors.New("token süresi dolmuş"), wantStatus: fiber.StatusUnauthorized},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			svc := &fakeAuthService{tokens: fakeTokens(), err: tt.svcErr}
			resp := doJSON(t, setupAuthApp(svc, ""), http.MethodPost, "/auth/refresh", tt.body)
			if resp.StatusCode != tt.wantStatus {
				t.Fatalf("beklenen %d, alınan %d", tt.wantStatus, resp.StatusCode)
			}
		})
	}
}

// --- Me ---

func TestAuthMe(t *testing.T) {
	t.Run("başarılı — kimliği context'ten alır", func(t *testing.T) {
		svc := &fakeAuthService{user: &models.User{ID: "u1", Email: "a@b.com"}}
		resp := doJSON(t, setupAuthApp(svc, "u1"), http.MethodGet, "/auth/me", "")
		if resp.StatusCode != fiber.StatusOK {
			t.Fatalf("beklenen 200, alınan %d", resp.StatusCode)
		}
		if svc.gotUserID != "u1" {
			t.Fatalf("servise giden userID %q, beklenen u1", svc.gotUserID)
		}
	})

	t.Run("kullanıcı bulunamadı", func(t *testing.T) {
		svc := &fakeAuthService{err: errors.New("yok")}
		resp := doJSON(t, setupAuthApp(svc, "u1"), http.MethodGet, "/auth/me", "")
		if resp.StatusCode != fiber.StatusNotFound {
			t.Fatalf("beklenen 404, alınan %d", resp.StatusCode)
		}
	})

	// Auth middleware atlanmış olsa bile handler kendi başına korumalı olmalı.
	t.Run("context'te userID yok — 401", func(t *testing.T) {
		svc := &fakeAuthService{user: &models.User{ID: "u1"}}
		resp := doJSON(t, setupAuthApp(svc, ""), http.MethodGet, "/auth/me", "")
		if resp.StatusCode != fiber.StatusUnauthorized {
			t.Fatalf("beklenen 401, alınan %d", resp.StatusCode)
		}
	})
}

// --- UpdateProfile ---

func TestAuthUpdateProfile(t *testing.T) {
	t.Run("başarılı güncelleme", func(t *testing.T) {
		svc := &fakeAuthService{user: &models.User{ID: "u1", Name: "Yeni"}}
		resp := doJSON(t, setupAuthApp(svc, "u1"), http.MethodPut, "/auth/profile",
			`{"name":"Yeni","surname":"Soyad","phone":"555"}`)
		if resp.StatusCode != fiber.StatusOK {
			t.Fatalf("beklenen 200, alınan %d", resp.StatusCode)
		}
		if svc.gotUserID != "u1" || svc.gotName != "Yeni" {
			t.Fatalf("alanlar doğru aktarılmadı: %+v", svc)
		}
	})

	t.Run("bozuk JSON", func(t *testing.T) {
		svc := &fakeAuthService{user: &models.User{ID: "u1"}}
		resp := doJSON(t, setupAuthApp(svc, "u1"), http.MethodPut, "/auth/profile", `{bozuk`)
		if resp.StatusCode != fiber.StatusBadRequest {
			t.Fatalf("beklenen 400, alınan %d", resp.StatusCode)
		}
	})

	t.Run("servis hatası — 500", func(t *testing.T) {
		svc := &fakeAuthService{err: errors.New("db hatası")}
		resp := doJSON(t, setupAuthApp(svc, "u1"), http.MethodPut, "/auth/profile", `{"name":"Yeni"}`)
		if resp.StatusCode != fiber.StatusInternalServerError {
			t.Fatalf("beklenen 500, alınan %d", resp.StatusCode)
		}
	})

	t.Run("context'te userID yok — 401", func(t *testing.T) {
		svc := &fakeAuthService{user: &models.User{ID: "u1"}}
		resp := doJSON(t, setupAuthApp(svc, ""), http.MethodPut, "/auth/profile", `{"name":"Yeni"}`)
		if resp.StatusCode != fiber.StatusUnauthorized {
			t.Fatalf("beklenen 401, alınan %d", resp.StatusCode)
		}
	})
}

// --- ForgotPassword ---

func TestForgotPasswordHandler(t *testing.T) {
	const wantMsg = "Eğer bu e-posta kayıtlıysa, sıfırlama kodu gönderildi."

	newApp := func(svc AuthServiceInterface) *fiber.App {
		app := fiber.New()
		h := NewAuthHandler(svc)
		app.Post("/forgot-password", h.ForgotPassword)
		return app
	}

	post := func(t *testing.T, app *fiber.App, body string) (*http.Response, map[string]any) {
		t.Helper()
		req := httptest.NewRequest(http.MethodPost, "/forgot-password", strings.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("istek başarısız: %v", err)
		}
		raw, _ := io.ReadAll(resp.Body)
		var parsed map[string]any
		_ = json.Unmarshal(raw, &parsed)
		return resp, parsed
	}

	t.Run("başarılı istek 200 ve sabit mesaj döner", func(t *testing.T) {
		resp, body := post(t, newApp(&fakeAuthService{}), `{"email":"a@b.com"}`)
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("beklenen 200, gelen %d", resp.StatusCode)
		}
		if body["message"] != wantMsg {
			t.Errorf("beklenmeyen mesaj: %v", body["message"])
		}
	})

	t.Run("servis hatası da AYNI 200 cevabını döner", func(t *testing.T) {
		// Enumeration koruması: iç durum istemciye sızmamalı.
		resp, body := post(t,
			newApp(&fakeAuthService{resetErr: errors.New("iç hata")}),
			`{"email":"a@b.com"}`)
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("beklenen 200, gelen %d", resp.StatusCode)
		}
		if body["message"] != wantMsg {
			t.Errorf("beklenmeyen mesaj: %v", body["message"])
		}
	})

	t.Run("email boşsa 400", func(t *testing.T) {
		resp, _ := post(t, newApp(&fakeAuthService{}), `{"email":""}`)
		if resp.StatusCode != http.StatusBadRequest {
			t.Fatalf("beklenen 400, gelen %d", resp.StatusCode)
		}
	})

	t.Run("geçersiz JSON 400", func(t *testing.T) {
		resp, _ := post(t, newApp(&fakeAuthService{}), `{bozuk`)
		if resp.StatusCode != http.StatusBadRequest {
			t.Fatalf("beklenen 400, gelen %d", resp.StatusCode)
		}
	})
}

func TestResetPasswordHandler(t *testing.T) {
	newApp := func(svc AuthServiceInterface) *fiber.App {
		app := fiber.New()
		h := NewAuthHandler(svc)
		app.Post("/reset-password", h.ResetPassword)
		return app
	}

	post := func(t *testing.T, app *fiber.App, body string) (*http.Response, map[string]any) {
		t.Helper()
		req := httptest.NewRequest(http.MethodPost, "/reset-password", strings.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		resp, err := app.Test(req)
		if err != nil {
			t.Fatalf("istek başarısız: %v", err)
		}
		raw, _ := io.ReadAll(resp.Body)
		var parsed map[string]any
		_ = json.Unmarshal(raw, &parsed)
		return resp, parsed
	}

	t.Run("başarılı sıfırlama 200", func(t *testing.T) {
		svc := &fakeAuthService{}
		resp, body := post(t, newApp(svc),
			`{"email":"a@b.com","code":"123456","new_password":"yeniSifre123"}`)
		if resp.StatusCode != http.StatusOK {
			t.Fatalf("beklenen 200, gelen %d", resp.StatusCode)
		}
		if body["message"] != "Şifreniz güncellendi." {
			t.Errorf("beklenmeyen mesaj: %v", body["message"])
		}
		if svc.gotCode != "123456" {
			t.Errorf("kod servise aktarılmadı: %q", svc.gotCode)
		}
	})

	t.Run("servis hatası 400 ve mesajı aynen döner", func(t *testing.T) {
		// errors.New(...) ile aynı metni üreten ama sentinel'i SARMAYAN bir hata
		// kasıtlı olarak kullanılmıyor: handler errors.Is ile ayrım yapıyor,
		// dolayısıyla burada gerçek sentinel (services.ErrResetInvalid) verilmeli.
		resp, body := post(t,
			newApp(&fakeAuthService{resetErr: services.ErrResetInvalid}),
			`{"email":"a@b.com","code":"999999","new_password":"yeniSifre123"}`)
		if resp.StatusCode != http.StatusBadRequest {
			t.Fatalf("beklenen 400, gelen %d", resp.StatusCode)
		}
		if body["error"] != "kod geçersiz veya süresi dolmuş" {
			t.Errorf("beklenmeyen mesaj: %v", body["error"])
		}
	})

	t.Run("beklenmeyen iç hata 500 ve jenerik mesaj döner", func(t *testing.T) {
		// DB/bcrypt gibi iç hatalar sentinel değildir; ham metin istemciye
		// sızmamalı, jenerik mesajla 500 dönmeli.
		resp, body := post(t,
			newApp(&fakeAuthService{resetErr: errors.New("db bağlantı hatası: dial tcp refused")}),
			`{"email":"a@b.com","code":"999999","new_password":"yeniSifre123"}`)
		if resp.StatusCode != http.StatusInternalServerError {
			t.Fatalf("beklenen 500, gelen %d", resp.StatusCode)
		}
		if body["error"] != "bir hata oluştu, lütfen tekrar deneyin" {
			t.Errorf("iç hata sızmış olabilir: %v", body["error"])
		}
	})

	t.Run("eksik alanlar 400", func(t *testing.T) {
		for _, body := range []string{
			`{"email":"","code":"123456","new_password":"yeniSifre123"}`,
			`{"email":"a@b.com","code":"","new_password":"yeniSifre123"}`,
			`{"email":"a@b.com","code":"123456","new_password":""}`,
		} {
			resp, _ := post(t, newApp(&fakeAuthService{}), body)
			if resp.StatusCode != http.StatusBadRequest {
				t.Errorf("beklenen 400, gelen %d — gövde: %s", resp.StatusCode, body)
			}
		}
	})

	t.Run("geçersiz JSON 400", func(t *testing.T) {
		resp, _ := post(t, newApp(&fakeAuthService{}), `{bozuk`)
		if resp.StatusCode != http.StatusBadRequest {
			t.Fatalf("beklenen 400, gelen %d", resp.StatusCode)
		}
	})
}

func TestAuthDeleteAccount(t *testing.T) {
	t.Run("başarılı silmede 204 döner", func(t *testing.T) {
		svc := &fakeAuthService{}
		app := setupAuthApp(svc, "user-42")

		resp := doJSON(t, app, http.MethodDelete, "/auth/me", "")
		if resp.StatusCode != fiber.StatusNoContent {
			t.Fatalf("beklenen 204, alınan %d", resp.StatusCode)
		}
		// Kimlik token'dan alınmalı; gövdeden ID kabul edilirse kullanıcı
		// başkasının hesabını silebilirdi.
		if svc.gotUserID != "user-42" {
			t.Fatalf("beklenen user-42, alınan %q", svc.gotUserID)
		}
	})

	t.Run("son admin engellenir: 403", func(t *testing.T) {
		svc := &fakeAuthService{deleteErr: services.ErrLastAdmin}
		app := setupAuthApp(svc, "admin-1")

		resp := doJSON(t, app, http.MethodDelete, "/auth/me", "")
		if resp.StatusCode != fiber.StatusForbidden {
			t.Fatalf("beklenen 403, alınan %d", resp.StatusCode)
		}
	})

	t.Run("kullanıcı yoksa 404", func(t *testing.T) {
		svc := &fakeAuthService{deleteErr: repository.ErrNotFound}
		app := setupAuthApp(svc, "yok")

		resp := doJSON(t, app, http.MethodDelete, "/auth/me", "")
		if resp.StatusCode != fiber.StatusNotFound {
			t.Fatalf("beklenen 404, alınan %d", resp.StatusCode)
		}
	})

	t.Run("beklenmeyen hatada 500", func(t *testing.T) {
		svc := &fakeAuthService{deleteErr: errors.New("db")}
		app := setupAuthApp(svc, "u1")

		resp := doJSON(t, app, http.MethodDelete, "/auth/me", "")
		if resp.StatusCode != fiber.StatusInternalServerError {
			t.Fatalf("beklenen 500, alınan %d", resp.StatusCode)
		}
	})
}
