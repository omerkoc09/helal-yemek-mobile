package handlers

import (
	"context"
	"errors"
	"log"
	"strings"

	"github.com/gofiber/fiber/v2"
	"github.com/omerkoc/caiz-mi/internal/models"
	"github.com/omerkoc/caiz-mi/internal/repository"
	"github.com/omerkoc/caiz-mi/internal/services"
)

type SchedulerRunner interface {
	RunNow(ctx context.Context)
}

type AdminHandler struct {
	venueRepo              *repository.VenueRepo
	guideRepo              *repository.GuideRepo
	userRepo               *repository.UserRepo
	auditRepo              *repository.AuditRepo
	verifLogRepo           *repository.VerificationLogRepo
	schedulerSvc           SchedulerRunner
	verificationPeriodDays int
}

func NewAdminHandler(
	venueRepo *repository.VenueRepo,
	guideRepo *repository.GuideRepo,
	userRepo *repository.UserRepo,
	auditRepo *repository.AuditRepo,
	verifLogRepo *repository.VerificationLogRepo,
	schedulerSvc SchedulerRunner,
	verificationPeriodDays int,
) *AdminHandler {
	return &AdminHandler{
		venueRepo:              venueRepo,
		guideRepo:              guideRepo,
		userRepo:               userRepo,
		auditRepo:              auditRepo,
		verifLogRepo:           verifLogRepo,
		schedulerSvc:           schedulerSvc,
		verificationPeriodDays: verificationPeriodDays,
	}
}

// writeAuditLog — audit kaydını yazar; hata olsa da isteği bloklamaz, sadece loglar.
func (h *AdminHandler) writeAuditLog(c *fiber.Ctx, action, targetType, targetID string, note *string) {
	adminID, _ := getUserID(c)
	if adminID == "" {
		return
	}
	l := &models.AuditLog{
		AdminID:    adminID,
		Action:     action,
		TargetType: targetType,
		TargetID:   targetID,
		Note:       note,
	}
	_ = h.auditRepo.Create(c.Context(), l)
}

// ── Venue ────────────────────────────────────────────────────────────────────

// GET /admin/venues
func (h *AdminHandler) ListAllVenues(c *fiber.Ctx) error {
	venues, err := h.venueRepo.FindAll(c.Context())
	if err != nil {
		log.Printf("[ADMIN] ListAllVenues error: %v", err)
		return fiber.ErrInternalServerError
	}
	return c.JSON(venues)
}

// DELETE /admin/venues/:id
func (h *AdminHandler) DeleteVenue(c *fiber.Ctx) error {
	id := c.Params("id")
	if err := h.venueRepo.SoftDelete(c.Context(), id); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return fiber.ErrNotFound
		}
		return fiber.ErrInternalServerError
	}
	h.writeAuditLog(c, "delete_venue", "venue", id, nil)
	return c.JSON(fiber.Map{"status": "deleted"})
}

