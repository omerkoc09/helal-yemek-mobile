package jwt

import (
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// Token tipleri. Bu ayrım olmadan access ve refresh token'lar birbirinin yerine
// kullanılabilir: ikisi de aynı secret ve algoritmayla imzalanıp Subject'e
// kullanıcı id'si koyduğu için ayırt edilemezler.
//
// Access token her istekte gönderildiği için (log, proxy, hata raporu) sızma
// olasılığı yüksektir ve ömrü bilinçli olarak 15 dakikadır. Tip doğrulaması
// olmasaydı sızan bir access token /auth/refresh'e verilip 30 günlük taze
// refresh token'a çevrilebilir, kısa pencere kalıcı erişime dönüşürdü.
const (
	TokenTypeAccess  = "access"
	TokenTypeRefresh = "refresh"
)

// ErrWrongTokenType — token geçerli ama beklenen tipte değil.
var ErrWrongTokenType = errors.New("beklenmeyen token tipi")

type Claims struct {
	UserID string `json:"uid"`
	Email  string `json:"email"`
	Role   string `json:"role"`
	Type   string `json:"typ"`
	jwt.RegisteredClaims
}

// refreshTokenClaims — refresh token kasıtlı olarak minimal tutuluyor:
// yalnızca kim olduğu ve tipi. Email/rol gibi bilgiler taşınmıyor çünkü JWT
// içeriği okunabilir ve refresh token uzun ömürlü.
type refreshTokenClaims struct {
	Type string `json:"typ"`
	jwt.RegisteredClaims
}

type TokenPair struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
}

func GenerateTokenPair(userID, email, role, secret string) (*TokenPair, error) {
	accessClaims := Claims{
		UserID: userID,
		Email:  email,
		Role:   role,
		Type:   TokenTypeAccess,
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   userID,
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(15 * time.Minute)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}
	accessToken := jwt.NewWithClaims(jwt.SigningMethodHS256, accessClaims)
	accessStr, err := accessToken.SignedString([]byte(secret))
	if err != nil {
		return nil, err
	}

	refreshClaims := refreshTokenClaims{
		Type: TokenTypeRefresh,
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   userID,
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(30 * 24 * time.Hour)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}
	refreshToken := jwt.NewWithClaims(jwt.SigningMethodHS256, refreshClaims)
	refreshStr, err := refreshToken.SignedString([]byte(secret))
	if err != nil {
		return nil, err
	}

	return &TokenPair{AccessToken: accessStr, RefreshToken: refreshStr}, nil
}

func ParseAccessToken(tokenStr, secret string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenStr, &Claims{}, func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, jwt.ErrSignatureInvalid
		}
		return []byte(secret), nil
	})
	if err != nil {
		return nil, err
	}
	claims, ok := token.Claims.(*Claims)
	if !ok || !token.Valid {
		return nil, jwt.ErrTokenInvalidClaims
	}
	// Refresh token'ın access token yerine geçmesini engeller.
	if claims.Type != TokenTypeAccess {
		return nil, ErrWrongTokenType
	}
	return claims, nil
}

func ParseRefreshToken(tokenStr, secret string) (userID string, err error) {
	token, err := jwt.ParseWithClaims(tokenStr, &refreshTokenClaims{}, func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, jwt.ErrSignatureInvalid
		}
		return []byte(secret), nil
	})
	if err != nil {
		return "", err
	}
	claims, ok := token.Claims.(*refreshTokenClaims)
	if !ok || !token.Valid {
		return "", jwt.ErrTokenInvalidClaims
	}
	// Sızması çok daha olası olan access token'ın uzun ömürlü refresh token'a
	// çevrilmesini engeller.
	if claims.Type != TokenTypeRefresh {
		return "", ErrWrongTokenType
	}
	return claims.Subject, nil
}
