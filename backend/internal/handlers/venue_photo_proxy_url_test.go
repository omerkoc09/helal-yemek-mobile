package handlers

import "testing"

// parsePlacePhotoProxyURL — mekan oluştururken gelen fotoğraf adresinin kendi
// proxy'mize mi ait olduğunu belirler.
//
// Regresyon: istemciye verilen adres GÖRELİ proxy yolu ("/api/v1/places/photo?ref=..")
// ama SSRF guard https + Google host şartı arıyordu. Bu yüzden seçilen fotoğraflar
// indirilemiyor, hata log'a yazılıp yutuluyor ve mekan sessizce FOTOĞRAFSIZ
// oluşuyordu (proxy'ye geçişten beri hiçbir yeni mekanda fotoğraf yok).
func TestParsePlacePhotoProxyURL(t *testing.T) {
	t.Run("göreli proxy yolu tanınır", func(t *testing.T) {
		ref, width, ok := parsePlacePhotoProxyURL("/api/v1/places/photo?ref=ABC&w=800")
		if !ok {
			t.Fatal("proxy yolu tanınmadı")
		}
		if ref != "ABC" {
			t.Fatalf("beklenen ref ABC, alınan %q", ref)
		}
		if width != 800 {
			t.Fatalf("beklenen genişlik 800, alınan %d", width)
		}
	})

	t.Run("tam URL biçimi de tanınır", func(t *testing.T) {
		// resolveMediaUrl istemcide tam URL üretiyor; geri gönderilebilir.
		ref, _, ok := parsePlacePhotoProxyURL("http://10.0.2.2:3000/api/v1/places/photo?ref=XYZ&w=400")
		if !ok || ref != "XYZ" {
			t.Fatalf("tam URL tanınmadı: ref=%q ok=%v", ref, ok)
		}
	})

	t.Run("w yoksa varsayılan genişlik", func(t *testing.T) {
		_, width, ok := parsePlacePhotoProxyURL("/api/v1/places/photo?ref=ABC")
		if !ok {
			t.Fatal("proxy yolu tanınmadı")
		}
		if width != defaultPhotoWidth {
			t.Fatalf("beklenen %d, alınan %d", defaultPhotoWidth, width)
		}
	})

	t.Run("ref yoksa proxy sayılmaz", func(t *testing.T) {
		// ref'siz adresten fotoğraf çekilemez; eski yola (DownloadAndStore) düşsün.
		if _, _, ok := parsePlacePhotoProxyURL("/api/v1/places/photo?w=800"); ok {
			t.Fatal("ref'siz adres proxy sayıldı")
		}
	})

	t.Run("Google tam URL'si proxy sayılmaz", func(t *testing.T) {
		// Bu adres doğrudan indirilebilir; guard'dan geçer, eski yol kullanılmalı.
		raw := "https://maps.googleapis.com/maps/api/place/photo?photo_reference=X&key=k"
		if _, _, ok := parsePlacePhotoProxyURL(raw); ok {
			t.Fatal("Google adresi proxy sayıldı")
		}
	})

	t.Run("benzer görünen yabancı yol proxy sayılmaz", func(t *testing.T) {
		if _, _, ok := parsePlacePhotoProxyURL("https://evil.com/not/api/v1/places/photoX?ref=A"); ok {
			t.Fatal("yabancı yol proxy sayıldı")
		}
	})
}