// PUT /admin/venues/:id
func (h *AdminHandler) UpdateVenue(c *fiber.Ctx) error {
	venueID := c.Params("id")
	log.Printf("[ADMIN] UpdateVenue called for id=%s", venueID)

	var req struct {
		Name             *string   `json:"name"`
		City             *string   `json:"city"`
		District         *string   `json:"district"`
		Status           *string   `json:"status"`
		Notes            *string   `json:"notes"`
		FoodHalalMode    *string   `json:"food_halal_mode"`
		CriteriaIDs      *[]int    `json:"criteria_ids"`
		FoodItemIDs      *[]int    `json:"food_item_ids"`
		ExcludedProducts *[]string `json:"excluded_products"`
		MapsLink         *string   `json:"maps_link"`
		Latitude         *float64  `json:"latitude"`
		Longitude        *float64  `json:"longitude"`
		GooglePlaceID    *string   `json:"google_place_id"`
	}
	if err := c.BodyParser(&req); err != nil {
		log.Printf("[ADMIN] UpdateVenue body parse error: %v", err)
		return fiber.ErrBadRequest
	}

	// Mevcut mekanı al — status karşılaştırması ve var olma kontrolü için.
	current, err := h.venueRepo.FindByID(c.Context(), venueID)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return fiber.ErrNotFound
		}
		return fiber.ErrInternalServerError
	}

	// Konum belirleme: öncelik maps_link (parse edilir); yoksa önizleme-onay
	// akışından gelen doğrudan koordinat + place_id kullanılır.
	var lat, lng *float64
	var googlePlaceID *string
	switch {
	case req.MapsLink != nil && strings.TrimSpace(*req.MapsLink) != "":
		coords, err := services.ParseMapsLink(*req.MapsLink)
		if err != nil {
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
				"error": "Google Maps linki çözümlenemedi. Lütfen geçerli bir konum linki yapıştırın.",
			})
		}
		lat = &coords.Latitude
		lng = &coords.Longitude
		if coords.PlaceID != "" {
			googlePlaceID = &coords.PlaceID
		}
	case req.Latitude != nil && req.Longitude != nil:
		lat = req.Latitude
		lng = req.Longitude
		googlePlaceID = req.GooglePlaceID // nil ise repo place_id'yi temizler (konum değişimiyle)
	}

	if err := h.venueRepo.UpdateVenue(c.Context(), venueID, req.Name, req.City,
		req.District, lat, lng, req.Notes, googlePlaceID); err != nil {
		log.Printf("[ADMIN] UpdateVenue repo error for id=%s: %v", venueID, err)
		if errors.Is(err, repository.ErrNotFound) {
			return fiber.ErrNotFound
		}
		if errors.Is(err, repository.ErrAlreadyExists) {
			return c.Status(fiber.StatusConflict).JSON(fiber.Map{
				"error": "Bu Google konumu başka bir mekana ait. Farklı bir konum seçin.",
			})
		}
		return fiber.ErrInternalServerError
	}

	// Helal kriterleri
	if req.CriteriaIDs != nil {
		if err := h.venueRepo.SetCriteria(c.Context(), venueID, *req.CriteriaIDs); err != nil {
			log.Printf("[ADMIN] UpdateVenue SetCriteria error for id=%s: %v", venueID, err)
			return fiber.ErrInternalServerError
		}
	}

	// Yemek çeşitleri
	if req.FoodItemIDs != nil {
		if err := h.venueRepo.SetVenueFoodItems(c.Context(), venueID, *req.FoodItemIDs); err != nil {
			log.Printf("[ADMIN] UpdateVenue SetVenueFoodItems error for id=%s: %v", venueID, err)
			return fiber.ErrInternalServerError
		}
	}

	// Helal modu (whitelist/blacklist vb.)
	if req.FoodHalalMode != nil {
		if err := h.venueRepo.SetFoodHalalMode(c.Context(), venueID, *req.FoodHalalMode); err != nil {
			log.Printf("[ADMIN] UpdateVenue SetFoodHalalMode error for id=%s: %v", venueID, err)
			return fiber.ErrInternalServerError
		}
	}

	// Sakıncalı ürünler
	if req.ExcludedProducts != nil {
		if err := h.venueRepo.SetExcludedProducts(c.Context(), venueID, *req.ExcludedProducts); err != nil {
			log.Printf("[ADMIN] UpdateVenue SetExcludedProducts error for id=%s: %v", venueID, err)
			return fiber.ErrInternalServerError
		}
	}

	// Status değişikliği — yalnızca gönderilen durum mevcut durumdan farklıysa
	// uygula. Admin modalı tam yetkili olduğundan SetStatus kaynak duruma
	// bakmadan hedef duruma geçer ve yan-etki sütunlarını tutarlı tutar.
	if req.Status != nil && *req.Status != string(current.Status) {
		newStatus := models.VenueStatus(*req.Status)
		switch newStatus {
		case models.VenueStatusApproved, models.VenueStatusRejected,
			models.VenueStatusPending, models.VenueStatusSuspended:
		default:
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "geçersiz durum değeri"})
		}

		adminID, err := getUserID(c)
		if err != nil {
			return err
		}
		if statusErr := h.venueRepo.SetStatus(c.Context(), venueID, newStatus, adminID, nil, h.verificationPeriodDays); statusErr != nil {
			log.Printf("[ADMIN] UpdateVenue status change error for id=%s: %v", venueID, statusErr)
			return fiber.ErrInternalServerError
		}
	}

	h.writeAuditLog(c, "update_venue", "venue", venueID, nil)
	venue, err := h.venueRepo.FindByID(c.Context(), venueID)
	if err != nil {
		return fiber.ErrInternalServerError
	}
	return c.JSON(venue)
}

// GET /admin/venues/pending
func (h *AdminHandler) ListPendingVenues(c *fiber.Ctx) error {
	venues, err := h.venueRepo.FindPending(c.Context())
	if err != nil {
		return fiber.ErrInternalServerError
	}
	return c.JSON(venues)
}

