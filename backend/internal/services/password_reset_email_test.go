package services

import (
	"strings"
	"testing"
)

func TestGenerateResetCode(t *testing.T) {
	t.Run("her zaman 6 haneli ve sadece rakam", func(t *testing.T) {
		for i := 0; i < 200; i++ {
			code, err := generateResetCode()
			if err != nil {
				t.Fatalf("kod üretilemedi: %v", err)
			}
			if len(code) != 6 {
				t.Fatalf("kod 6 haneli değil: %q", code)
			}
			for _, r := range code {
				if r < '0' || r > '9' {
					t.Fatalf("kodda rakam olmayan karakter: %q", code)
				}
			}
		}
	})

	t.Run("ardışık kodlar aynı değil", func(t *testing.T) {
		// Zayıf ama etkili bir sağlamlık kontrolü: sabit dönen bir
		// implementasyonu yakalar.
		seen := make(map[string]bool)
		for i := 0; i < 50; i++ {
			code, err := generateResetCode()
			if err != nil {
				t.Fatalf("kod üretilemedi: %v", err)
			}
			seen[code] = true
		}
		if len(seen) < 40 {
			t.Fatalf("kodlar yeterince değişken değil: %d benzersiz", len(seen))
		}
	})
}

func TestPasswordResetEmailHTML(t *testing.T) {
	t.Run("normal isim, gerekli alanlar mevcut", func(t *testing.T) {
		body := passwordResetEmailHTML("Ayşe", "042317")

		if !strings.Contains(body, "042317") {
			t.Error("gövdede kod yok")
		}
		if !strings.Contains(body, "Ayşe") {
			t.Error("gövdede isim yok")
		}
		if !strings.Contains(body, "15 dakika") {
			t.Error("gövdede geçerlilik süresi yok")
		}
	})

	t.Run("HTML metakarakterleri escape edilir, XSS koruması", func(t *testing.T) {
		// Kötü niyetli isim: script etiketi içeren
		body := passwordResetEmailHTML("<script>alert(1)</script>", "123456")

		// Ham script etiketi olmamalı (XSS açığı)
		if strings.Contains(body, "<script>alert(1)</script>") {
			t.Error("ham script etiketi gövdede mevcut, XSS açığı!")
		}

		// Escape edilmiş hali olmalı
		if !strings.Contains(body, "&lt;script&gt;") {
			t.Error("escape edilmiş script etiketi yok")
		}

		// Kodun (rakamlar) escape edilmemesi gerekir
		if !strings.Contains(body, "123456") {
			t.Error("kod gövdede yok")
		}
	})

	t.Run("Türkçe karakterler escape edilmez", func(t *testing.T) {
		body := passwordResetEmailHTML("Müşterim", "654321")

		// Türkçe karakterler ham olarak kalmalı
		if !strings.Contains(body, "Müşterim") {
			t.Error("Türkçe karakterler yanlışlıkla escape edilmiş")
		}
	})
}
