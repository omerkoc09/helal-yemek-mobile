package handlers

import (
	"errors"
	"log"
	"strings"

	"github.com/gofiber/fiber/v2"
	"github.com/omerkoc/caiz-mi/internal/models"
	"github.com/omerkoc/caiz-mi/internal/repository"
	"github.com/omerkoc/caiz-mi/internal/services"
)

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
		CategoryIDs      *[]int    `json:"category_ids"`
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

	// Mutfak kategorileri
	if req.CategoryIDs != nil {
		if err := h.venueRepo.SetVenueCategories(c.Context(), venueID, *req.CategoryIDs); err != nil {
			log.Printf("[ADMIN] UpdateVenue SetVenueCategories error for id=%s: %v", venueID, err)
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

// ── Activity Stats ────────────────────────────────────────────────────────────
