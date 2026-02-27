package middleware

import (
	"io"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gofiber/fiber/v2"
	jwtpkg "github.com/omerkoc/caiz-mi/pkg/jwt"
)

const testSecret = "test-secret-key-middleware"

// testHandler — middleware'den sonra çağrılan basit handler
func testHandler(c *fiber.Ctx) error {
	return c.JSON(fiber.Map{
		"userID":   c.Locals("userID"),
		"userRole": c.Locals("userRole"),
	})
}

func setupApp(middlewares ...fiber.Handler) *fiber.App {
	app := fiber.New()
	handlers := append(middlewares, testHandler)
	app.Get("/test", handlers...)
	return app
}

// --- Auth Middleware Testleri ---

func TestAuth_ValidToken(t *testing.T) {
	pair, err := jwtpkg.GenerateTokenPair("user-123", "test@test.com", "traveler", testSecret)
	if err != nil {
		t.Fatalf("token üretme hatası: %v", err)
	}

	app := setupApp(Auth(testSecret))
	req := httptest.NewRequest(http.MethodGet, "/test", nil)
	req.Header.Set("Authorization", "Bearer "+pair.AccessToken)

	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("test isteği hatası: %v", err)
	}

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("status beklenen: 200, gelen: %d, body: %s", resp.StatusCode, string(body))
	}
}

func TestAuth_MissingHeader(t *testing.T) {
	app := setupApp(Auth(testSecret))
	req := httptest.NewRequest(http.MethodGet, "/test", nil)

	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("test isteği hatası: %v", err)
	}

	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("status beklenen: 401, gelen: %d", resp.StatusCode)
	}
}

func TestAuth_InvalidToken(t *testing.T) {
	app := setupApp(Auth(testSecret))
	req := httptest.NewRequest(http.MethodGet, "/test", nil)
	req.Header.Set("Authorization", "Bearer invalid-token-string")

	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("test isteği hatası: %v", err)
	}

	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("status beklenen: 401, gelen: %d", resp.StatusCode)
	}
}

func TestAuth_WrongSecret(t *testing.T) {
	pair, err := jwtpkg.GenerateTokenPair("user-123", "test@test.com", "traveler", "other-secret")
	if err != nil {
		t.Fatalf("token üretme hatası: %v", err)
	}

	app := setupApp(Auth(testSecret))
	req := httptest.NewRequest(http.MethodGet, "/test", nil)
	req.Header.Set("Authorization", "Bearer "+pair.AccessToken)

	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("test isteği hatası: %v", err)
	}

	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("status beklenen: 401, gelen: %d", resp.StatusCode)
	}
}

func TestAuth_MalformedHeader(t *testing.T) {
	app := setupApp(Auth(testSecret))

	tests := []struct {
		name   string
		header string
	}{
		{"sadece token", "some-token"},
		{"Basic auth", "Basic dXNlcjpwYXNz"},
		{"boş bearer", "Bearer "},
		{"boş değer", "Bearer"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, "/test", nil)
			req.Header.Set("Authorization", tt.header)

			resp, err := app.Test(req)
			if err != nil {
				t.Fatalf("test isteği hatası: %v", err)
			}

			if resp.StatusCode != http.StatusUnauthorized {
				t.Errorf("status beklenen: 401, gelen: %d", resp.StatusCode)
			}
		})
	}
}

// --- OptionalAuth Testleri ---

func TestOptionalAuth_WithToken(t *testing.T) {
	pair, err := jwtpkg.GenerateTokenPair("user-123", "test@test.com", "guide", testSecret)
	if err != nil {
		t.Fatalf("token üretme hatası: %v", err)
	}

	app := setupApp(OptionalAuth(testSecret))
	req := httptest.NewRequest(http.MethodGet, "/test", nil)
	req.Header.Set("Authorization", "Bearer "+pair.AccessToken)

	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("test isteği hatası: %v", err)
	}

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status beklenen: 200, gelen: %d", resp.StatusCode)
	}
}

func TestOptionalAuth_WithoutToken(t *testing.T) {
	app := setupApp(OptionalAuth(testSecret))
	req := httptest.NewRequest(http.MethodGet, "/test", nil)

	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("test isteği hatası: %v", err)
	}

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("OptionalAuth: token olmadan da geçmeli, status: %d", resp.StatusCode)
	}
}

func TestOptionalAuth_InvalidToken(t *testing.T) {
	app := setupApp(OptionalAuth(testSecret))
	req := httptest.NewRequest(http.MethodGet, "/test", nil)
	req.Header.Set("Authorization", "Bearer invalid-token")

	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("test isteği hatası: %v", err)
	}

	// Geçersiz token olsa bile OptionalAuth geçmeli
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("OptionalAuth: geçersiz token ile de geçmeli, status: %d", resp.StatusCode)
	}
}

// --- RequireRole Testleri ---

func TestRequireRole_Allowed(t *testing.T) {
	pair, err := jwtpkg.GenerateTokenPair("user-123", "admin@test.com", "admin", testSecret)
	if err != nil {
		t.Fatalf("token üretme hatası: %v", err)
	}

	app := setupApp(Auth(testSecret), RequireRole("admin"))
	req := httptest.NewRequest(http.MethodGet, "/test", nil)
	req.Header.Set("Authorization", "Bearer "+pair.AccessToken)

	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("test isteği hatası: %v", err)
	}

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("admin rolü erişebilmeli, status: %d", resp.StatusCode)
	}
}

func TestRequireRole_Denied(t *testing.T) {
	pair, err := jwtpkg.GenerateTokenPair("user-123", "traveler@test.com", "traveler", testSecret)
	if err != nil {
		t.Fatalf("token üretme hatası: %v", err)
	}

	app := setupApp(Auth(testSecret), RequireRole("admin"))
	req := httptest.NewRequest(http.MethodGet, "/test", nil)
	req.Header.Set("Authorization", "Bearer "+pair.AccessToken)

	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("test isteği hatası: %v", err)
	}

	if resp.StatusCode != http.StatusForbidden {
		t.Fatalf("traveler admin endpointine erişememeli, status: %d", resp.StatusCode)
	}
}

func TestRequireRole_MultipleRoles(t *testing.T) {
	tests := []struct {
		role     string
		allowed  bool
	}{
		{"guide", true},
		{"admin", true},
		{"traveler", false},
	}

	for _, tt := range tests {
		t.Run(tt.role, func(t *testing.T) {
			pair, err := jwtpkg.GenerateTokenPair("user-1", "u@test.com", tt.role, testSecret)
			if err != nil {
				t.Fatalf("token üretme hatası: %v", err)
			}

			app := setupApp(Auth(testSecret), RequireRole("guide", "admin"))
			req := httptest.NewRequest(http.MethodGet, "/test", nil)
			req.Header.Set("Authorization", "Bearer "+pair.AccessToken)

			resp, err := app.Test(req)
			if err != nil {
				t.Fatalf("test isteği hatası: %v", err)
			}

			if tt.allowed && resp.StatusCode != http.StatusOK {
				t.Errorf("%s erişebilmeli, status: %d", tt.role, resp.StatusCode)
			}
			if !tt.allowed && resp.StatusCode != http.StatusForbidden {
				t.Errorf("%s erişememeli, status: %d", tt.role, resp.StatusCode)
			}
		})
	}
}
