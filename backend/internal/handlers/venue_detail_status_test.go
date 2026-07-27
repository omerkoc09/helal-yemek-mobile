package handlers

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gofiber/fiber/v2"

	"github.com/omerkoc/itimat-mobile/internal/models"
)

// detailApp — Detail endpoint'ini verilen viewer kimliğiyle kurar.
// userID/role boş bırakılırsa anonim viewer simüle edilir (OptionalAuth davranışı).
func detailApp(store *fakeVenueStore, userID, role string) *fiber.App {
	h := &VenueHandler{venueRepo: store}
	app := fiber.New()
	app.Get("/venues/:id", func(c *fiber.Ctx) error {
		if userID != "" {
			c.Locals("userID", userID)
		}
		if role != "" {
			c.Locals("userRole", role)
		}
		return h.Detail(c)
	})
	return app
}

func detailStatusCode(t *testing.T, app *fiber.App) int {
	t.Helper()
	resp, err := app.Test(httptest.NewRequest(http.MethodGet, "/venues/v1", nil))
	if err != nil {
		t.Fatalf("istek gönderilemedi: %v", err)
	}
	return resp.StatusCode
}

// TestDetail_NonApprovedHiddenFromPublic — rehber düzenlemesi sonrası pending'e
// düşen mekan, admin onaylayana kadar detay ucunda görünmemelidir. Askıya alınan
// ve reddedilen mekanlar için de aynı kural geçerlidir.
func TestDetail_NonApprovedHiddenFromPublic(t *testing.T) {
	hiddenStatuses := []models.VenueStatus{
		models.VenueStatusPending,
		models.VenueStatusRejected,
		models.VenueStatusSuspended,
	}

	for _, status := range hiddenStatuses {
		t.Run(string(status), func(t *testing.T) {
			store := &fakeVenueStore{
				venue: &models.Venue{ID: "v1", Name: "Test Mekan", AddedBy: "guide-1", Status: status},
			}

			// Anonim viewer
			if code := detailStatusCode(t, detailApp(store, "", "")); code != http.StatusNotFound {
				t.Fatalf("anonim viewer: 404 beklendi, %d alındı", code)
			}

			// Mekanı eklemeyen başka bir rehber
			app := detailApp(store, "guide-2", string(models.RoleGuide))
			if code := detailStatusCode(t, app); code != http.StatusNotFound {
				t.Fatalf("yabancı rehber: 404 beklendi, %d alındı", code)
			}
		})
	}
}

// TestDetail_ApprovedVisibleToPublic — onaylı mekan herkese açıktır.
func TestDetail_ApprovedVisibleToPublic(t *testing.T) {
	store := &fakeVenueStore{
		venue: &models.Venue{ID: "v1", Name: "Test Mekan", AddedBy: "guide-1", Status: models.VenueStatusApproved},
	}

	if code := detailStatusCode(t, detailApp(store, "", "")); code != http.StatusOK {
		t.Fatalf("onaylı mekan: 200 beklendi, %d alındı", code)
	}
}

// TestDetail_PendingVisibleToOwnerAndAdmin — ekleyen rehber kendi bekleyen
// mekanını my-venues üzerinden açabilmeli, admin ise her durumu görebilmeli.
func TestDetail_PendingVisibleToOwnerAndAdmin(t *testing.T) {
	store := &fakeVenueStore{
		venue: &models.Venue{ID: "v1", Name: "Test Mekan", AddedBy: "guide-1", Status: models.VenueStatusPending},
	}

	ownerApp := detailApp(store, "guide-1", string(models.RoleGuide))
	if code := detailStatusCode(t, ownerApp); code != http.StatusOK {
		t.Fatalf("ekleyen rehber: 200 beklendi, %d alındı", code)
	}

	adminApp := detailApp(store, "admin-9", string(models.RoleAdmin))
	if code := detailStatusCode(t, adminApp); code != http.StatusOK {
		t.Fatalf("admin: 200 beklendi, %d alındı", code)
	}
}