// PUT /admin/venues/:id/approve
func (h *AdminHandler) ApproveVenue(c *fiber.Ctx) error {
	id := c.Params("id")
	adminID, err := getUserID(c)
	if err != nil {
		return err
	}

	if err := h.venueRepo.Approve(c.Context(), id, adminID, h.verificationPeriodDays); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return fiber.ErrNotFound
		}
		return fiber.ErrInternalServerError
	}

	h.writeAuditLog(c, "approve_venue", "venue", id, nil)
	return c.JSON(fiber.Map{"status": "approved"})
}

// PUT /admin/venues/:id/reject
// Body: {"note": "..."}
func (h *AdminHandler) RejectVenue(c *fiber.Ctx) error {
	id := c.Params("id")
	adminID, err := getUserID(c)
	if err != nil {
		return err
	}

	var req struct {
		Note *string `json:"note"`
	}
	// Body boş olabilir, parse hatasını yoksay
	_ = c.BodyParser(&req)

	if err := h.venueRepo.Reject(c.Context(), id, adminID, req.Note); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return fiber.ErrNotFound
		}
		return fiber.ErrInternalServerError
	}

	h.writeAuditLog(c, "reject_venue", "venue", id, req.Note)
	return c.JSON(fiber.Map{"status": "rejected"})
}

// ── Guide Başvuruları ─────────────────────────────────────────────────────────

// GET /admin/applications
func (h *AdminHandler) ListApplications(c *fiber.Ctx) error {
	list, err := h.guideRepo.ListPending(c.Context())
	if err != nil {
		return fiber.ErrInternalServerError
	}
	return c.JSON(list)
}

// PUT /admin/applications/:id/approve — Kodsuz başvuruyu onaylar: rolü guide yapar + çalışma şehrini ayarlar.
func (h *AdminHandler) ApproveApplication(c *fiber.Ctx) error {
	id := c.Params("id")
	adminID, err := getUserID(c)
	if err != nil {
		return err
	}

	app, err := h.guideRepo.FindByID(c.Context(), id)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return fiber.ErrNotFound
		}
		return fiber.ErrInternalServerError
	}

	if err := h.guideRepo.UpdateStatus(c.Context(), id, adminID, models.ApplicationStatusApproved, nil); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return c.Status(409).JSON(fiber.Map{"error": "başvuru zaten incelenmiş"})
		}
		return fiber.ErrInternalServerError
	}

	// Kullanıcı rolünü guide'a yükselt
	if err := h.userRepo.UpdateRole(c.Context(), app.UserID, models.RoleGuide); err != nil {
		return fiber.ErrInternalServerError
	}

	// Rehberin aktif çalışma şehrini başvurudaki beyandan ayarla.
	if err := h.userRepo.SetGuideCity(c.Context(), app.UserID, app.City); err != nil {
		log.Printf("[ADMIN] guide_city ayarlama hatası user=%s: %v", app.UserID, err)
	}

	h.writeAuditLog(c, "approve_guide_application", "guide_application", id, nil)
	return c.JSON(fiber.Map{"status": "approved"})
}

// PUT /admin/applications/:id/reject — Kodsuz başvuruyu reddeder.
// Body: {"note": "..."}
func (h *AdminHandler) RejectApplication(c *fiber.Ctx) error {
	id := c.Params("id")
	adminID, err := getUserID(c)
	if err != nil {
		return err
	}

	var req struct {
		Note *string `json:"note"`
	}
	if err := c.BodyParser(&req); err != nil {
		return fiber.ErrBadRequest
	}

	if err := h.guideRepo.UpdateStatus(c.Context(), id, adminID, models.ApplicationStatusRejected, req.Note); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return fiber.ErrNotFound
		}
		return fiber.ErrInternalServerError
	}

	h.writeAuditLog(c, "reject_guide_application", "guide_application", id, req.Note)
	return c.JSON(fiber.Map{"status": "rejected"})
}

// ── Audit Log ─────────────────────────────────────────────────────────────────

// GET /admin/audit-logs
func (h *AdminHandler) ListAuditLogs(c *fiber.Ctx) error {
	list, err := h.auditRepo.List(c.Context())
	if err != nil {
		return fiber.ErrInternalServerError
	}
	return c.JSON(list)
}

// ── Kullanıcılar ──────────────────────────────────────────────────────────────

