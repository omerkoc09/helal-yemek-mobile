package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gofiber/fiber/v2"
	"github.com/omerkoc/caiz-mi/internal/models"
	jwtpkg "github.com/omerkoc/caiz-mi/pkg/jwt"
)

// --- Mock AuthService ---

type mockAuthService struct {
	registerFn     func(ctx context.Context, email, password, name string) (*jwtpkg.TokenPair, error)
	loginFn        func(ctx context.Context, email, password string) (*jwtpkg.TokenPair, error)
	googleLoginFn  func(ctx context.Context, idToken string) (*jwtpkg.TokenPair, error)
	appleLoginFn   func(ctx context.Context, identityToken, name string) (*jwtpkg.TokenPair, error)
	refreshTokenFn func(ctx context.Context, refreshToken string) (*jwtpkg.TokenPair, error)
	getUserFn      func(ctx context.Context, userID string) (*models.User, error)
}

func (m *mockAuthService) Register(ctx context.Context, email, password, name string) (*jwtpkg.TokenPair, error) {
	if m.registerFn != nil {
		return m.registerFn(ctx, email, password, name)
	}
	return &jwtpkg.TokenPair{AccessToken: "access", RefreshToken: "refresh"}, nil
}

func (m *mockAuthService) Login(ctx context.Context, email, password string) (*jwtpkg.TokenPair, error) {
	if m.loginFn != nil {
		return m.loginFn(ctx, email, password)
	}
	return &jwtpkg.TokenPair{AccessToken: "access", RefreshToken: "refresh"}, nil
}

func (m *mockAuthService) LoginWithGoogle(ctx context.Context, idToken string) (*jwtpkg.TokenPair, error) {
	if m.googleLoginFn != nil {
		return m.googleLoginFn(ctx, idToken)
	}
	return &jwtpkg.TokenPair{AccessToken: "access", RefreshToken: "refresh"}, nil
}

func (m *mockAuthService) LoginWithApple(ctx context.Context, identityToken, name string) (*jwtpkg.TokenPair, error) {
	if m.appleLoginFn != nil {
		return m.appleLoginFn(ctx, identityToken, name)
	}
	return &jwtpkg.TokenPair{AccessToken: "access", RefreshToken: "refresh"}, nil
}

func (m *mockAuthService) RefreshTokens(ctx context.Context, refreshToken string) (*jwtpkg.TokenPair, error) {
	if m.refreshTokenFn != nil {
		return m.refreshTokenFn(ctx, refreshToken)
	}
	return &jwtpkg.TokenPair{AccessToken: "new-access", RefreshToken: "new-refresh"}, nil
}

func (m *mockAuthService) GetUser(ctx context.Context, userID string) (*models.User, error) {
	if m.getUserFn != nil {
		return m.getUserFn(ctx, userID)
	}
	return &models.User{ID: userID, Email: "test@test.com", Name: "Test", Role: "traveler"}, nil
}

// --- Yardımcı fonksiyonlar ---

func setupAuthApp(mock *mockAuthService) *fiber.App {
	app := fiber.New()
	h := &AuthHandler{authService: mock}

	app.Post("/register", h.Register)
	app.Post("/login", h.Login)
	app.Post("/google", h.GoogleLogin)
	app.Post("/apple", h.AppleLogin)
	app.Post("/refresh", h.Refresh)
	app.Get("/me", func(c *fiber.Ctx) error {
		c.Locals("userID", "user-123")
		return c.Next()
	}, h.Me)

	return app
}

func jsonBody(t *testing.T, v interface{}) *bytes.Buffer {
	t.Helper()
	b, err := json.Marshal(v)
	if err != nil {
		t.Fatalf("JSON marshal hatası: %v", err)
	}
	return bytes.NewBuffer(b)
}

func readBody(t *testing.T, resp *http.Response) map[string]interface{} {
	t.Helper()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatalf("body okuma hatası: %v", err)
	}
	var result map[string]interface{}
	json.Unmarshal(body, &result)
	return result
}

// --- Register Testleri ---

