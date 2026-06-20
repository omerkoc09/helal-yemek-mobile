package models

import "testing"

func TestTurkishCitiesCount(t *testing.T) {
	if len(TurkishCities) != 81 {
		t.Fatalf("81 il bekleniyor, %d bulundu", len(TurkishCities))
	}
}

func TestIsValidCity(t *testing.T) {
	if !IsValidCity("İstanbul") {
		t.Error("İstanbul geçerli olmalı")
	}
	if IsValidCity("Gotham") {
		t.Error("Gotham geçersiz olmalı")
	}
}

func TestNormalizeCity(t *testing.T) {
	cases := map[string]string{
		"istanbul": "İstanbul",
		"ISTANBUL": "İstanbul",
		" ankara ": "Ankara",
		"ANKARA":   "Ankara",
		"izmir":    "İzmir",
	}
	for in, want := range cases {
		got, ok := NormalizeCity(in)
		if !ok || got != want {
			t.Errorf("NormalizeCity(%q) = %q,%v; want %q,true", in, got, ok, want)
		}
	}
	if _, ok := NormalizeCity("Paris"); ok {
		t.Error("Paris eşleşmemeli")
	}
}
