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

// --- fakeVenueStore ---
//
// venueStore geniş bir arayüz (VenueHandler'ın 20 endpoint'i tek yapıda topluyor);
// burada yalnızca test edilen uçların kullandığı metotlar davranış taşır,
// kalanlar arayüzü karşılamak için boş bırakıldı.
type fakeVenueStore struct {
	venue      *models.Venue
	findErr    error
	confirmErr error
	verifyErr  error
	dropped    []string

	gotVenueID   string
	gotGuideID   string
	gotGuideCity string
	gotPeriod    int
}

func (f *fakeVenueStore) FindByID(_ context.Context, _ string) (*models.Venue, error) {
	if f.findErr != nil {
		return nil, f.findErr
	}
	if f.venue == nil {
		return &models.Venue{ID: "v1", Name: "Test Mekan"}, nil
	}
	return f.venue, nil
}

func (f *fakeVenueStore) ConfirmVenue(_ context.Context, venueID, guideID, guideCity string, periodDays int) error {
	f.gotVenueID, f.gotGuideID, f.gotGuideCity, f.gotPeriod = venueID, guideID, guideCity, periodDays
	return f.confirmErr
}

func (f *fakeVenueStore) VerifyByGuide(_ context.Context, venueID, guideID string, periodDays int) ([]string, error) {
	f.gotVenueID, f.gotGuideID, f.gotPeriod = venueID, guideID, periodDays
	return f.dropped, f.verifyErr
}

func (f *fakeVenueStore) FindByGooglePlaceID(_ context.Context, _ string) (*models.Venue, error) {
	if f.findErr != nil {
		return nil, f.findErr
	}
	return f.venue, nil
}

// --- arayüzü karşılayan boş metotlar ---

func (f *fakeVenueStore) FindByCity(context.Context, string, float64, float64, int) ([]models.Venue, error) {
	return nil, nil
}
func (f *fakeVenueStore) FindByFoodCategory(context.Context, int) ([]models.Venue, error) {
	return nil, nil
}
func (f *fakeVenueStore) FindNearby(context.Context, float64, float64, float64) ([]models.Venue, error) {
	return nil, nil
}
func (f *fakeVenueStore) FindNearbyApproved(context.Context, float64, float64, float64, int) ([]models.Venue, error) {
	return nil, nil
}
func (f *fakeVenueStore) FindPopular(context.Context, float64, float64, float64, int) ([]models.Venue, error) {
	return nil, nil
}
func (f *fakeVenueStore) FindDistinctCities(context.Context) ([]string, error)          { return nil, nil }
func (f *fakeVenueStore) SearchByText(context.Context, string) ([]models.Venue, error)  { return nil, nil }
func (f *fakeVenueStore) Create(context.Context, *models.Venue) error                   { return nil }
func (f *fakeVenueStore) ResetToPending(context.Context, string) error                  { return nil }
func (f *fakeVenueStore) AddPhoto(context.Context, *models.VenuePhoto) error            { return nil }
func (f *fakeVenueStore) DeletePhoto(context.Context, string, string) error             { return nil }
func (f *fakeVenueStore) SetCriteria(context.Context, string, []int) error              { return nil }
func (f *fakeVenueStore) SetVenueFoodItems(context.Context, string, []int) error        { return nil }
func (f *fakeVenueStore) SetFoodHalalMode(context.Context, string, string) error        { return nil }
func (f *fakeVenueStore) SetExcludedProducts(context.Context, string, []string) error   { return nil }
func (f *fakeVenueStore) Approve(context.Context, string, string, int) error            { return nil }
func (f *fakeVenueStore) HasConfirmed(context.Context, string, string) (bool, error)    { return false, nil }

func (f *fakeVenueStore) UpdateVenue(context.Context, string, *string, *string, *string, *float64, *float64, *string, *string) error {
	return nil
}
func (f *fakeVenueStore) FindPhotoByID(context.Context, string) (*models.VenuePhoto, error) {
	return nil, nil
}
func (f *fakeVenueStore) GetPhotosByVenueID(context.Context, string) ([]models.VenuePhoto, error) {
	return nil, nil
}
func (f *fakeVenueStore) GetAllCriteria(context.Context) ([]models.HalalCriteria, error) {
	return nil, nil
}
func (f *fakeVenueStore) GetCriteriaByVenueID(context.Context, string) ([]models.HalalCriteria, error) {
	return nil, nil
}
func (f *fakeVenueStore) GetAllFoodCategoriesWithItems(context.Context) ([]models.FoodCategory, error) {
	return nil, nil
}
func (f *fakeVenueStore) GetFoodItemsByVenueID(context.Context, string) ([]models.FoodItem, error) {
	return nil, nil
}
func (f *fakeVenueStore) CreateCustomFoodItem(context.Context, int, string, string) (*models.FoodItem, error) {
	return nil, nil
}

