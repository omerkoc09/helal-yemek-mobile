package services

import (
	"context"
	"fmt"

	"github.com/MicahParks/keyfunc/v3"
	"github.com/golang-jwt/jwt/v5"
)

const appleJWKSURL = "https://appleid.apple.com/auth/keys"
const appleIssuer = "https://appleid.apple.com"

// AppleClaims — Apple identity token içindeki claim'ler.
type AppleClaims struct {
	Email string `json:"email"`
	jwt.RegisteredClaims
}

// AppleService — Apple JWKS ile token doğrulama işlemlerini yönetir.
type AppleService struct{}

func NewAppleService() *AppleService {
	return &AppleService{}
}

// ValidateToken — Apple'ın identity token'ını JWKS endpoint'inden alınan public key ile doğrular.
func (a *AppleService) ValidateToken(ctx context.Context, identityToken string) (*AppleClaims, error) {
	// Apple'ın JWKS endpoint'inden public key seti al
	jwks, err := keyfunc.NewDefaultCtx(ctx, []string{appleJWKSURL})
	if err != nil {
		return nil, fmt.Errorf("Apple JWKS alınamadı: %w", err)
	}

	claims := &AppleClaims{}
	token, err := jwt.ParseWithClaims(identityToken, claims, jwks.Keyfunc,
		jwt.WithIssuer(appleIssuer),
		jwt.WithValidMethods([]string{"RS256"}),
	)
	if err != nil {
		return nil, fmt.Errorf("Apple token doğrulanamadı: %w", err)
	}
	if !token.Valid {
		return nil, fmt.Errorf("geçersiz Apple token")
	}
	return claims, nil
}
