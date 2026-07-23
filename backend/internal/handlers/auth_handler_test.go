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

	"github.com/omerkoc/caiz-mi/internal/models"
	jwtpkg "github.com/omerkoc/caiz-mi/pkg/jwt"
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
