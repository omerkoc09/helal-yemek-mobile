package handlers

import (
	"context"
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/omerkoc/caiz-mi/internal/models"
	"github.com/omerkoc/caiz-mi/internal/repository"
)

// GET /admin/audit-logs
func (h *AdminHandler) ListAuditLogs(c *fiber.Ctx) error {
	list, err := h.auditRepo.List(c.Context())
	if err != nil {
		return fiber.ErrInternalServerError
	}
	return c.JSON(list)
}

// ── Kullanıcılar ──────────────────────────────────────────────────────────────

// GET /admin/venues/:id/verification-logs
func (h *AdminHandler) GetVenueVerificationLogs(c *fiber.Ctx) error {
	id := c.Params("id")
	logs, err := h.verifLogRepo.ListByVenue(c.Context(), id)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "doğrulama geçmişi alınamadı"})
	}
	if logs == nil {
		logs = []*models.VerificationLog{}
	}
	return c.JSON(logs)
}

// GET /admin/verification-logs?tab=verified|suspended|upcoming
func (h *AdminHandler) VerificationLogs(c *fiber.Ctx) error {
	tab := c.Query("tab", "verified")
	switch tab {
	case "verified":
		page := max(c.QueryInt("page", 1), 1)
		logs, err := h.verifLogRepo.ListVerified(c.Context(), 50, (page-1)*50)
		if err != nil {
			return fiber.ErrInternalServerError
		}
		return c.JSON(fiber.Map{"data": logs})
	case "suspended":
		logs, err := h.verifLogRepo.ListSuspended(c.Context())
		if err != nil {
			return fiber.ErrInternalServerError
		}
		return c.JSON(fiber.Map{"data": logs})
	case "upcoming":
		logs, err := h.verifLogRepo.ListUpcoming(c.Context(), 30)
		if err != nil {
			return fiber.ErrInternalServerError
		}
		return c.JSON(fiber.Map{"data": logs})
	case "warnings":
		page := max(c.QueryInt("page", 1), 1)
		logs, err := h.verifLogRepo.ListWarningsSent(c.Context(), 50, (page-1)*50)
		if err != nil {
			return fiber.ErrInternalServerError
		}
		return c.JSON(fiber.Map{"data": logs})
	default:
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "geçersiz tab parametresi"})
	}
}

// GET /admin/venues/by-city — şehir bazlı onaylı mekan sayımı.
func (h *AdminHandler) VenuesByCity(c *fiber.Ctx) error {
	list, err := h.venueRepo.CountApprovedVenuesByCity(c.Context())
	if err != nil {
		return fiber.ErrInternalServerError
	}
	return c.JSON(list)
}

// GET /admin/stats/activity?days=N
func (h *AdminHandler) GetActivityStats(c *fiber.Ctx) error {
	days := 7
	if d, err := strconv.Atoi(c.Query("days", "7")); err == nil && d > 0 && d <= 90 {
		days = d
	}

	now := time.Now().UTC()
	todayStart := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.UTC)
	trendStart := todayStart.AddDate(0, 0, -(days - 1))
	tomorrow := todayStart.AddDate(0, 0, 1)

	todayUsers, err := h.userRepo.CountToday(c.Context(), todayStart, tomorrow)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "istatistikler alınamadı"})
	}
	todayVenues, err := h.venueRepo.CountToday(c.Context(), todayStart, tomorrow)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "istatistikler alınamadı"})
	}

	userDays, err := h.userRepo.CountByDay(c.Context(), trendStart, tomorrow)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "istatistikler alınamadı"})
	}
	venueDays, err := h.venueRepo.CountByDay(c.Context(), trendStart, tomorrow)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "istatistikler alınamadı"})
	}
	loginDays, err := h.loginRepo.CountByDay(c.Context(), trendStart, tomorrow)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "istatistikler alınamadı"})
	}
	directionDays, err := h.directionRepo.CountByDay(c.Context(), trendStart, tomorrow)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "istatistikler alınamadı"})
	}
	topDirectionVenues, err := h.directionRepo.TopVenues(c.Context(), trendStart, tomorrow, 10)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "istatistikler alınamadı"})
	}

	trMonths := []string{"", "Oca", "Şub", "Mar", "Nis", "May", "Haz", "Tem", "Ağu", "Eyl", "Eki", "Kas", "Ara"}

	toMap := func(counts []repository.DayCount) map[string]int {
		m := make(map[string]int, len(counts))
		for _, dc := range counts {
			m[dc.Date] = dc.Count
		}
		return m
	}
	userMap := toMap(userDays)
	venueMap := toMap(venueDays)
	loginMap := toMap(loginDays)
	directionMap := toMap(directionDays)

	todayStr := todayStart.Format("2006-01-02")
	labels := make([]string, days)
	newUsers := make([]int, days)
	newVenues := make([]int, days)
	logins := make([]int, days)
	directionClicks := make([]int, days)

	for i := 0; i < days; i++ {
		d := trendStart.AddDate(0, 0, i)
		key := d.Format("2006-01-02")
		labels[i] = fmt.Sprintf("%d %s", d.Day(), trMonths[d.Month()])
		newUsers[i] = userMap[key]
		newVenues[i] = venueMap[key]
		logins[i] = loginMap[key]
		directionClicks[i] = directionMap[key]
	}

	return c.JSON(fiber.Map{
		"today": fiber.Map{
			"new_users":  todayUsers,
			"new_venues": todayVenues,
			"logins":     loginMap[todayStr],
		},
		"trend": fiber.Map{
			"labels":           labels,
			"new_users":        newUsers,
			"new_venues":       newVenues,
			"logins":           logins,
			"direction_clicks": directionClicks,
		},
		"top_direction_venues": topDirectionVenues,
	})
}

// ── Yemek Kategorileri ───────────────────────────────────────────────────────

// slugifyKey — bir etiketten (label) URL/DB-dostu bir key türetir: küçük harf, boşluklar "_".
func slugifyKey(label string) string {
	return strings.ToLower(strings.ReplaceAll(strings.TrimSpace(label), " ", "_"))
}

// POST /admin/scheduler/run — doğrulama döngüsünü manuel tetikler (test için).
func (h *AdminHandler) RunSchedulerNow(c *fiber.Ctx) error {
	go h.schedulerSvc.RunNow(context.Background())
	return c.JSON(fiber.Map{"status": "started"})
}
