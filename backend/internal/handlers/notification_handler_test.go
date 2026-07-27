package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gofiber/fiber/v2"

	"github.com/omerkoc/itimat-mobile/internal/models"
	"github.com/omerkoc/itimat-mobile/internal/repository"
)

// --- fakeNotifStore ---

type fakeNotifStore struct {
	notifications []*models.Notification
	unreadCount   int
	markReadErr   error
	markAllErr    error
	listErr       error
	countErr      error
}

func (f *fakeNotifStore) ListByUserID(_ context.Context, userID string, limit, offset int) ([]*models.Notification, error) {
	if f.listErr != nil {
		return nil, f.listErr
	}
	var result []*models.Notification
	for _, n := range f.notifications {
		if n.UserID == userID {
			result = append(result, n)
		}
	}
	// sayfalama uygula
	if offset >= len(result) {
		return []*models.Notification{}, nil
	}
	end := offset + limit
	if end > len(result) {
		end = len(result)
	}
	return result[offset:end], nil
}

func (f *fakeNotifStore) UnreadCount(_ context.Context, _ string) (int, error) {
	return f.unreadCount, f.countErr
}

func (f *fakeNotifStore) MarkRead(_ context.Context, _, userID string) error {
	return f.markReadErr
}

func (f *fakeNotifStore) MarkAllRead(_ context.Context, _ string) error {
	return f.markAllErr
}

// --- test helpers ---

func setupNotifApp(store NotificationStore, userID string) *fiber.App {
	app := fiber.New()
	h := NewNotificationHandler(store)
	app.Use(func(c *fiber.Ctx) error {
		c.Locals("userID", userID)
		return c.Next()
	})
	app.Get("/notifications", h.List)
	app.Get("/notifications/unread-count", h.UnreadCount)
	app.Put("/notifications/read-all", h.MarkAllRead)
	app.Put("/notifications/:id/read", h.MarkRead)
	return app
}

func decodeBody(t *testing.T, body io.Reader) map[string]any {
	t.Helper()
	var m map[string]any
	if err := json.NewDecoder(body).Decode(&m); err != nil {
		t.Fatalf("body decode hatası: %v", err)
	}
	return m
}

// --- testler ---

func TestNotificationList_OnlyReturnsOwnNotifications(t *testing.T) {
	// TC-12: sadece kendi bildirimleri dönmeli
	store := &fakeNotifStore{
		notifications: []*models.Notification{
			{ID: "n1", UserID: "user-A", Title: "A bildirimi", CreatedAt: time.Now()},
			{ID: "n2", UserID: "user-B", Title: "B bildirimi", CreatedAt: time.Now()},
		},
	}
	app := setupNotifApp(store, "user-A")

	req := httptest.NewRequest(http.MethodGet, "/notifications", nil)
	resp, _ := app.Test(req)

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("beklenen: 200, gelen: %d", resp.StatusCode)
	}
	body := decodeBody(t, resp.Body)
	data := body["data"].([]any)
	if len(data) != 1 {
		t.Fatalf("TC-12: 1 bildirim beklendi, %d geldi", len(data))
	}
	first := data[0].(map[string]any)
	if first["id"] != "n1" {
		t.Errorf("TC-12: yanlış bildirim döndü: %v", first["id"])
	}
}

func TestNotificationList_EmptyReturnsArrayNotNull(t *testing.T) {
	// TC-13: hiç bildirim yoksa [] döner, null değil
	store := &fakeNotifStore{notifications: nil}
	app := setupNotifApp(store, "user-A")

	req := httptest.NewRequest(http.MethodGet, "/notifications", nil)
	resp, _ := app.Test(req)

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("beklenen: 200, gelen: %d", resp.StatusCode)
	}
	body := decodeBody(t, resp.Body)
	if body["data"] == nil {
		t.Fatal("TC-13: data nil döndü, [] beklendi")
	}
	data := body["data"].([]any)
	if len(data) != 0 {
		t.Fatalf("TC-13: boş liste beklendi, %d eleman geldi", len(data))
	}
}

