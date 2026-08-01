package handlers

import (
	"strings"
	"testing"
)

// resolveGooglePhotoURLs — mekan oluştururken indirilecek Google fotoğraflarını
// belirler. Sıra anlamlıdır: İLK URL kapak (IsPrimary) olur.
func TestResolveGooglePhotoURLs(t *testing.T) {
	t.Run("çoklu seçimde sıra korunur", func(t *testing.T) {
		got := resolveGooglePhotoURLs([]string{"a", "b"}, "")
		if len(got) != 2 || got[0] != "a" || got[1] != "b" {
			t.Fatalf("sıra bozuldu: %v", got)
		}
	})

	t.Run("eski istemcinin tekil alanı desteklenir", func(t *testing.T) {
		// Yayındaki eski sürümler hâlâ google_photo_url gönderiyor; bu alan
		// yok sayılırsa o istemcilerde fotoğraf sessizce kaybolur.
		got := resolveGooglePhotoURLs(nil, "tek")
		if len(got) != 1 || got[0] != "tek" {
			t.Fatalf("eski alan yok sayıldı: %v", got)
		}
	})

	t.Run("çoklu alan varsa eski alan yok sayılır", func(t *testing.T) {
		got := resolveGooglePhotoURLs([]string{"yeni"}, "eski")
		if len(got) != 1 || got[0] != "yeni" {
			t.Fatalf("beklenen [yeni], alınan %v", got)
		}
	})

	t.Run("üst sınır uygulanır", func(t *testing.T) {
		// Sınır bilinçli küçük: Places içeriğini depolamak ToS gri alanı,
		// yüzey dar tutuluyor.
		many := make([]string, maxGooglePhotosPerVenue+3)
		for i := range many {
			many[i] = strings.Repeat("u", i+1)
		}

		got := resolveGooglePhotoURLs(many, "")
		if len(got) != maxGooglePhotosPerVenue {
			t.Fatalf("beklenen %d, alınan %d", maxGooglePhotosPerVenue, len(got))
		}
		// Sınır uygulanırken BAŞTAN alınmalı — kapak seçimi korunur.
		if got[0] != many[0] {
			t.Fatalf("kapak değişti: %q", got[0])
		}
	})

	t.Run("boş ve tekrar eden değerler ayıklanır", func(t *testing.T) {
		got := resolveGooglePhotoURLs([]string{"a", "", "a", "b"}, "")
		if len(got) != 2 || got[0] != "a" || got[1] != "b" {
			t.Fatalf("beklenen [a b], alınan %v", got)
		}
	})

	t.Run("hiç fotoğraf yoksa boş liste", func(t *testing.T) {
		got := resolveGooglePhotoURLs(nil, "")
		if len(got) != 0 {
			t.Fatalf("beklenen boş, alınan %v", got)
		}
	})
}
