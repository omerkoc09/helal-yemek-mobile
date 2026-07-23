package services

import (
	"context"
	"io"
	"math"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
)

// newTestPlacesService — verilen handler'a yönlendirilmiş, sahte Google host'u
// kullanan bir PlacesService döndürür. Sunucu test bitince kapatılır.
func newTestPlacesService(t *testing.T, apiKey string, handler http.HandlerFunc) *PlacesService {
	t.Helper()
	srv := httptest.NewServer(handler)
	t.Cleanup(srv.Close)
	return &PlacesService{
		apiKey:  apiKey,
		baseURL: srv.URL,
		client:  srv.Client(),
	}
}

// --- ResolvePlaceID ---

func TestPlacesServiceResolvePlaceID(t *testing.T) {
	t.Run("api anahtarı yoksa boş döner, çağrı yapılmaz", func(t *testing.T) {
		called := false
		s := newTestPlacesService(t, "", func(http.ResponseWriter, *http.Request) {
			called = true
		})
		if got := s.ResolvePlaceID("Kafe", 41.0, 29.0); got != "" {
			t.Fatalf("anahtarsız çağrıda %q döndü, boş beklenirdi", got)
		}
		if called {
			t.Fatal("anahtar yokken Google'a istek atıldı")
		}
	})

	t.Run("500m içindeki adayın place_id'si döner", func(t *testing.T) {
		// Sorgu koordinatına ~11m mesafede tek aday: kabul edilmeli.
		s := newTestPlacesService(t, "k", func(w http.ResponseWriter, r *http.Request) {
			if got := r.URL.Query().Get("key"); got != "k" {
				t.Errorf("key parametresi eklenmedi: %q", got)
			}
			io.WriteString(w, `{"status":"OK","candidates":[
				{"place_id":"ChIJyakin","name":"Yakın","geometry":{"location":{"lat":41.00010,"lng":29.0}}}
			]}`)
		})
		if got := s.ResolvePlaceID("Kafe", 41.0, 29.0); got != "ChIJyakin" {
			t.Fatalf("yakın aday seçilmedi: %q", got)
		}
	})

	t.Run("en yakın aday seçilir", func(t *testing.T) {
		// İki aday: ilki uzak (~55m), ikincisi çok yakın (~1m). Fonksiyon
		// listedeki ilk değil, en yakın olanı seçmeli.
		s := newTestPlacesService(t, "k", func(w http.ResponseWriter, _ *http.Request) {
			io.WriteString(w, `{"status":"OK","candidates":[
				{"place_id":"ChIJuzak","name":"Uzak","geometry":{"location":{"lat":41.0005,"lng":29.0}}},
				{"place_id":"ChIJyakin","name":"Yakın","geometry":{"location":{"lat":41.00001,"lng":29.0}}}
			]}`)
		})
		if got := s.ResolvePlaceID("Kafe", 41.0, 29.0); got != "ChIJyakin" {
			t.Fatalf("en yakın aday seçilmedi: %q", got)
		}
	})

	t.Run("500m dışındaki aday reddedilir", func(t *testing.T) {
		// ~1.1km uzakta: güvenlik için reddedilmeli (yanlış mekan eşleşmesini önler).
		s := newTestPlacesService(t, "k", func(w http.ResponseWriter, _ *http.Request) {
			io.WriteString(w, `{"status":"OK","candidates":[
				{"place_id":"ChIJcokuzak","name":"Çok Uzak","geometry":{"location":{"lat":41.01,"lng":29.0}}}
			]}`)
		})
		if got := s.ResolvePlaceID("Kafe", 41.0, 29.0); got != "" {
			t.Fatalf("500m dışı aday kabul edildi: %q", got)
		}
	})

	t.Run("ZERO_RESULTS boş döner", func(t *testing.T) {
		s := newTestPlacesService(t, "k", func(w http.ResponseWriter, _ *http.Request) {
			io.WriteString(w, `{"status":"ZERO_RESULTS","candidates":[]}`)
		})
		if got := s.ResolvePlaceID("Kafe", 41.0, 29.0); got != "" {
			t.Fatalf("sonuç yokken %q döndü", got)
		}
	})

	t.Run("HTTP 500 boş döner (hata yutulur)", func(t *testing.T) {
		s := newTestPlacesService(t, "k", func(w http.ResponseWriter, _ *http.Request) {
			w.WriteHeader(http.StatusInternalServerError)
		})
		if got := s.ResolvePlaceID("Kafe", 41.0, 29.0); got != "" {
			t.Fatalf("500 yanıtında %q döndü", got)
		}
	})
}

