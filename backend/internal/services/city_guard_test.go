package services

import "testing"

func TestCheckCityAllowed(t *testing.T) {
	ankara := "Ankara"
	istanbul := "İstanbul"

	cases := []struct {
		name        string
		guideCity   *string
		venueCity   string
		wantAllowed bool
		wantResolved string
	}{
		{"guide_city nil → izin", nil, "İstanbul", true, ""},
		{"guide_city boş → izin", strPtr(""), "İstanbul", true, ""},
		{"venue çözülemez → izin", &ankara, "Gotham", true, ""},
		{"venue boş → izin", &ankara, "", true, ""},
		{"aynı il → izin", &istanbul, "İstanbul", true, "İstanbul"},
		{"aynı il türkçe-duyarsız → izin", &istanbul, "istanbul", true, "İstanbul"},
		{"aynı il upper → izin", &istanbul, "ISTANBUL", true, "İstanbul"},
		{"farklı il → red", &ankara, "İstanbul", false, "İstanbul"},
		{"farklı il türkçe-duyarsız → red", &ankara, "istanbul", false, "İstanbul"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			allowed, resolved := CheckCityAllowed(tc.guideCity, tc.venueCity)
			if allowed != tc.wantAllowed || resolved != tc.wantResolved {
				t.Errorf("CheckCityAllowed(%v, %q) = %v,%q; want %v,%q",
					tc.guideCity, tc.venueCity, allowed, resolved, tc.wantAllowed, tc.wantResolved)
			}
		})
	}
}

func strPtr(s string) *string { return &s }
