package services

import (
	"strings"
	"testing"
)

func TestBuildPhotoURLDoesNotLeakAPIKey(t *testing.T) {
	const secret = "AIzaSyGIZLI_ANAHTAR_SIZMAMALI"
	svc := NewPlacesService(secret)

	url := svc.BuildPhotoURL("ref-abc", 800)

	// Asıl güvenlik iddiası: istemciye giden adreste anahtar BULUNMAMALI.
	if strings.Contains(url, secret) {
		t.Fatalf("API anahtarı istemci adresine sızdı: %q", url)
	}
	// Google'a doğrudan işaret etmemeli; kendi proxy'mize gitmeli.
	if strings.Contains(url, "maps.googleapis.com") {
		t.Fatalf("adres hâlâ doğrudan Google'a işaret ediyor: %q", url)
	}
	if !strings.HasPrefix(url, PhotoProxyPath) {
		t.Fatalf("proxy yolu beklenmişti, alınan: %q", url)
	}
	// photo_reference gizli değil, taşınması gerekiyor.
	if !strings.Contains(url, "ref=ref-abc") {
		t.Fatalf("photo_reference adreste yok: %q", url)
	}
	if !strings.Contains(url, "w=800") {
		t.Fatalf("genişlik adreste yok: %q", url)
	}
}

func TestBuildPhotoURLEmptyCases(t *testing.T) {
	t.Run("anahtar yoksa boş döner", func(t *testing.T) {
		if got := NewPlacesService("").BuildPhotoURL("ref", 800); got != "" {
			t.Fatalf("boş beklenmişti, alınan %q", got)
		}
	})

	t.Run("referans yoksa boş döner", func(t *testing.T) {
		if got := NewPlacesService("key").BuildPhotoURL("", 800); got != "" {
			t.Fatalf("boş beklenmişti, alınan %q", got)
		}
	})
}

func TestBuildPhotoURLsSkipsEmpty(t *testing.T) {
	svc := NewPlacesService("key")
	// Boş referanslar listeye girmemeli; istemci kırık adres almasın.
	urls := svc.BuildPhotoURLs([]string{"a", "", "b"}, 400)
	if len(urls) != 2 {
		t.Fatalf("2 adres beklenmişti, alınan %d: %v", len(urls), urls)
	}
	for _, u := range urls {
		if !strings.HasPrefix(u, PhotoProxyPath) {
			t.Fatalf("proxy yolu değil: %q", u)
		}
	}
}

func TestFetchPhotoRejectsInvalidInput(t *testing.T) {
	t.Run("anahtar yoksa hata", func(t *testing.T) {
		if _, _, err := NewPlacesService("").FetchPhoto(t.Context(), "ref", 800); err == nil {
			t.Fatal("hata beklenmişti")
		}
	})

	t.Run("referans boşsa hata", func(t *testing.T) {
		if _, _, err := NewPlacesService("key").FetchPhoto(t.Context(), "", 800); err == nil {
			t.Fatal("hata beklenmişti")
		}
	})
}
