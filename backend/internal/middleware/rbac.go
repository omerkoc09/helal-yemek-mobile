package middleware

import (
	"github.com/gofiber/fiber/v2"
)

// RequireRole — verilen rollerden birine sahip olmayan kullanıcıyı reddeder.
// Auth middleware'den sonra kullanılmalıdır.
func RequireRole(roles ...string) fiber.Handler {
	roleSet := make(map[string]bool, len(roles))
	for _, r := range roles {
		roleSet[r] = true
	}
	return func(c *fiber.Ctx) error {
		role, ok := c.Locals("userRole").(string)
		if !ok || !roleSet[role] {
			return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
				"error": "bu işlem için yetkiniz yok",
			})
		}
		return c.Next()
	}
}