func TestRegister_Success(t *testing.T) {
	mock := &mockAuthService{}
	app := setupAuthApp(mock)

	body := jsonBody(t, map[string]string{
		"email": "new@test.com", "password": "123456", "name": "Test User",
	})

	req := httptest.NewRequest(http.MethodPost, "/register", body)
	req.Header.Set("Content-Type", "application/json")

	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("test hatası: %v", err)
	}

	if resp.StatusCode != http.StatusCreated {
		result := readBody(t, resp)
		t.Fatalf("status beklenen: 201, gelen: %d, body: %v", resp.StatusCode, result)
	}

	result := readBody(t, resp)
	if result["access_token"] == nil {
		t.Error("access_token döndürülmedi")
	}
	if result["refresh_token"] == nil {
		t.Error("refresh_token döndürülmedi")
	}
}

func TestRegister_MissingFields(t *testing.T) {
	mock := &mockAuthService{}
	app := setupAuthApp(mock)

	tests := []struct {
		name string
		body map[string]string
	}{
		{"email eksik", map[string]string{"password": "123456", "name": "Test"}},
		{"şifre eksik", map[string]string{"email": "a@b.com", "name": "Test"}},
		{"ad eksik", map[string]string{"email": "a@b.com", "password": "123456"}},
		{"hepsi boş", map[string]string{}},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodPost, "/register", jsonBody(t, tt.body))
			req.Header.Set("Content-Type", "application/json")

			resp, err := app.Test(req)
			if err != nil {
				t.Fatalf("test hatası: %v", err)
			}

			if resp.StatusCode != http.StatusBadRequest {
				t.Errorf("status beklenen: 400, gelen: %d", resp.StatusCode)
			}
		})
	}
}

func TestRegister_DuplicateEmail(t *testing.T) {
	mock := &mockAuthService{
		registerFn: func(ctx context.Context, email, password, name string) (*jwtpkg.TokenPair, error) {
			return nil, errors.New("bu email adresi zaten kullanılıyor")
		},
	}
	app := setupAuthApp(mock)

	body := jsonBody(t, map[string]string{
		"email": "existing@test.com", "password": "123456", "name": "Test",
	})

	req := httptest.NewRequest(http.MethodPost, "/register", body)
	req.Header.Set("Content-Type", "application/json")

	resp, _ := app.Test(req)

	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("status beklenen: 400, gelen: %d", resp.StatusCode)
	}

	result := readBody(t, resp)
	if result["error"] == nil {
		t.Error("hata mesajı döndürülmedi")
	}
}

func TestRegister_ShortPassword(t *testing.T) {
	mock := &mockAuthService{
		registerFn: func(ctx context.Context, email, password, name string) (*jwtpkg.TokenPair, error) {
			return nil, errors.New("şifre en az 6 karakter olmalıdır")
		},
	}
	app := setupAuthApp(mock)

	body := jsonBody(t, map[string]string{
		"email": "a@b.com", "password": "123", "name": "Test",
	})

	req := httptest.NewRequest(http.MethodPost, "/register", body)
	req.Header.Set("Content-Type", "application/json")

	resp, _ := app.Test(req)
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("status beklenen: 400, gelen: %d", resp.StatusCode)
	}
}

func TestRegister_InvalidJSON(t *testing.T) {
	mock := &mockAuthService{}
	app := setupAuthApp(mock)

	req := httptest.NewRequest(http.MethodPost, "/register", bytes.NewBufferString("invalid json"))
	req.Header.Set("Content-Type", "application/json")

	resp, _ := app.Test(req)
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("status beklenen: 400, gelen: %d", resp.StatusCode)
	}
}

// --- Login Testleri ---

func TestLogin_Success(t *testing.T) {
	mock := &mockAuthService{}
	app := setupAuthApp(mock)

	body := jsonBody(t, map[string]string{"email": "test@test.com", "password": "123456"})
	req := httptest.NewRequest(http.MethodPost, "/login", body)
	req.Header.Set("Content-Type", "application/json")

	resp, _ := app.Test(req)
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status beklenen: 200, gelen: %d", resp.StatusCode)
	}

	result := readBody(t, resp)
	if result["access_token"] == nil {
		t.Error("access_token döndürülmedi")
	}
}

