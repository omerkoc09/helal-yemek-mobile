package jwt

import (
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

const testSecret = "test-secret-key-for-testing"

func TestGenerateTokenPair(t *testing.T) {
	pair, err := GenerateTokenPair("user-123", "test@example.com", "traveler", testSecret)
	if err != nil {
		t.Fatalf("GenerateTokenPair hatası: %v", err)
	}
	if pair.AccessToken == "" {
		t.Fatal("AccessToken boş olmamalı")
	}
	if pair.RefreshToken == "" {
		t.Fatal("RefreshToken boş olmamalı")
	}
	if pair.AccessToken == pair.RefreshToken {
		t.Fatal("AccessToken ve RefreshToken farklı olmalı")
	}
}

func TestParseAccessToken_Valid(t *testing.T) {
	pair, err := GenerateTokenPair("user-123", "test@example.com", "guide", testSecret)
	if err != nil {
		t.Fatalf("token üretme hatası: %v", err)
	}

	claims, err := ParseAccessToken(pair.AccessToken, testSecret)
	if err != nil {
		t.Fatalf("ParseAccessToken hatası: %v", err)
	}

	if claims.UserID != "user-123" {
		t.Errorf("UserID beklenen: user-123, gelen: %s", claims.UserID)
	}
	if claims.Email != "test@example.com" {
		t.Errorf("Email beklenen: test@example.com, gelen: %s", claims.Email)
	}
	if claims.Role != "guide" {
		t.Errorf("Role beklenen: guide, gelen: %s", claims.Role)
	}
}

func TestParseAccessToken_WrongSecret(t *testing.T) {
	pair, err := GenerateTokenPair("user-123", "test@example.com", "traveler", testSecret)
	if err != nil {
		t.Fatalf("token üretme hatası: %v", err)
	}

	_, err = ParseAccessToken(pair.AccessToken, "wrong-secret")
	if err == nil {
		t.Fatal("yanlış secret ile parse başarılı olmamalıydı")
	}
}

func TestParseAccessToken_Expired(t *testing.T) {
	// Manuel olarak süresi dolmuş token oluştur
	claims := Claims{
		UserID: "user-123",
		Email:  "test@example.com",
		Role:   "traveler",
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   "user-123",
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(-1 * time.Hour)),
			IssuedAt:  jwt.NewNumericDate(time.Now().Add(-2 * time.Hour)),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenStr, err := token.SignedString([]byte(testSecret))
	if err != nil {
		t.Fatalf("token imzalama hatası: %v", err)
	}

	_, err = ParseAccessToken(tokenStr, testSecret)
	if err == nil {
		t.Fatal("süresi dolmuş token ile parse başarılı olmamalıydı")
	}
}

func TestParseRefreshToken_Valid(t *testing.T) {
	pair, err := GenerateTokenPair("user-456", "refresh@example.com", "admin", testSecret)
	if err != nil {
		t.Fatalf("token üretme hatası: %v", err)
	}

	userID, err := ParseRefreshToken(pair.RefreshToken, testSecret)
	if err != nil {
		t.Fatalf("ParseRefreshToken hatası: %v", err)
	}

	if userID != "user-456" {
		t.Errorf("UserID beklenen: user-456, gelen: %s", userID)
	}
}

func TestParseRefreshToken_WrongSecret(t *testing.T) {
	pair, err := GenerateTokenPair("user-456", "test@example.com", "traveler", testSecret)
	if err != nil {
		t.Fatalf("token üretme hatası: %v", err)
	}

	_, err = ParseRefreshToken(pair.RefreshToken, "wrong-secret")
	if err == nil {
		t.Fatal("yanlış secret ile refresh parse başarılı olmamalıydı")
	}
}

func TestParseRefreshToken_Expired(t *testing.T) {
	claims := jwt.RegisteredClaims{
		Subject:   "user-456",
		ExpiresAt: jwt.NewNumericDate(time.Now().Add(-1 * time.Hour)),
		IssuedAt:  jwt.NewNumericDate(time.Now().Add(-2 * time.Hour)),
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenStr, err := token.SignedString([]byte(testSecret))
	if err != nil {
		t.Fatalf("token imzalama hatası: %v", err)
	}

	_, err = ParseRefreshToken(tokenStr, testSecret)
	if err == nil {
		t.Fatal("süresi dolmuş refresh token ile parse başarılı olmamalıydı")
	}
}

func TestAccessTokenExpiry(t *testing.T) {
	pair, err := GenerateTokenPair("user-123", "test@example.com", "traveler", testSecret)
	if err != nil {
		t.Fatalf("token üretme hatası: %v", err)
	}

	claims, err := ParseAccessToken(pair.AccessToken, testSecret)
	if err != nil {
		t.Fatalf("parse hatası: %v", err)
	}

	expiry := claims.ExpiresAt.Time
	expectedExpiry := time.Now().Add(15 * time.Minute)
	diff := expectedExpiry.Sub(expiry).Abs()

	if diff > 5*time.Second {
		t.Errorf("Access token süresi ~15 dakika olmalı, fark: %v", diff)
	}
}

func TestRefreshTokenExpiry(t *testing.T) {
	pair, err := GenerateTokenPair("user-123", "test@example.com", "traveler", testSecret)
	if err != nil {
		t.Fatalf("token üretme hatası: %v", err)
	}

	// Refresh token'ı parse edip süresini kontrol et
	token, err := jwt.ParseWithClaims(pair.RefreshToken, &jwt.RegisteredClaims{}, func(t *jwt.Token) (interface{}, error) {
		return []byte(testSecret), nil
	})
	if err != nil {
		t.Fatalf("parse hatası: %v", err)
	}

	claims := token.Claims.(*jwt.RegisteredClaims)
	expiry := claims.ExpiresAt.Time
	expectedExpiry := time.Now().Add(30 * 24 * time.Hour)
	diff := expectedExpiry.Sub(expiry).Abs()

	if diff > 5*time.Second {
		t.Errorf("Refresh token süresi ~30 gün olmalı, fark: %v", diff)
	}
}

func TestParseAccessToken_InvalidSigningMethod(t *testing.T) {
	// None signing method ile token oluştur
	claims := Claims{
		UserID: "hacker",
		Email:  "hacker@evil.com",
		Role:   "admin",
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   "hacker",
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(1 * time.Hour)),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodNone, claims)
	tokenStr, _ := token.SignedString(jwt.UnsafeAllowNoneSignatureType)

	_, err := ParseAccessToken(tokenStr, testSecret)
	if err == nil {
		t.Fatal("'none' signing method kabul edilmemeli")
	}
}

func TestDifferentRoles(t *testing.T) {
	roles := []string{"traveler", "guide", "admin"}
	for _, role := range roles {
		pair, err := GenerateTokenPair("user-1", "u@test.com", role, testSecret)
		if err != nil {
			t.Fatalf("role=%s token üretme hatası: %v", role, err)
		}

		claims, err := ParseAccessToken(pair.AccessToken, testSecret)
		if err != nil {
			t.Fatalf("role=%s parse hatası: %v", role, err)
		}

		if claims.Role != role {
			t.Errorf("role beklenen: %s, gelen: %s", role, claims.Role)
		}
	}
}

// TestTokenTypesAreNotInterchangeable — access ve refresh token'lar birbirinin
// yerine geçmemeli.
//
// İkisi de aynı secret ve algoritmayla imzalanıp Subject'e kullanıcı id'si
// koyduğu için, tip claim'i olmadan ayırt edilemezler. En tehlikeli yön
// access -> refresh: access token her istekte gönderildiği için sızma olasılığı
// yüksektir ve 15 dakikalık ömrü, 30 günlük refresh token'a çevrilebilseydi
// kalıcı erişime dönüşürdü.
func TestTokenTypesAreNotInterchangeable(t *testing.T) {
	pair, err := GenerateTokenPair("user-1", "a@b.com", "traveler", testSecret)
	if err != nil {
		t.Fatalf("token üretme hatası: %v", err)
	}

	t.Run("access token refresh olarak kullanılamaz", func(t *testing.T) {
		if _, err := ParseRefreshToken(pair.AccessToken, testSecret); err == nil {
			t.Fatal("access token refresh olarak kabul edildi")
		}
	})

	t.Run("refresh token access olarak kullanılamaz", func(t *testing.T) {
		if _, err := ParseAccessToken(pair.RefreshToken, testSecret); err == nil {
			t.Fatal("refresh token access olarak kabul edildi")
		}
	})

	t.Run("her token kendi tipinde çalışır", func(t *testing.T) {
		if _, err := ParseAccessToken(pair.AccessToken, testSecret); err != nil {
			t.Fatalf("access token kendi tipinde parse edilemedi: %v", err)
		}
		uid, err := ParseRefreshToken(pair.RefreshToken, testSecret)
		if err != nil {
			t.Fatalf("refresh token kendi tipinde parse edilemedi: %v", err)
		}
		if uid != "user-1" {
			t.Fatalf("userID %q, beklenen user-1", uid)
		}
	})

	// typ claim'i hiç olmayan eski token'lar da reddedilmeli.
	t.Run("tipsiz eski token reddedilir", func(t *testing.T) {
		old := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.RegisteredClaims{
			Subject:   "user-1",
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Hour)),
		})
		str, err := old.SignedString([]byte(testSecret))
		if err != nil {
			t.Fatalf("token imzalanamadı: %v", err)
		}
		if _, err := ParseRefreshToken(str, testSecret); err == nil {
			t.Fatal("tipsiz token kabul edildi")
		}
	})
}
