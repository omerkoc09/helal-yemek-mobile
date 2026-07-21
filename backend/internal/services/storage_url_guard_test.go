package services

import (
	"errors"
	"testing"
)

func TestValidateRemotePhotoURL(t *testing.T) {
	tests := []struct {
		name    string
		url     string
		wantErr error
	}{
		// İzin verilenler — Places Photo API ve yönlendirildiği CDN.
		{
			name: "Places Photo API — backend'in ürettiği adres",
			url:  "https://maps.googleapis.com/maps/api/place/photo?photo_reference=abc&maxwidth=800&key=k",
		},
		{
			name: "googleusercontent alt alan adı — redirect hedefi",
			url:  "https://lh3.googleusercontent.com/places/xyz",
		},
		{
			name: "farklı googleusercontent alt alanı",
			url:  "https://lh5.googleusercontent.com/p/abc",
		},

		// Şema kontrolü.
		{
			name:    "http — cleartext reddedilmeli",
			url:     "http://maps.googleapis.com/maps/api/place/photo",
			wantErr: ErrPhotoURLScheme,
		},
		{
			name:    "file şeması — yerel dosya okuma girişimi",
			url:     "file:///etc/passwd",
			wantErr: ErrPhotoURLScheme,
		},

		// SSRF hedefleri.
		{
			name:    "cloud metadata servisi",
			url:     "https://169.254.169.254/latest/meta-data/iam/security-credentials/",
			wantErr: ErrPhotoURLHost,
		},
		{
			name:    "iç ağ adresi",
			url:     "https://192.168.1.5:3000/admin",
			wantErr: ErrPhotoURLHost,
		},
		{
			name:    "localhost",
			url:     "https://localhost:5433/",
			wantErr: ErrPhotoURLHost,
		},
		{
			name:    "rastgele dış alan adı",
			url:     "https://evil.example.com/payload",
			wantErr: ErrPhotoURLHost,
		},

		// Allowlist'i delme girişimleri.
		{
			name:    "sahte alt alan — googleusercontent.com.evil.com",
			url:     "https://lh3.googleusercontent.com.evil.com/x",
			wantErr: ErrPhotoURLHost,
		},
		{
			name:    "sonek benzerliği — notgoogleusercontent.com",
			url:     "https://notgoogleusercontent.com/x",
			wantErr: ErrPhotoURLHost,
		},
		{
			name:    "userinfo ile kandırma",
			url:     "https://maps.googleapis.com@evil.example.com/x",
			wantErr: ErrPhotoURLHost,
		},
		{
			name:    "maps.googleapis.com sahte öneki",
			url:     "https://evilmaps.googleapis.com/x",
			wantErr: ErrPhotoURLHost,
		},

		{
			name:    "boş URL",
			url:     "",
			wantErr: ErrPhotoURLScheme,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := validateRemotePhotoURL(tt.url)
			if tt.wantErr == nil {
				if err != nil {
					t.Fatalf("izin verilmeliydi, hata alındı: %v", err)
				}
				return
			}
			if !errors.Is(err, tt.wantErr) {
				t.Fatalf("beklenen %v, alınan %v", tt.wantErr, err)
			}
		})
	}
}