// --- GetAddressComponents ---

func TestPlacesServiceGetAddressComponents(t *testing.T) {
	t.Run("anahtar veya place_id boşsa nil döner", func(t *testing.T) {
		s := newTestPlacesService(t, "", func(http.ResponseWriter, *http.Request) {
			t.Error("çağrı yapılmamalıydı")
		})
		got, err := s.GetAddressComponents("ChIJx")
		if err != nil || got != nil {
			t.Fatalf("anahtarsız: got=%v err=%v", got, err)
		}

		s2 := newTestPlacesService(t, "k", func(http.ResponseWriter, *http.Request) {
			t.Error("çağrı yapılmamalıydı")
		})
		got2, err2 := s2.GetAddressComponents("")
		if err2 != nil || got2 != nil {
			t.Fatalf("place_id boş: got=%v err=%v", got2, err2)
		}
	})

	t.Run("Türkiye il/ilçe doğru eşlenir", func(t *testing.T) {
		s := newTestPlacesService(t, "k", func(w http.ResponseWriter, _ *http.Request) {
			io.WriteString(w, `{"status":"OK","result":{
				"name":"Meşhur Kafe",
				"address_components":[
					{"long_name":"İstanbul","types":["administrative_area_level_1"]},
					{"long_name":"Kadıköy","types":["administrative_area_level_2"]}
				],
				"photos":[]
			}}`)
		})
		got, err := s.GetAddressComponents("ChIJx")
		if err != nil {
			t.Fatalf("hata: %v", err)
		}
		if got.Name != "Meşhur Kafe" {
			t.Errorf("name %q", got.Name)
		}
		if got.City != "İstanbul" {
			t.Errorf("city %q, beklenen İstanbul", got.City)
		}
		if got.District != "Kadıköy" {
			t.Errorf("district %q, beklenen Kadıköy", got.District)
		}
	})

	t.Run("locality/sublocality yalnızca il/ilçe boşken kullanılır", func(t *testing.T) {
		// administrative_area_level_1 varken locality onu EZMEMELİ.
		s := newTestPlacesService(t, "k", func(w http.ResponseWriter, _ *http.Request) {
			io.WriteString(w, `{"status":"OK","result":{
				"name":"Kafe",
				"address_components":[
					{"long_name":"İzmir","types":["administrative_area_level_1"]},
					{"long_name":"YanlışŞehir","types":["locality"]},
					{"long_name":"Konak","types":["sublocality_level_1"]}
				],
				"photos":[]
			}}`)
		})
		got, err := s.GetAddressComponents("ChIJx")
		if err != nil {
			t.Fatalf("hata: %v", err)
		}
		if got.City != "İzmir" {
			t.Errorf("locality admin_area_level_1'i ezdi: %q", got.City)
		}
		if got.District != "Konak" {
			t.Errorf("sublocality ilçe olarak alınmadı: %q", got.District)
		}
	})

	t.Run("en fazla 5 fotoğraf referansı alınır", func(t *testing.T) {
		s := newTestPlacesService(t, "k", func(w http.ResponseWriter, _ *http.Request) {
			io.WriteString(w, `{"status":"OK","result":{
				"name":"Kafe",
				"address_components":[],
				"photos":[
					{"photo_reference":"r1"},{"photo_reference":"r2"},{"photo_reference":"r3"},
					{"photo_reference":"r4"},{"photo_reference":"r5"},{"photo_reference":"r6"},
					{"photo_reference":"r7"}
				]
			}}`)
		})
		got, err := s.GetAddressComponents("ChIJx")
		if err != nil {
			t.Fatalf("hata: %v", err)
		}
		if len(got.PhotoReferences) != 5 {
			t.Fatalf("foto referans sayısı %d, beklenen 5", len(got.PhotoReferences))
		}
		if got.PhotoReferences[0] != "r1" || got.PhotoReferences[4] != "r5" {
			t.Errorf("ilk 5 referans yanlış: %v", got.PhotoReferences)
		}
	})

	t.Run("status OK değilse hata döner", func(t *testing.T) {
		s := newTestPlacesService(t, "k", func(w http.ResponseWriter, _ *http.Request) {
			io.WriteString(w, `{"status":"NOT_FOUND","result":{}}`)
		})
		if _, err := s.GetAddressComponents("ChIJx"); err == nil {
			t.Fatal("NOT_FOUND'da hata dönmeliydi")
		}
	})

	t.Run("HTTP 403 hata döner", func(t *testing.T) {
		s := newTestPlacesService(t, "k", func(w http.ResponseWriter, _ *http.Request) {
			w.WriteHeader(http.StatusForbidden)
		})
		if _, err := s.GetAddressComponents("ChIJx"); err == nil {
			t.Fatal("403'te hata dönmeliydi")
		}
	})
}