func TestLogin_MissingFields(t *testing.T) {
	mock := &mockAuthService{}
	app := setupAuthApp(mock)

	tests := []struct {
		name string
		body map[string]string
	}{
		{"email eksik", map[string]string{"password": "123456"}},
		{"şifre eksik", map[string]string{"email": "a@b.com"}},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodPost, "/login", jsonBody(t, tt.body))
			req.Header.Set("Content-Type", "application/json")

			resp, _ := app.Test(req)
			if resp.StatusCode != http.StatusBadRequest {
				t.Errorf("status beklenen: 400, gelen: %d", resp.StatusCode)
			}
		})
	}
}

func TestLogin_WrongCredentials(t *testing.T) {
	mock := &mockAuthService{
		loginFn: func(ctx context.Context, email, password string) (*jwtpkg.TokenPair, error) {
			return nil, errors.New("geçersiz email veya şifre")
		},
	}
	app := setupAuthApp(mock)

	body := jsonBody(t, map[string]string{"email": "test@test.com", "password": "wrongpass"})
	req := httptest.NewRequest(http.MethodPost, "/login", body)
	req.Header.Set("Content-Type", "application/json")

	resp, _ := app.Test(req)
	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("status beklenen: 401, gelen: %d", resp.StatusCode)
	}
}

func TestLogin_InactiveAccount(t *testing.T) {
	mock := &mockAuthService{
		loginFn: func(ctx context.Context, email, password string) (*jwtpkg.TokenPair, error) {
			return nil, errors.New("hesabınız devre dışı bırakılmıştır")
		},
	}
	app := setupAuthApp(mock)

	body := jsonBody(t, map[string]string{"email": "banned@test.com", "password": "123456"})
	req := httptest.NewRequest(http.MethodPost, "/login", body)
	req.Header.Set("Content-Type", "application/json")

	resp, _ := app.Test(req)
	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("status beklenen: 401, gelen: %d", resp.StatusCode)
	}
}

// --- Google Login Testleri ---

func TestGoogleLogin_Success(t *testing.T) {
	mock := &mockAuthService{}
	app := setupAuthApp(mock)

	body := jsonBody(t, map[string]string{"id_token": "valid-google-token"})
	req := httptest.NewRequest(http.MethodPost, "/google", body)
	req.Header.Set("Content-Type", "application/json")

	resp, _ := app.Test(req)
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status beklenen: 200, gelen: %d", resp.StatusCode)
	}
}

func TestGoogleLogin_MissingToken(t *testing.T) {
	mock := &mockAuthService{}
	app := setupAuthApp(mock)

	body := jsonBody(t, map[string]string{})
	req := httptest.NewRequest(http.MethodPost, "/google", body)
	req.Header.Set("Content-Type", "application/json")

	resp, _ := app.Test(req)
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("status beklenen: 400, gelen: %d", resp.StatusCode)
	}
}

func TestGoogleLogin_InvalidToken(t *testing.T) {
	mock := &mockAuthService{
		googleLoginFn: func(ctx context.Context, idToken string) (*jwtpkg.TokenPair, error) {
			return nil, errors.New("geçersiz Google token")
		},
	}
	app := setupAuthApp(mock)

	body := jsonBody(t, map[string]string{"id_token": "invalid-token"})
	req := httptest.NewRequest(http.MethodPost, "/google", body)
	req.Header.Set("Content-Type", "application/json")

	resp, _ := app.Test(req)
	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("status beklenen: 401, gelen: %d", resp.StatusCode)
	}
}

// --- Apple Login Testleri ---

func TestAppleLogin_Success(t *testing.T) {
	mock := &mockAuthService{}
	app := setupAuthApp(mock)

	body := jsonBody(t, map[string]string{
		"identity_token": "valid-apple-token",
		"name":           "Apple User",
	})
	req := httptest.NewRequest(http.MethodPost, "/apple", body)
	req.Header.Set("Content-Type", "application/json")

	resp, _ := app.Test(req)
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status beklenen: 200, gelen: %d", resp.StatusCode)
	}
}

