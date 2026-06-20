package handlers

import (
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gofiber/fiber/v2"
)

// setTestAuth — c.Locals'a userID ve userRole değerlerini set eden test yardımcısı.
// getUserID ve getUserRole fonksiyonları c.Locals("userID") ve c.Locals("userRole") okur;
// bu helper aynı anahtarları kullanarak gerçek middleware'i taklit eder.
func setTestAuth(c *fiber.Ctx, userID, role string) {
	c.Locals("userID", userID)
	c.Locals("userRole", role)
}

// TestApply_TermsNotAccepted_Returns400 — terms_accepted=false gönderilince 400 dönmeli.
// Bu dal repo'ya ulaşmadan döner; guideRepo nil olabilir.
func TestApply_TermsNotAccepted_Returns400(t *testing.T) {
	app := fiber.New()
	h := &GuideHandler{} // guideRepo nil; bu dal repo'ya gitmez
	app.Post("/guide/apply", func(c *fiber.Ctx) error {
		setTestAuth(c, "user-1", "traveler")
		return h.Apply(c)
	})

	req := httptest.NewRequest("POST", "/guide/apply",
		strings.NewReader(`{"city":"İstanbul","terms_accepted":false}`))
	req.Header.Set("Content-Type", "application/json")
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("istek gönderilemedi: %v", err)
	}
	if resp.StatusCode != 400 {
		t.Fatalf("400 bekleniyor (terms_accepted=false), %d alındı", resp.StatusCode)
	}
}

// TestApply_InvalidCity_Returns400 — geçersiz şehir (Gotham) gönderilince 400 dönmeli.
// Bu dal da repo'ya ulaşmadan döner.
func TestApply_InvalidCity_Returns400(t *testing.T) {
	app := fiber.New()
	h := &GuideHandler{} // guideRepo nil; bu dal repo'ya gitmez
	app.Post("/guide/apply", func(c *fiber.Ctx) error {
		setTestAuth(c, "user-1", "traveler")
		return h.Apply(c)
	})

	req := httptest.NewRequest("POST", "/guide/apply",
		strings.NewReader(`{"city":"Gotham","terms_accepted":true}`))
	req.Header.Set("Content-Type", "application/json")
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("istek gönderilemedi: %v", err)
	}
	if resp.StatusCode != 400 {
		t.Fatalf("400 bekleniyor (geçersiz şehir), %d alındı", resp.StatusCode)
	}
}