// GET /admin/users
func (h *AdminHandler) ListUsers(c *fiber.Ctx) error {
	list, err := h.userRepo.List(c.Context())
	if err != nil {
		return fiber.ErrInternalServerError
	}
	return c.JSON(list)
}

// PUT /admin/users/:id
func (h *AdminHandler) UpdateUser(c *fiber.Ctx) error {
	id := c.Params("id")
	log.Printf("[ADMIN] UpdateUser called for id=%s", id)

	var req struct {
		Name     *string      `json:"name"`
		Surname  *string      `json:"surname"`
		Phone    *string      `json:"phone"`
		Email    *string      `json:"email"`
		Role     *models.Role `json:"role"`
		IsActive *bool        `json:"is_active"`
	}
	if err := c.BodyParser(&req); err != nil {
		log.Printf("[ADMIN] UpdateUser body parse error: %v", err)
		return fiber.ErrBadRequest
	}

	// Demote tespiti için mevcut rolü oku.
	// Okuma başarısız olursa prevRole boş kalır ve revoke atlanır (idempotent, güvenli).
	var prevRole models.Role
	if existing, ferr := h.userRepo.FindByID(c.Context(), id); ferr == nil {
		prevRole = existing.Role
	}

	if err := h.userRepo.Update(c.Context(), id, req.Name, req.Surname, req.Phone, req.Email, req.Role, req.IsActive); err != nil {
		log.Printf("[ADMIN] UpdateUser repo error for id=%s: %v", id, err)
		if errors.Is(err, repository.ErrNotFound) {
			return fiber.ErrNotFound
		}
		return fiber.ErrInternalServerError
	}

	// Guide'dan başka role düşürülüyorsa guide_city'yi temizle
	// ve açık guide başvurularını kapat (kullanıcı yeniden başvurabilsin).
	if prevRole == models.RoleGuide && req.Role != nil && *req.Role != models.RoleGuide {
		if cerr := h.userRepo.ClearGuideCity(c.Context(), id); cerr != nil {
			log.Printf("[ADMIN] guide_city temizleme hatası user=%s: %v", id, cerr)
		}
		if cerr := h.guideRepo.CancelOpenByUserID(c.Context(), id); cerr != nil {
			log.Printf("[ADMIN] başvuru kapatma hatası user=%s: %v", id, cerr)
		}
	}

	h.writeAuditLog(c, "update_user", "user", id, nil)

	user, err := h.userRepo.FindByID(c.Context(), id)
	if err != nil {
		log.Printf("[ADMIN] UpdateUser FindByID error for id=%s: %v", id, err)
		return fiber.ErrInternalServerError
	}
	return c.JSON(user)
}

// DELETE /admin/users/:id
func (h *AdminHandler) DeleteUser(c *fiber.Ctx) error {
	id := c.Params("id")

	// Admin kendini silemesin
	adminID, err := getUserID(c)
	if err != nil {
		return err
	}
	if id == adminID {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "kendi hesabınızı silemezsiniz"})
	}

	if err := h.userRepo.Delete(c.Context(), id); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return fiber.ErrNotFound
		}
		return fiber.ErrInternalServerError
	}

	h.writeAuditLog(c, "delete_user", "user", id, nil)
	return c.JSON(fiber.Map{"status": "deleted"})
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

// POST /admin/scheduler/run — doğrulama döngüsünü manuel tetikler (test için).
func (h *AdminHandler) RunSchedulerNow(c *fiber.Ctx) error {
	go h.schedulerSvc.RunNow(context.Background())
	return c.JSON(fiber.Map{"status": "started"})
}

// GET /admin/guides/by-city — şehir bazlı aktif rehber sayımı.
func (h *AdminHandler) GuidesByCity(c *fiber.Ctx) error {
	list, err := h.userRepo.CountGuidesByCity(c.Context())
	if err != nil {
		return fiber.ErrInternalServerError
	}
	return c.JSON(list)
}

// PUT /admin/venues/:id/reactivate
func (h *AdminHandler) ReactivateVenue(c *fiber.Ctx) error {
	id := c.Params("id")
	adminID, err := getUserID(c)
	if err != nil {
		return err
	}

	if err := h.venueRepo.ReactivateVenue(c.Context(), id, h.verificationPeriodDays); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return fiber.ErrNotFound
		}
		return fiber.ErrInternalServerError
	}

	h.writeAuditLog(c, "reactivate_venue", "venue", id, nil)
	_ = adminID
	return c.JSON(fiber.Map{"status": "reactivated"})
}