func TestAppleLogin_MissingToken(t *testing.T) {
	mock := &mockAuthService{}
	app := setupAuthApp(mock)

	body := jsonBody(t, map[string]string{"name": "Apple User"})
	req := httptest.NewRequest(http.MethodPost, "/apple", body)
	req.Header.Set("Content-Type", "application/json")

	resp, _ := app.Test(req)
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("status beklenen: 400, gelen: %d", resp.StatusCode)
	}
}

func TestAppleLogin_InvalidToken(t *testing.T) {
	mock := &mockAuthService{
		appleLoginFn: func(ctx context.Context, identityToken, name string) (*jwtpkg.TokenPair, error) {
			return nil, errors.New("geçersiz Apple token")
		},
	}
	app := setupAuthApp(mock)

	body := jsonBody(t, map[string]string{"identity_token": "bad-token"})
	req := httptest.NewRequest(http.MethodPost, "/apple", body)
	req.Header.Set("Content-Type", "application/json")

	resp, _ := app.Test(req)
	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("status beklenen: 401, gelen: %d", resp.StatusCode)
	}
}

// --- Refresh Token Testleri ---

func TestRefresh_Success(t *testing.T) {
	mock := &mockAuthService{}
	app := setupAuthApp(mock)

	body := jsonBody(t, map[string]string{"refresh_token": "valid-refresh"})
	req := httptest.NewRequest(http.MethodPost, "/refresh", body)
	req.Header.Set("Content-Type", "application/json")

	resp, _ := app.Test(req)
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status beklenen: 200, gelen: %d", resp.StatusCode)
	}
}

func TestRefresh_MissingToken(t *testing.T) {
	mock := &mockAuthService{}
	app := setupAuthApp(mock)

	body := jsonBody(t, map[string]string{})
	req := httptest.NewRequest(http.MethodPost, "/refresh", body)
	req.Header.Set("Content-Type", "application/json")

	resp, _ := app.Test(req)
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("status beklenen: 400, gelen: %d", resp.StatusCode)
	}
}

func TestRefresh_InvalidToken(t *testing.T) {
	mock := &mockAuthService{
		refreshTokenFn: func(ctx context.Context, refreshToken string) (*jwtpkg.TokenPair, error) {
			return nil, errors.New("geçersiz veya süresi dolmuş refresh token")
		},
	}
	app := setupAuthApp(mock)

	body := jsonBody(t, map[string]string{"refresh_token": "expired-token"})
	req := httptest.NewRequest(http.MethodPost, "/refresh", body)
	req.Header.Set("Content-Type", "application/json")

	resp, _ := app.Test(req)
	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("status beklenen: 401, gelen: %d", resp.StatusCode)
	}
}

// --- Me Endpoint Testi ---

func TestMe_Success(t *testing.T) {
	mock := &mockAuthService{
		getUserFn: func(ctx context.Context, userID string) (*models.User, error) {
			return &models.User{
				ID:       userID,
				Email:    "me@test.com",
				Name:     "Test User",
				Role:     models.RoleTraveler,
				Provider: "email",
				IsActive: true,
			}, nil
		},
	}
	app := setupAuthApp(mock)

	req := httptest.NewRequest(http.MethodGet, "/me", nil)
	resp, _ := app.Test(req)

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status beklenen: 200, gelen: %d", resp.StatusCode)
	}

	result := readBody(t, resp)
	if result["email"] != "me@test.com" {
		t.Errorf("email beklenen: me@test.com, gelen: %v", result["email"])
	}
}

func TestMe_UserNotFound(t *testing.T) {
	mock := &mockAuthService{
		getUserFn: func(ctx context.Context, userID string) (*models.User, error) {
			return nil, errors.New("kullanıcı bulunamadı")
		},
	}
	app := setupAuthApp(mock)

	req := httptest.NewRequest(http.MethodGet, "/me", nil)
	resp, _ := app.Test(req)

	if resp.StatusCode != http.StatusNotFound {
		t.Fatalf("status beklenen: 404, gelen: %d", resp.StatusCode)
	}
}