func TestNotificationList_DefaultPagination(t *testing.T) {
	// page ve limit response'da dönmeli
	store := &fakeNotifStore{}
	app := setupNotifApp(store, "user-A")

	req := httptest.NewRequest(http.MethodGet, "/notifications", nil)
	resp, _ := app.Test(req)

	body := decodeBody(t, resp.Body)
	if body["page"] != float64(1) {
		t.Errorf("varsayılan page=1 beklendi, gelen: %v", body["page"])
	}
	if body["limit"] != float64(20) {
		t.Errorf("varsayılan limit=20 beklendi, gelen: %v", body["limit"])
	}
}

func TestNotificationList_NoAuth_Returns401(t *testing.T) {
	store := &fakeNotifStore{}
	app := fiber.New()
	h := NewNotificationHandler(store)
	app.Get("/notifications", h.List) // middleware yok → userID set edilmez

	req := httptest.NewRequest(http.MethodGet, "/notifications", nil)
	resp, _ := app.Test(req)

	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("auth olmadan 401 beklendi, gelen: %d", resp.StatusCode)
	}
}

func TestUnreadCount_ReturnsCorrectNumber(t *testing.T) {
	// TC-14: unread count doğru döner
	store := &fakeNotifStore{unreadCount: 3}
	app := setupNotifApp(store, "user-A")

	req := httptest.NewRequest(http.MethodGet, "/notifications/unread-count", nil)
	resp, _ := app.Test(req)

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("beklenen: 200, gelen: %d", resp.StatusCode)
	}
	body := decodeBody(t, resp.Body)
	if body["count"] != float64(3) {
		t.Errorf("TC-14: count=3 beklendi, gelen: %v", body["count"])
	}
}

func TestMarkRead_OtherUsersNotification_Returns404(t *testing.T) {
	// TC-15: başka kullanıcının bildirimi işaretlenince 404
	store := &fakeNotifStore{markReadErr: repository.ErrNotFound}
	app := setupNotifApp(store, "user-A")

	req := httptest.NewRequest(http.MethodPut, "/notifications/other-notif-id/read", nil)
	resp, _ := app.Test(req)

	if resp.StatusCode != http.StatusNotFound {
		t.Fatalf("TC-15: 404 beklendi, gelen: %d", resp.StatusCode)
	}
}

func TestMarkRead_OwnNotification_Returns200(t *testing.T) {
	store := &fakeNotifStore{markReadErr: nil}
	app := setupNotifApp(store, "user-A")

	req := httptest.NewRequest(http.MethodPut, "/notifications/my-notif-id/read", nil)
	resp, _ := app.Test(req)

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("beklenen: 200, gelen: %d", resp.StatusCode)
	}
	body := decodeBody(t, resp.Body)
	if body["status"] != "ok" {
		t.Errorf("beklenen: status=ok, gelen: %v", body["status"])
	}
}

func TestMarkAllRead_Returns200(t *testing.T) {
	// TC-16: tümünü okundu işaretle
	store := &fakeNotifStore{}
	app := setupNotifApp(store, "user-A")

	req := httptest.NewRequest(http.MethodPut, "/notifications/read-all", nil)
	resp, _ := app.Test(req)

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("TC-16: 200 beklendi, gelen: %d", resp.StatusCode)
	}
	body := decodeBody(t, resp.Body)
	if body["status"] != "ok" {
		t.Errorf("beklenen: status=ok, gelen: %v", body["status"])
	}
}

func TestNotificationList_DBError_Returns500(t *testing.T) {
	// DB hatasında 500 dönmeli
	store := &fakeNotifStore{listErr: fmt.Errorf("db connection lost")}
	app := setupNotifApp(store, "user-A")

	req := httptest.NewRequest(http.MethodGet, "/notifications", nil)
	resp, _ := app.Test(req)

	if resp.StatusCode != http.StatusInternalServerError {
		t.Fatalf("DB hatasında 500 beklendi, gelen: %d", resp.StatusCode)
	}
}
