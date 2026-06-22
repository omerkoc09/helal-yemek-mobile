package handlers

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/recover"

	"github.com/omerkoc/caiz-mi/internal/models"
)

// --- fakeGuideCityGetter ---

// fakeGuideCityGetter, testlerde gerçek DB gerekmeksizin GetGuideCity davranışını simüle eder.
// guideCityGetter arayüzünü (venue_handler.go'da tanımlı) karşılar.
type fakeGuideCityGetter struct {
	city *string
	err  error
}

func (f *fakeGuideCityGetter) GetGuideCity(_ context.Context, _ string) (*string, error) {
	return f.city, f.err
}

// str — *string kolaylaştırıcı yardımcı.
func str(s string) *string { return &s }

// setupCityGuardApp — şehir kısıtı testleri için minimal Fiber uygulaması kurar.
// userRepo olarak fakeGuideCityGetter kullanır; diğer alanlar nil (Places/Storage/Repo)
// çünkü guard bu alanları kullanmadan önce 403 döner.
func setupCityGuardApp(userID, role string, getter guideCityGetter) *fiber.App {
	h := &VenueHandler{
		venueRepo:     nil, // guard sonrası nil'e ulaşılmamalı; ulaşılırsa recover ile 500 döner
		userRepo:      getter,
		placesService: nil, // place_id göndermeyeceğiz; Places API'ye gidilmez
	}

	app := fiber.New()
	app.Use(recover.New()) // nil venueRepo panic'lerini 500'e dönüştürür
	app.Use(func(c *fiber.Ctx) error {
		c.Locals("userID", userID)
		c.Locals("userRole", role)
		return c.Next()
	})
	app.Post("/venues", h.Create)
	return app
}

// venueBody — test isteği için minimal JSON gövdesi üretir.
// google_place_id ve latitude/longitude olmaksızın Places çağrısını atlatır;
// city parametresi rehber-mekan karşılaştırmasında kullanılır.
func venueBody(city string) io.Reader {
	body := map[string]any{
		"name":           "Test Mekan",
		"city":           city,
		"latitude":       41.01,
		"longitude":      28.97,
		"food_halal_mode": "selected",
		"food_item_ids":  []int{},
		// google_place_id yok → Places API çağrılmaz; city = req.City
	}
	b, _ := json.Marshal(body)
	return strings.NewReader(string(b))
}

// TC-4a: Guide farklı şehirde (Ankara/İstanbul) → 403 + Türkçe mesaj
func TestCreate_GuideWrongCity_Returns403(t *testing.T) {
	getter := &fakeGuideCityGetter{city: str("Ankara")}
	app := setupCityGuardApp("guide-1", string(models.RoleGuide), getter)

	req := httptest.NewRequest(http.MethodPost, "/venues", venueBody("İstanbul"))
	req.Header.Set("Content-Type", "application/json")

	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("istek gönderilemedi: %v", err)
	}
	if resp.StatusCode != http.StatusForbidden {
		t.Fatalf("TC-4a: 403 beklendi, %d alındı", resp.StatusCode)
	}

	var body map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		t.Fatalf("TC-4a: yanıt decode edilemedi: %v", err)
	}
	errMsg, _ := body["error"].(string)
	if !strings.Contains(errMsg, "Yalnızca rehberi olduğunuz şehirde") {
		t.Errorf("TC-4a: Türkçe hata mesajı beklendi, alınan: %q", errMsg)
	}
	if !strings.Contains(errMsg, "İstanbul") {
		t.Errorf("TC-4a: hata mesajında mekan şehri (İstanbul) beklendi, alınan: %q", errMsg)
	}
}

// TC-4b: Guide kendi şehrinde (Ankara/Ankara) → 403 DEĞİL (sonraki adımlarda başka kod devreye girer)
// Burada venueRepo nil olduğu için 500 veya panic beklenir; ama 403 olmamalı.
// Testin amacı: şehir kısıtı AŞILDI, yani guard farklı şehir kontrolünü geçti.
func TestCreate_GuideSameCity_NotBlocked(t *testing.T) {
	getter := &fakeGuideCityGetter{city: str("Ankara")}
	app := setupCityGuardApp("guide-1", string(models.RoleGuide), getter)

	req := httptest.NewRequest(http.MethodPost, "/venues", venueBody("Ankara"))
	req.Header.Set("Content-Type", "application/json")

	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("istek gönderilemedi: %v", err)
	}
	// 403 olmamalı — şehir kısıtı geçildi; venueRepo nil olduğu için muhtemelen 500 gelir.
	if resp.StatusCode == http.StatusForbidden {
		t.Fatalf("TC-4b: aynı şehirde 403 gelmemeli, alındı")
	}
}

// TC-4c: Admin farklı şehirde (guide_city=Ankara, venue city=İstanbul) → 403 DEĞİL (admin muaf)
func TestCreate_AdminDifferentCity_NotBlocked(t *testing.T) {
	// Admin için userRepo.GetGuideCity HİÇ çağrılmamalı; getter nil geçip nil döner fark etmez.
	getter := &fakeGuideCityGetter{city: str("Ankara")}
	app := setupCityGuardApp("admin-1", "admin", getter)

	req := httptest.NewRequest(http.MethodPost, "/venues", venueBody("İstanbul"))
	req.Header.Set("Content-Type", "application/json")

	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("istek gönderilemedi: %v", err)
	}
	// Admin için şehir kısıtı uygulanmamalı.
	if resp.StatusCode == http.StatusForbidden {
		t.Fatalf("TC-4c: admin için 403 gelmemeli, alındı")
	}
}

// TC-4d: guide_city NULL ise belirsizlikte izin verilir → 403 DEĞİL
func TestCreate_GuideNullCity_Allowed(t *testing.T) {
	getter := &fakeGuideCityGetter{city: nil} // guide_city NULL
	app := setupCityGuardApp("guide-1", string(models.RoleGuide), getter)

	req := httptest.NewRequest(http.MethodPost, "/venues", venueBody("İstanbul"))
	req.Header.Set("Content-Type", "application/json")

	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("istek gönderilemedi: %v", err)
	}
	if resp.StatusCode == http.StatusForbidden {
		t.Fatalf("TC-4d: guide_city NULL'da 403 gelmemeli, alındı")
	}
}
