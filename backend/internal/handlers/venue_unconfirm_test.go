package handlers

import (
	"encoding/json"
	"net/http"
	"testing"
	"time"

	"github.com/gofiber/fiber/v2"

	"github.com/omerkoc/itimat-mobile/internal/models"
	"github.com/omerkoc/itimat-mobile/internal/repository"
)

// unconfirmApp — DELETE /venues/:id/confirm ucunu verilen kimlikle kurar.
func unconfirmApp(store *fakeVenueStore, userID string) *fiber.App {
	h := &VenueHandler{venueRepo: store, verificationPeriodDays: 180}
	app := fiber.New()
	app.Delete("/venues/:id/confirm", func(c *fiber.Ctx) error {
		if userID != "" {
			c.Locals("userID", userID)
		}
		c.Locals("userRole", string(models.RoleGuide))
		return h.RemoveConfirmation(c)
	})
	return app
}

// TestRemoveConfirmation_UsesTokenGuideID — silinecek kayıt path'ten değil
// token'dan gelen guideID ile belirlenir; rehber başkasının kaydını silemez.
func TestRemoveConfirmation_UsesTokenGuideID(t *testing.T) {
	store := &fakeVenueStore{}
	app := unconfirmApp(store, "guide-1")

	resp := doJSON(t, app, http.MethodDelete, "/venues/v1/confirm", "")
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("200 beklendi, %d alındı", resp.StatusCode)
	}
	if store.gotVenueID != "v1" {
		t.Errorf("venueID = %q, want v1", store.gotVenueID)
	}
	if store.gotGuideID != "guide-1" {
		t.Errorf("guideID = %q, want guide-1 (token'dan gelmeli)", store.gotGuideID)
	}
	if store.gotPeriod != 180 {
		t.Errorf("periodDays = %d, want 180", store.gotPeriod)
	}
}

// TestRemoveConfirmation_NotFound — kaydı olmayan rehber için 404.
func TestRemoveConfirmation_NotFound(t *testing.T) {
	store := &fakeVenueStore{removeConfirmErr: repository.ErrNotFound}
	app := unconfirmApp(store, "guide-1")

	resp := doJSON(t, app, http.MethodDelete, "/venues/v1/confirm", "")
	if resp.StatusCode != http.StatusNotFound {
		t.Fatalf("404 beklendi, %d alındı", resp.StatusCode)
	}
}

// TestRemoveConfirmation_Unauthenticated — token yoksa 401.
func TestRemoveConfirmation_Unauthenticated(t *testing.T) {
	store := &fakeVenueStore{}
	app := unconfirmApp(store, "")

	resp := doJSON(t, app, http.MethodDelete, "/venues/v1/confirm", "")
	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("401 beklendi, %d alındı", resp.StatusCode)
	}
	if store.gotVenueID != "" {
		t.Error("kimliksiz istekte repo çağrılmamalıydı")
	}
}

// TestMyConfirmations — liste ucu token'daki kullanıcının doğrulamalarını döner.
func TestMyConfirmations(t *testing.T) {
	confirmedAt := time.Date(2026, 3, 12, 10, 0, 0, 0, time.UTC)
	lister := &fakeGuideVenueLister{
		confirmed: []models.Venue{
			{ID: "v1", Name: "Doğruladığım Mekan", ConfirmedAt: &confirmedAt},
		},
	}
	app := setupGuideApp(&fakeGuideStore{}, lister, "guide-7", "guide")

	resp := doJSON(t, app, http.MethodGet, "/guide/my-confirmations", "")
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("200 beklendi, %d alındı", resp.StatusCode)
	}
	if lister.gotConfirmedUserID != "guide-7" {
		t.Errorf("guideID = %q, want guide-7", lister.gotConfirmedUserID)
	}

	var got []models.Venue
	if err := json.NewDecoder(resp.Body).Decode(&got); err != nil {
		t.Fatalf("yanıt çözümlenemedi: %v", err)
	}
	if len(got) != 1 || got[0].ID != "v1" {
		t.Fatalf("beklenen tek mekan v1, alınan: %+v", got)
	}
	if got[0].ConfirmedAt == nil {
		t.Error("confirmed_at JSON'a yazılmalıydı")
	}
}
