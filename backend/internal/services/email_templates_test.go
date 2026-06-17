package services

import (
	"strings"
	"testing"
)

// --- warningEmailHTML ---

func TestWarningEmailHTML_ContainsGuideName(t *testing.T) {
	html := warningEmailHTML("Ahmet", "Köfte Salonu")
	if !strings.Contains(html, "Ahmet") {
		t.Error("uyarı emaili rehber adını içermiyor")
	}
}

func TestWarningEmailHTML_ContainsVenueName(t *testing.T) {
	html := warningEmailHTML("Ahmet", "Köfte Salonu")
	if !strings.Contains(html, "Köfte Salonu") {
		t.Error("uyarı emaili mekan adını içermiyor")
	}
}

func TestWarningEmailHTML_Contains14Days(t *testing.T) {
	html := warningEmailHTML("Ahmet", "Köfte Salonu")
	if !strings.Contains(html, "14 gün") {
		t.Error("uyarı emaili '14 gün' ifadesini içermiyor")
	}
}

func TestWarningEmailHTML_IsValidHTML(t *testing.T) {
	html := warningEmailHTML("Test", "Test Mekan")
	if !strings.HasPrefix(html, "<!DOCTYPE html>") {
		t.Error("email geçerli HTML belgesi değil")
	}
	if !strings.Contains(html, "</html>") {
		t.Error("email kapanış html etiketi içermiyor")
	}
}

func TestWarningEmailHTML_DoesNotLeakOtherGuideName(t *testing.T) {
	// Başka bir rehberin adı şablona sızmamalı
	html := warningEmailHTML("Mehmet", "Lokanta")
	if strings.Contains(html, "Ahmet") {
		t.Error("email başka rehberin adını içeriyor")
	}
}

// --- suspensionEmailHTML ---

func TestSuspensionEmailHTML_ContainsGuideName(t *testing.T) {
	html := suspensionEmailHTML("Fatma", "Pide Fırını")
	if !strings.Contains(html, "Fatma") {
		t.Error("askıya alma emaili rehber adını içermiyor")
	}
}

func TestSuspensionEmailHTML_ContainsVenueName(t *testing.T) {
	html := suspensionEmailHTML("Fatma", "Pide Fırını")
	if !strings.Contains(html, "Pide Fırını") {
		t.Error("askıya alma emaili mekan adını içermiyor")
	}
}

func TestSuspensionEmailHTML_ContainsSuspendedMessage(t *testing.T) {
	html := suspensionEmailHTML("Fatma", "Pide Fırını")
	if !strings.Contains(html, "askıya alınmıştır") {
		t.Error("askıya alma emaili 'askıya alınmıştır' ifadesini içermiyor")
	}
}

func TestSuspensionEmailHTML_ContainsReactivationHint(t *testing.T) {
	// Rehbere mekanı nasıl geri açacağını söylenmeli
	html := suspensionEmailHTML("Fatma", "Pide Fırını")
	if !strings.Contains(html, "doğrulamayı") && !strings.Contains(html, "doğrulama") {
		t.Error("askıya alma emaili yeniden aktifleştirme talimatı içermiyor")
	}
}

func TestSuspensionEmailHTML_IsValidHTML(t *testing.T) {
	html := suspensionEmailHTML("Test", "Test Mekan")
	if !strings.HasPrefix(html, "<!DOCTYPE html>") {
		t.Error("email geçerli HTML belgesi değil")
	}
}
