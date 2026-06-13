package services

import "testing"

func TestParseMapsLink_FullURLs(t *testing.T) {
	cases := []struct {
		name      string
		link      string
		wantLat   float64
		wantLng   float64
		wantPID   string
	}{
		{
			// Hex feature ID (0x...) geçerli place_id DEĞİLDİR — boş dönmeli.
			name:    "data format !8m2!3d!4d with hex feature id (rejected)",
			link:    "https://www.google.com/maps/place/Sultanahmet+Camii/@41.0054,28.9768,17z/data=!3m1!4b1!4m6!3m5!1s0x14cab9bf1c0b3f6d:0x123abc!8m2!3d41.0054!4d28.9768",
			wantLat: 41.0054,
			wantLng: 28.9768,
			wantPID: "",
		},
		{
			// ChIJ formatı gerçek place_id — kabul edilir.
			name:    "data format with ChIJ place_id (accepted)",
			link:    "https://www.google.com/maps/place/Cafe/@41.0054,28.9768,17z/data=!4m6!3m5!1sChIJKWPD4-q5yhQR8DWoTvTwknk!8m2!3d41.0054!4d28.9768",
			wantLat: 41.0054,
			wantLng: 28.9768,
			wantPID: "ChIJKWPD4-q5yhQR8DWoTvTwknk",
		},
		{
			name:    "embed !3d!4d",
			link:    "https://www.google.com/maps/embed?pb=!1m18!3d39.9334!4d32.8597",
			wantLat: 39.9334,
			wantLng: 32.8597,
		},
		{
			name:    "camera /@lat,lng",
			link:    "https://www.google.com/maps/@36.8841,30.7056,15z",
			wantLat: 36.8841,
			wantLng: 30.7056,
		},
		{
			name:    "query ?q=lat,lng",
			link:    "https://maps.google.com/?q=38.4192,27.1287",
			wantLat: 38.4192,
			wantLng: 27.1287,
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got, err := ParseMapsLink(tc.link)
			if err != nil {
				t.Fatalf("ParseMapsLink() error = %v", err)
			}
			if got.Latitude != tc.wantLat || got.Longitude != tc.wantLng {
				t.Errorf("coords = (%v, %v), want (%v, %v)", got.Latitude, got.Longitude, tc.wantLat, tc.wantLng)
			}
			if got.PlaceID != tc.wantPID {
				t.Errorf("placeID = %q, want %q", got.PlaceID, tc.wantPID)
			}
		})
	}
}

func TestParseMapsLink_Invalid(t *testing.T) {
	for _, link := range []string{"", "not a link", "https://example.com/foo"} {
		if _, err := ParseMapsLink(link); err == nil {
			t.Errorf("ParseMapsLink(%q) expected error, got nil", link)
		}
	}
}