// --- yardımcı fake'ler ---

type fakeVerifLogger struct {
	entries []string
	err     error
}

func (f *fakeVerifLogger) Create(_ context.Context, venueID, guideID, action string) error {
	f.entries = append(f.entries, venueID+"|"+guideID+"|"+action)
	return f.err
}

type fakeResetNotifier struct {
	sentTo []string
	err    error
}

func (f *fakeResetNotifier) SendConfirmationReset(_ context.Context, guideID, _, _ string) error {
	f.sentTo = append(f.sentTo, guideID)
	return f.err
}

// --- helper ---

func setupVenueConfirmApp(store venueStore, getter guideCityGetter, logger verificationLogger,
	notifier confirmationResetNotifier, userID, role string) *fiber.App {
	app := fiber.New()
	h := &VenueHandler{
		venueRepo:              store,
		userRepo:               getter,
		verifLogRepo:           logger,
		verificationPeriodDays: 180,
	}
	if notifier != nil {
		h.notifService = notifier
	}
	app.Use(func(c *fiber.Ctx) error {
		if userID != "" {
			c.Locals("userID", userID)
		}
		if role != "" {
			c.Locals("userRole", role)
		}
		return c.Next()
	})
	app.Post("/venues/:id/confirm", h.ConfirmVenue)
	app.Put("/venues/:id/verify", h.Verify)
	app.Get("/venues/check-duplicate", h.CheckDuplicate)
	return app
}

// --- ConfirmVenue ---

func TestConfirmVenue(t *testing.T) {
	tests := []struct {
		name       string
		userID     string
		confirmErr error
		wantStatus int
	}{
		{name: "başarılı", userID: "g1", wantStatus: fiber.StatusOK},
		{name: "giriş yapılmamış", userID: "", wantStatus: fiber.StatusUnauthorized},
		{name: "mekan yok", userID: "g1", confirmErr: repository.ErrNotFound, wantStatus: fiber.StatusNotFound},
		// Repo'nun iş kuralı hataları kullanıcıya 400 olarak dönmeli, 500 değil:
		// bunlar beklenen durumlar, sunucu arızası değil.
		{name: "zaten doğrulanmış", userID: "g1", confirmErr: errors.New("bu mekanı zaten doğrulamışsınız"), wantStatus: fiber.StatusBadRequest},
		{name: "kendi eklediği mekan", userID: "g1", confirmErr: errors.New("kendi eklediğiniz mekanı doğrulayamazsınız"), wantStatus: fiber.StatusBadRequest},
		{name: "onaylı olmayan mekan", userID: "g1", confirmErr: errors.New("yalnızca onaylı mekanlar doğrulanabilir"), wantStatus: fiber.StatusBadRequest},
		{name: "başka şehir", userID: "g1", confirmErr: errors.New("yalnızca rehberi olduğunuz şehirde"), wantStatus: fiber.StatusBadRequest},
		// Tanınmayan hata gerçekten sunucu arızası sayılmalı.
		{name: "beklenmeyen db hatası", userID: "g1", confirmErr: errors.New("connection reset"), wantStatus: fiber.StatusInternalServerError},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			store := &fakeVenueStore{confirmErr: tt.confirmErr}
			getter := &fakeGuideCityGetter{city: str("İstanbul")}
			app := setupVenueConfirmApp(store, getter, &fakeVerifLogger{}, &fakeResetNotifier{}, tt.userID, "guide")
			resp := doJSON(t, app, http.MethodPost, "/venues/v1/confirm", "")
			if resp.StatusCode != tt.wantStatus {
				t.Fatalf("beklenen %d, alınan %d", tt.wantStatus, resp.StatusCode)
			}
		})
	}
}

