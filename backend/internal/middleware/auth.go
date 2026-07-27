package middleware

import (
	"strings"

	"github.com/gofiber/fiber/v2"
	jwtpkg "github.com/omerkoc/itimat-mobile/pkg/jwt"
)

// Auth — Bearer token'ı doğrular, geçerliyse user bilgilerini context'e yazar.
func Auth(jwtSecret string) fiber.Handler {
	return func(c *fiber.Ctx) error {
		header := c.Get("Authorization")
		if !strings.HasPrefix(header, "Bearer ") {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"error": "yetkilendirme başlığı eksik",
			})
		}
		tokenStr := strings.TrimPrefix(header, "Bearer ")
		claims, err := jwtpkg.ParseAccessToken(tokenStr, jwtSecret)
		if err != nil {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"error": "geçersiz veya süresi dolmuş token",
			})
		}
		c.Locals("userID", claims.UserID)
		c.Locals("userRole", claims.Role)
		c.Locals("userEmail", claims.Email)
		return c.Next()
	}
}

// OptionalAuth — Token varsa doğrular ama zorunlu değil (public endpoint'ler için).
func OptionalAuth(jwtSecret string) fiber.Handler {
	return func(c *fiber.Ctx) error {
		header := c.Get("Authorization")
		if strings.HasPrefix(header, "Bearer ") {
			tokenStr := strings.TrimPrefix(header, "Bearer ")
			if claims, err := jwtpkg.ParseAccessToken(tokenStr, jwtSecret); err == nil {
				c.Locals("userID", claims.UserID)
				c.Locals("userRole", claims.Role)
				c.Locals("userEmail", claims.Email)
			}
		}
		return c.Next()
	}
}
