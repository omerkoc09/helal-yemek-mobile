package handlers

import "github.com/gofiber/fiber/v2"

// getUserID — context'ten kullanıcı ID'sini güvenli şekilde çıkarır.
// Middleware userID set etmemişse veya tip uyumsuzsa hata döner.
func getUserID(c *fiber.Ctx) (string, error) {
	id, ok := c.Locals("userID").(string)
	if !ok || id == "" {
		return "", fiber.ErrUnauthorized
	}
	return id, nil
}

// getUserRole — context'ten kullanıcı rolünü güvenli şekilde çıkarır.
// Rol yoksa boş string döner (hata dönmez, çünkü bazı endpoint'lerde opsiyonel).
func getUserRole(c *fiber.Ctx) string {
	role, _ := c.Locals("userRole").(string)
	return role
}