// --- BuildPhotoURL / BuildPhotoURLs ---

func TestPlacesServiceBuildPhotoURL(t *testing.T) {
	s := NewPlacesService("k")

	t.Run("proxy yoluna işaret eder, anahtar sızmaz", func(t *testing.T) {
		got := s.BuildPhotoURL("ref123", 800)
		if !strings.HasPrefix(got, PhotoProxyPath+"?") {
			t.Fatalf("proxy yolu değil: %q", got)
		}
		if strings.Contains(got, "k") && strings.Contains(got, "key=") {
			t.Fatalf("api anahtarı URL'ye sızdı: %q", got)
		}
		u, err := url.Parse(got)
		if err != nil {
			t.Fatalf("geçersiz url: %v", err)
		}
		if u.Query().Get("ref") != "ref123" || u.Query().Get("w") != "800" {
			t.Fatalf("parametreler yanlış: %q", got)
		}
	})

	t.Run("anahtar yoksa veya ref boşsa boş döner", func(t *testing.T) {
		if got := NewPlacesService("").BuildPhotoURL("ref", 800); got != "" {
			t.Fatalf("anahtarsız %q döndü", got)
		}
		if got := s.BuildPhotoURL("", 800); got != "" {
			t.Fatalf("ref boşken %q döndü", got)
		}
	})

	t.Run("BuildPhotoURLs boş referansları atlar", func(t *testing.T) {
		got := s.BuildPhotoURLs([]string{"a", "", "b"}, 400)
		if len(got) != 2 {
			t.Fatalf("beklenen 2 url, alınan %d: %v", len(got), got)
		}
	})
}

// --- calculateDistance ---

func TestPlacesServiceCalculateDistance(t *testing.T) {
	s := NewPlacesService("k")

	t.Run("aynı nokta sıfır mesafe", func(t *testing.T) {
		if d := s.calculateDistance(41.0, 29.0, 41.0, 29.0); d != 0 {
			t.Fatalf("aynı nokta mesafesi %f, beklenen 0", d)
		}
	})

	t.Run("bilinen mesafe makul toleransta", func(t *testing.T) {
		// İstanbul (41.0082, 28.9784) - Ankara (39.9334, 32.8597): ~350 km.
		d := s.calculateDistance(41.0082, 28.9784, 39.9334, 32.8597)
		const wantKm = 350000
		if math.Abs(d-wantKm) > 20000 {
			t.Fatalf("mesafe %f m, ~%d m bekleniyordu", d, wantKm)
		}
	})
}

// --- FetchPhoto ---

func TestPlacesServiceFetchPhoto(t *testing.T) {
	t.Run("anahtar veya ref yoksa hata", func(t *testing.T) {
		if _, _, err := NewPlacesService("").FetchPhoto(context.Background(), "ref", 800); err == nil {
			t.Fatal("anahtarsız hata dönmeliydi")
		}
		s := newTestPlacesService(t, "k", func(http.ResponseWriter, *http.Request) {})
		if _, _, err := s.FetchPhoto(context.Background(), "", 800); err == nil {
			t.Fatal("ref boşken hata dönmeliydi")
		}
	})

	t.Run("başarılı indirme gövde ve content-type döner", func(t *testing.T) {
		s := newTestPlacesService(t, "k", func(w http.ResponseWriter, r *http.Request) {
			if r.URL.Query().Get("key") != "k" {
				t.Error("key sunucu tarafında eklenmedi")
			}
			w.Header().Set("Content-Type", "image/jpeg")
			io.WriteString(w, "JPEGDATA")
		})
		body, ct, err := s.FetchPhoto(context.Background(), "ref", 800)
		if err != nil {
			t.Fatalf("hata: %v", err)
		}
		defer body.Close()
		if ct != "image/jpeg" {
			t.Errorf("content-type %q", ct)
		}
		data, _ := io.ReadAll(body)
		if string(data) != "JPEGDATA" {
			t.Errorf("gövde %q", data)
		}
	})

	t.Run("Google 4xx hata döner", func(t *testing.T) {
		s := newTestPlacesService(t, "k", func(w http.ResponseWriter, _ *http.Request) {
			w.WriteHeader(http.StatusForbidden)
		})
		if _, _, err := s.FetchPhoto(context.Background(), "ref", 800); err == nil {
			t.Fatal("403'te hata dönmeliydi")
		}
	})
}