func TestConfirmVenueFeedsGuideCity(t *testing.T) {
	// Şehir kısıtı repo'da uygulanıyor; handler rehberin şehrini doğru
	// beslemezse kısıt sessizce devre dışı kalır.
	t.Run("guide rolünde şehir gönderilir", func(t *testing.T) {
		store := &fakeVenueStore{}
		getter := &fakeGuideCityGetter{city: str("Ankara")}
		app := setupVenueConfirmApp(store, getter, &fakeVerifLogger{}, &fakeResetNotifier{}, "g1", "guide")
		doJSON(t, app, http.MethodPost, "/venues/v9/confirm", "")
		if store.gotGuideCity != "Ankara" {
			t.Fatalf("guideCity %q, beklenen Ankara", store.gotGuideCity)
		}
		if store.gotVenueID != "v9" || store.gotGuideID != "g1" {
			t.Fatalf("venue/guide yanlış: %s/%s", store.gotVenueID, store.gotGuideID)
		}
	})

	// Admin şehir kısıtına tabi değil: boş şehir gönderilir.
	t.Run("admin rolünde şehir boş gider", func(t *testing.T) {
		store := &fakeVenueStore{}
		getter := &fakeGuideCityGetter{city: str("Ankara")}
		app := setupVenueConfirmApp(store, getter, &fakeVerifLogger{}, &fakeResetNotifier{}, "a1", "admin")
		doJSON(t, app, http.MethodPost, "/venues/v1/confirm", "")
		if store.gotGuideCity != "" {
			t.Fatalf("admin için şehir boş olmalıydı, alınan %q", store.gotGuideCity)
		}
	})

	t.Run("şehir sorgusu hata verirse 500", func(t *testing.T) {
		getter := &fakeGuideCityGetter{err: errors.New("db")}
		app := setupVenueConfirmApp(&fakeVenueStore{}, getter, &fakeVerifLogger{}, &fakeResetNotifier{}, "g1", "guide")
		resp := doJSON(t, app, http.MethodPost, "/venues/v1/confirm", "")
		if resp.StatusCode != fiber.StatusInternalServerError {
			t.Fatalf("beklenen 500, alınan %d", resp.StatusCode)
		}
	})
}

// --- Verify ---

func TestVenueVerify(t *testing.T) {
	tests := []struct {
		name       string
		userID     string
		verifyErr  error
		wantStatus int
	}{
		{name: "başarılı", userID: "g1", wantStatus: fiber.StatusOK},
		{name: "giriş yapılmamış", userID: "", wantStatus: fiber.StatusUnauthorized},
		// Mekanı ekleyen kişi değilse repo ErrNotFound döner → 404.
		{name: "ekleyen değil / mekan yok", userID: "g2", verifyErr: repository.ErrNotFound, wantStatus: fiber.StatusNotFound},
		{name: "db hatası", userID: "g1", verifyErr: errors.New("db"), wantStatus: fiber.StatusInternalServerError},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			store := &fakeVenueStore{verifyErr: tt.verifyErr}
			app := setupVenueConfirmApp(store, &fakeGuideCityGetter{}, &fakeVerifLogger{}, &fakeResetNotifier{}, tt.userID, "guide")
			resp := doJSON(t, app, http.MethodPut, "/venues/v1/verify", "")
			if resp.StatusCode != tt.wantStatus {
				t.Fatalf("beklenen %d, alınan %d", tt.wantStatus, resp.StatusCode)
			}
		})
	}
}

func TestVenueVerifyNotifiesDroppedGuides(t *testing.T) {
	// Yeniden doğrulama diğer rehberlerin onaylarını sıfırlıyor; sıfırlananlara
	// haber verilmezse rozetleri sessizce düşer.
	t.Run("düşen rehberlere bildirim gider", func(t *testing.T) {
		store := &fakeVenueStore{dropped: []string{"g7", "g8"}}
		notifier := &fakeResetNotifier{}
		app := setupVenueConfirmApp(store, &fakeGuideCityGetter{}, &fakeVerifLogger{}, notifier, "g1", "guide")
		doJSON(t, app, http.MethodPut, "/venues/v1/verify", "")
		if len(notifier.sentTo) != 2 || notifier.sentTo[0] != "g7" || notifier.sentTo[1] != "g8" {
			t.Fatalf("bildirim alıcıları yanlış: %v", notifier.sentTo)
		}
	})

	t.Run("düşen yoksa bildirim gitmez", func(t *testing.T) {
		store := &fakeVenueStore{dropped: nil}
		notifier := &fakeResetNotifier{}
		app := setupVenueConfirmApp(store, &fakeGuideCityGetter{}, &fakeVerifLogger{}, notifier, "g1", "guide")
		doJSON(t, app, http.MethodPut, "/venues/v1/verify", "")
		if len(notifier.sentTo) != 0 {
			t.Fatalf("bildirim gitmemeliydi: %v", notifier.sentTo)
		}
	})

	// Bildirim servisi yoksa istek yine de başarılı olmalı (fire-and-forget).
	// Bu test aynı zamanda "tipli nil" tuzağını sabitler: notifService arayüz
	// alanı olduğu için nil bir servis yanlışlıkla non-nil görünürse panic olur.
	t.Run("bildirim servisi yokken panic olmaz", func(t *testing.T) {
		store := &fakeVenueStore{dropped: []string{"g7"}}
		app := setupVenueConfirmApp(store, &fakeGuideCityGetter{}, &fakeVerifLogger{}, nil, "g1", "guide")
		resp := doJSON(t, app, http.MethodPut, "/venues/v1/verify", "")
		if resp.StatusCode != fiber.StatusOK {
			t.Fatalf("beklenen 200, alınan %d", resp.StatusCode)
		}
	})

	t.Run("doğrulama iz kaydı yazılır", func(t *testing.T) {
		logger := &fakeVerifLogger{}
		app := setupVenueConfirmApp(&fakeVenueStore{}, &fakeGuideCityGetter{}, logger, &fakeResetNotifier{}, "g1", "guide")
		doJSON(t, app, http.MethodPut, "/venues/v42/verify", "")
		if len(logger.entries) != 1 || logger.entries[0] != "v42|g1|verified" {
			t.Fatalf("iz kaydı yanlış: %v", logger.entries)
		}
	})
}

