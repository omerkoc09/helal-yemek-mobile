package handlers

import (
	"errors"
	"log"
	"strings"

	"github.com/gofiber/fiber/v2"
	"github.com/omerkoc/itimat-mobile/internal/models"
	"github.com/omerkoc/itimat-mobile/internal/repository"
	"golang.org/x/crypto/bcrypt"
)

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

	// Statü + rol + şehir tek transaction'da. Herhangi biri başarısız olursa
	// hepsi geri sarılır; kullanıcı "guide ama şehirsiz" durumuna düşmez.
	if _, err := h.guideRepo.ApproveApplication(c.Context(), id, adminID); err != nil {
		switch {
		case errors.Is(err, repository.ErrNotFound):
			return fiber.ErrNotFound
		case errors.Is(err, repository.ErrAlreadyReviewed):
			return c.Status(409).JSON(fiber.Map{"error": "başvuru zaten incelenmiş"})
		default:
			return fiber.ErrInternalServerError
		}
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

// POST /admin/users
func (h *AdminHandler) CreateUser(c *fiber.Ctx) error {
	var req struct {
		Email     string      `json:"email"`
		Password  string      `json:"password"`
		Name      string      `json:"name"`
		Surname   string      `json:"surname"`
		Phone     string      `json:"phone"`
		Role      models.Role `json:"role"`
		GuideCity string      `json:"guide_city"`
	}
	if err := c.BodyParser(&req); err != nil {
		return fiber.ErrBadRequest
	}
	if req.Email == "" || req.Password == "" || req.Name == "" || req.Surname == "" || req.Phone == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "email, şifre, ad, soyad ve telefon zorunludur"})
	}
	if req.Role == "" {
		req.Role = models.RoleTraveler
	}

	// guide_city yalnızca rehber rolünde anlamlı; doluysa kanonik şehre normalize et.
	var guideCity *string
	if req.Role == models.RoleGuide {
		if trimmed := strings.TrimSpace(req.GuideCity); trimmed != "" {
			canonical, ok := models.NormalizeCity(trimmed)
			if !ok {
				return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "geçersiz şehir: " + trimmed})
			}
			guideCity = &canonical
		}
	}

	exists, err := h.userRepo.EmailExists(c.Context(), req.Email)
	if err != nil {
		return fiber.ErrInternalServerError
	}
	if exists {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "bu email adresi zaten kullanılıyor"})
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return fiber.ErrInternalServerError
	}
	hashStr := string(hash)

	user := &models.User{
		Email:        strings.ToLower(strings.TrimSpace(req.Email)),
		PasswordHash: &hashStr,
		Name:         strings.TrimSpace(req.Name),
		Surname:      strPtr(strings.TrimSpace(req.Surname)),
		Phone:        strPtr(strings.TrimSpace(req.Phone)),
		Role:         req.Role,
		Provider:     "email",
		IsActive:     true,
		GuideCity:    guideCity,
	}
	if err := h.userRepo.Create(c.Context(), user); err != nil {
		return fiber.ErrInternalServerError
	}

	h.writeAuditLog(c, "create_user", "user", user.ID, nil)
	return c.Status(fiber.StatusCreated).JSON(user)
}

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
		Name      *string      `json:"name"`
		Surname   *string      `json:"surname"`
		Phone     *string      `json:"phone"`
		Email     *string      `json:"email"`
		Role      *models.Role `json:"role"`
		IsActive  *bool        `json:"is_active"`
		GuideCity *string      `json:"guide_city"`
	}
	if err := c.BodyParser(&req); err != nil {
		log.Printf("[ADMIN] UpdateUser body parse error: %v", err)
		return fiber.ErrBadRequest
	}

	// guide_city gönderildiyse: boş string → temizle (NULL), dolu → kanonik şehre normalize et.
	if req.GuideCity != nil {
		trimmed := strings.TrimSpace(*req.GuideCity)
		if trimmed == "" {
			req.GuideCity = strPtr("")
		} else {
			canonical, ok := models.NormalizeCity(trimmed)
			if !ok {
				return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "geçersiz şehir: " + trimmed})
			}
			req.GuideCity = strPtr(canonical)
		}
	}

	// Demote tespiti için mevcut rolü oku.
	// Okuma başarısız olursa prevRole boş kalır ve revoke atlanır (idempotent, güvenli).
	var prevRole models.Role
	if existing, ferr := h.userRepo.FindByID(c.Context(), id); ferr == nil {
		prevRole = existing.Role
	}

	if err := h.userRepo.Update(c.Context(), id, req.Name, req.Surname, req.Phone, req.Email, req.Role, req.IsActive, req.GuideCity); err != nil {
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

// GET /admin/users/:id
func (h *AdminHandler) GetUser(c *fiber.Ctx) error {
	id := c.Params("id")
	user, err := h.userRepo.FindByID(c.Context(), id)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "kullanıcı bulunamadı"})
		}
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "kullanıcı alınamadı"})
	}
	return c.JSON(user)
}

// PUT /admin/users/:id/password
func (h *AdminHandler) UpdateUserPassword(c *fiber.Ctx) error {
	id := c.Params("id")
	var req struct {
		Password string `json:"password"`
	}
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "geçersiz istek"})
	}
	if len(req.Password) < 6 {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "şifre en az 6 karakter olmalıdır"})
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "şifre hashlenemedi"})
	}
	if err := h.userRepo.UpdatePassword(c.Context(), id, string(hash)); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "kullanıcı bulunamadı"})
		}
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "şifre güncellenemedi"})
	}
	return c.JSON(fiber.Map{"message": "şifre güncellendi"})
}

// GET /admin/users/:id/venues
func (h *AdminHandler) GetUserVenues(c *fiber.Ctx) error {
	id := c.Params("id")
	venues, err := h.venueRepo.FindByUserID(c.Context(), id)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "mekanlar alınamadı"})
	}
	if venues == nil {
		venues = []models.Venue{}
	}
	return c.JSON(venues)
}

// GET /admin/users/:id/reviews
func (h *AdminHandler) GetUserReviews(c *fiber.Ctx) error {
	id := c.Params("id")
	reviews, err := h.reviewRepo.FindByUserID(c.Context(), id)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "yorumlar alınamadı"})
	}
	if reviews == nil {
		reviews = []repository.ReviewWithVenue{}
	}
	return c.JSON(reviews)
}

// GET /admin/venues/:id/confirming-guides
func (h *AdminHandler) GetVenueConfirmingGuides(c *fiber.Ctx) error {
	id := c.Params("id")
	guides, err := h.venueRepo.ListConfirmingGuides(c.Context(), id)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "doğrulayan rehberler alınamadı"})
	}
	if guides == nil {
		guides = []repository.ConfirmingGuide{}
	}
	return c.JSON(guides)
}

// GET /admin/guides/by-city — şehir bazlı aktif rehber sayımı.
func (h *AdminHandler) GuidesByCity(c *fiber.Ctx) error {
	list, err := h.userRepo.CountGuidesByCity(c.Context())
	if err != nil {
		return fiber.ErrInternalServerError
	}
	return c.JSON(list)
}
