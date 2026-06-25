package handlers

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gofiber/fiber/v2"
)

// fakeDirectionClickCreator — directionClickCreator arayüzünü karşılayan sahte uygulama.
// Testte Create'in çağrılıp çağrılmadığını ve userID'yi yakalar.
type fakeDirectionClickCreator struct {
	called bool
	userID *string
}

func (f *fakeDirectionClickCreator) Create(_ context.Context, _ string, userID *string) error {
	f.called = true
	f.userID = userID
	return nil
}

// TestTrackDirectionClick_Anonymous — kimlik doğrulama olmadan POST → 204, userID nil.
func TestTrackDirectionClick_Anonymous(t *testing.T) {
	fake := &fakeDirectionClickCreator{}

	h := &VenueHandler{
		directionRepo: fake,
	}

	app := fiber.New()
	// Auth middleware yok — Locals'da userID set edilmez
	app.Post("/venues/:id/direction-click", h.TrackDirectionClick)

	req := httptest.NewRequest(http.MethodPost, "/venues/some-venue-id/direction-click", nil)
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("istek gönderilemedi: %v", err)
	}
	if resp.StatusCode != http.StatusNoContent {
		t.Fatalf("anonim: 204 beklendi, %d alındı", resp.StatusCode)
	}
	if !fake.called {
		t.Fatal("anonim: Create çağrılmadı")
	}
	if fake.userID != nil {
		t.Fatalf("anonim: userID nil beklendi, alınan: %v", *fake.userID)
	}
}

// TestTrackDirectionClick_Authenticated — token ile POST → 204, userID set.
func TestTrackDirectionClick_Authenticated(t *testing.T) {
	const testUserID = "user-abc-123"

	fake := &fakeDirectionClickCreator{}

	h := &VenueHandler{
		directionRepo: fake,
	}

	app := fiber.New()
	// Auth middleware simülasyonu: Locals'a userID set et
	app.Use(func(c *fiber.Ctx) error {
		c.Locals("userID", testUserID)
		return c.Next()
	})
	app.Post("/venues/:id/direction-click", h.TrackDirectionClick)

	req := httptest.NewRequest(http.MethodPost, "/venues/some-venue-id/direction-click", nil)
	resp, err := app.Test(req)
	if err != nil {
		t.Fatalf("istek gönderilemedi: %v", err)
	}
	if resp.StatusCode != http.StatusNoContent {
		t.Fatalf("auth'lu: 204 beklendi, %d alındı", resp.StatusCode)
	}
	if !fake.called {
		t.Fatal("auth'lu: Create çağrılmadı")
	}
	if fake.userID == nil {
		t.Fatal("auth'lu: userID nil olmamalı")
	}
	if *fake.userID != testUserID {
		t.Fatalf("auth'lu: userID %q beklendi, alınan: %q", testUserID, *fake.userID)
	}
}