func TestVenueVerifyPassesConfiguredPeriod(t *testing.T) {
	// Periyot config'den geliyor; sabit kodlanırsa prod ayarı etkisiz kalır.
	store := &fakeVenueStore{}
	app := setupVenueConfirmApp(store, &fakeGuideCityGetter{}, &fakeVerifLogger{}, &fakeResetNotifier{}, "g1", "guide")
	doJSON(t, app, http.MethodPut, "/venues/v1/verify", "")
	if store.gotPeriod != 180 {
		t.Fatalf("periyot %d, beklenen 180 (handler config'i geçmeli)", store.gotPeriod)
	}
}

// TestNewVenueHandlerNilNotifierStaysNil — "tipli nil" tuzağına karşı koruma.
//
// notifService arayüz alanı olduğu için, nil bir *services.NotificationService
// doğrudan atanırsa alan non-nil GÖRÜNÜR (tipli nil) ve Verify içindeki
// `h.notifService != nil` kontrolü yanlışlıkla geçip panic üretir.
// Constructor açık kontrol yapmalı; bu test o kontrolü sabitler.
func TestNewVenueHandlerNilNotifierStaysNil(t *testing.T) {
	h := NewVenueHandler(nil, nil, nil, nil, nil, nil, nil, 180)
	if h.notifService != nil {
		t.Fatal("nil notifService atandığında alan gerçekten nil kalmalı (tipli nil tuzağı)")
	}
}

// --- CheckDuplicate ---

func TestVenueCheckDuplicate(t *testing.T) {
	t.Run("place_id zorunlu", func(t *testing.T) {
		app := setupVenueConfirmApp(&fakeVenueStore{}, &fakeGuideCityGetter{}, &fakeVerifLogger{}, &fakeResetNotifier{}, "g1", "guide")
		resp := doJSON(t, app, http.MethodGet, "/venues/check-duplicate", "")
		if resp.StatusCode != fiber.StatusBadRequest {
			t.Fatalf("beklenen 400, alınan %d", resp.StatusCode)
		}
	})

	t.Run("mevcut mekan bulunur", func(t *testing.T) {
		store := &fakeVenueStore{venue: &models.Venue{ID: "v1", Name: "Var Olan"}}
		app := setupVenueConfirmApp(store, &fakeGuideCityGetter{}, &fakeVerifLogger{}, &fakeResetNotifier{}, "g1", "guide")
		resp := doJSON(t, app, http.MethodGet, "/venues/check-duplicate?google_place_id=ChIJabc", "")
		if resp.StatusCode != fiber.StatusOK {
			t.Fatalf("beklenen 200, alınan %d", resp.StatusCode)
		}
	})

	t.Run("mekan yoksa da 200 döner", func(t *testing.T) {
		store := &fakeVenueStore{findErr: repository.ErrNotFound}
		app := setupVenueConfirmApp(store, &fakeGuideCityGetter{}, &fakeVerifLogger{}, &fakeResetNotifier{}, "g1", "guide")
		resp := doJSON(t, app, http.MethodGet, "/venues/check-duplicate?google_place_id=ChIJabc", "")
		if resp.StatusCode != fiber.StatusOK {
			t.Fatalf("beklenen 200, alınan %d", resp.StatusCode)
		}
	})
}
