package config

import (
	"errors"
	"strings"
	"testing"
)

func TestValidate(t *testing.T) {
	const validSecret = "0123456789abcdef0123456789abcdef" // 32 karakter
	const validDB = "postgres://u:p@localhost:5432/db"

	tests := []struct {
		name    string
		cfg     Config
		wantErr error
	}{
		{
			name: "geçerli config",
			cfg:  Config{JWTSecret: validSecret, DatabaseURL: validDB},
		},
		{
			name:    "JWT secret boş — sessizce boş anahtarla imzalanmasın",
			cfg:     Config{JWTSecret: "", DatabaseURL: validDB},
			wantErr: ErrJWTSecretMissing,
		},
		{
			name:    "JWT secret sadece boşluk",
			cfg:     Config{JWTSecret: "   ", DatabaseURL: validDB},
			wantErr: ErrJWTSecretMissing,
		},
		{
			name:    "JWT secret çok kısa — brute-force'a açık",
			cfg:     Config{JWTSecret: strings.Repeat("a", MinJWTSecretLength-1), DatabaseURL: validDB},
			wantErr: ErrJWTSecretTooShort,
		},
		{
			name: "JWT secret tam sınırda — kabul edilmeli",
			cfg:  Config{JWTSecret: strings.Repeat("a", MinJWTSecretLength), DatabaseURL: validDB},
		},
		{
			name:    "DATABASE_URL boş",
			cfg:     Config{JWTSecret: validSecret, DatabaseURL: ""},
			wantErr: ErrDatabaseURLMissing,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.cfg.Validate()
			if tt.wantErr == nil {
				if err != nil {
					t.Fatalf("hata beklenmiyordu, alındı: %v", err)
				}
				return
			}
			if !errors.Is(err, tt.wantErr) {
				t.Fatalf("beklenen hata %v, alınan %v", tt.wantErr, err)
			}
		})
	}
}
