package handlers

import (
	"bytes"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gofiber/fiber/v2"

	"github.com/omerkoc/itimat-mobile/internal/services"
)

// TestPlacePhotoProxyReturnsFullImage — proxy'nin görselin TAMAMINI döndürdüğünü
// doğrular.
//
// Regresyon: handler önce `FetchPhoto`'nun döndürdüğü gövdeyi `SendStream` ile
// yazdırıyordu. İki sorun vardı:
//  1. `defer body.Close()` gövdeyi handler dönerken kapatıyordu; oysa SendStream
//     gövdeyi handler DÖNDÜKTEN SONRA okur.
//  2. Yukarı akış isteği Fiber'ın request context'ine bağlıydı; o context handler
//     dönünce geri dönüştürülüyor ve istek iptal ediliyordu.
//
// Sonuç: istemci HTTP status'ü olmayan, yarıda kesilmiş bir yanıt alıyordu
// (Dio tarafında "DioException [unknown]: null") ve fotoğraflar hiç görünmüyordu.
// Yukarı akış gövdeyi parça parça ve gecikmeli gönderdiğinde hata kesinleşiyor.
func TestPlacePhotoProxyReturnsFullImage(t *testing.T) {
	// Gerçek bir Places fotoğrafı büyüklüğünde gövde.
	payload := bytes.Repeat([]byte("itimat-photo-bytes"), 12000) // ~216 KB

	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "image/jpeg")
		w.WriteHeader(http.StatusOK)
		flusher, ok := w.(http.Flusher)
		if !ok {
			t.Error("test sunucusu flush desteklemiyor")
			return
		}
		// Google gövdeyi tek seferde vermez; parçalı ve gecikmeli gönderim
		// handler döndükten sonra okuma yapılıp yapılmadığını açığa çıkarır.
		const chunks = 4
		size := len(payload) / chunks
		for i := 0; i < chunks; i++ {
			end := (i + 1) * size
			if i == chunks-1 {
				end = len(payload)
			}
			if _, err := w.Write(payload[i*size : end]); err != nil {
				return
			}
			flusher.Flush()
			time.Sleep(15 * time.Millisecond)
		}
	}))
	defer upstream.Close()

	places := services.NewPlacesServiceWithBaseURL("test-key", upstream.URL)
	app := setupPhotoProxyApp(places)

	req := httptest.NewRequest(http.MethodGet, "/places/photo?ref=abc&w=800", nil)
	// Fiber varsayılan test zaman aşımı kısa; parçalı yanıt için genişlet.
	resp, err := app.Test(req, 10000)
	if err != nil {
		t.Fatalf("istek başarısız: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != fiber.StatusOK {
		t.Fatalf("beklenen 200, alınan %d", resp.StatusCode)
	}
	if ct := resp.Header.Get("Content-Type"); ct != "image/jpeg" {
		t.Errorf("beklenen content-type image/jpeg, alınan %q", ct)
	}

	got, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatalf("yanıt gövdesi okunamadı: %v", err)
	}
	if len(got) != len(payload) {
		t.Fatalf("gövde eksik: beklenen %d bayt, alınan %d", len(payload), len(got))
	}
	if !bytes.Equal(got, payload) {
		t.Fatal("gövde içeriği yukarı akıştan farklı")
	}
}
