package middleware

import (
	"sync"
	"time"

	"github.com/gofiber/fiber/v2"
)

type rateLimiter struct {
	mu     sync.Mutex
	counts map[string][]time.Time
	limit  int
	window time.Duration
}

func newRateLimiter(limit int, window time.Duration) *rateLimiter {
	return &rateLimiter{
		counts: make(map[string][]time.Time),
		limit:  limit,
		window: window,
	}
}

// saatte max 10 mekan ekleme
var guideSubmitLimiter = newRateLimiter(10, time.Hour)

// GuideSubmitLimit — Guide'ların mekan spam eklemesini önler.
// Auth middleware'den sonra kullanılmalıdır.
func GuideSubmitLimit() fiber.Handler {
	return func(c *fiber.Ctx) error {
		userID, ok := c.Locals("userID").(string)
		if !ok {
			return fiber.ErrUnauthorized
		}

		guideSubmitLimiter.mu.Lock()
		defer guideSubmitLimiter.mu.Unlock()

		now := time.Now()
		windowStart := now.Add(-guideSubmitLimiter.window)

		// Pencere dışındaki eski kayıtları temizle
		times := guideSubmitLimiter.counts[userID]
		valid := times[:0]
		for _, t := range times {
			if t.After(windowStart) {
				valid = append(valid, t)
			}
		}

		if len(valid) >= guideSubmitLimiter.limit {
			return c.Status(fiber.StatusTooManyRequests).JSON(fiber.Map{
				"error": "saatte en fazla 10 mekan ekleyebilirsiniz",
			})
		}

		guideSubmitLimiter.counts[userID] = append(valid, now)
		return c.Next()
	}
}
