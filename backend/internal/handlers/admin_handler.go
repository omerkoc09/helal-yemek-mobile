package handlers

import (
	"context"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/omerkoc/caiz-mi/internal/models"
	"github.com/omerkoc/caiz-mi/internal/repository"
	"github.com/omerkoc/caiz-mi/internal/services"
)

func strPtr(s string) *string { return &s }

type SchedulerRunner interface {
	RunNow(ctx context.Context)
}

// Aşağıdaki arayüzler AdminHandler'ın moderasyon ve kullanıcı yönetimi
// akışlarında kullandığı repo metotlarını kapsar. Genişlikleri bir tasarım
// sinyali: AdminHandler 35 endpoint ile mekan moderasyonu, rehber başvuruları,
// kullanıcı yönetimi, istatistikler ve yemek kategorilerini birlikte taşıyor.

// adminVenueStore — mekan moderasyonu ve yemek kategorisi yönetimi.
type adminVenueStore interface {
	Approve(ctx context.Context, id, adminID string, periodDays int) error
	Reject(ctx context.Context, id, adminID string, note *string) error
	SetStatus(ctx context.Context, id string, status models.VenueStatus, adminID string, note *string, periodDays int) error
	ReactivateVenue(ctx context.Context, id string, periodDays int) error
	SoftDelete(ctx context.Context, id string) error
	FindAll(ctx context.Context) ([]models.Venue, error)
	FindPending(ctx context.Context) ([]models.Venue, error)
	FindByID(ctx context.Context, id string) (*models.Venue, error)
	FindByUserID(ctx context.Context, userID string) ([]models.Venue, error)
	UpdateVenue(ctx context.Context, id string, name, city, district *string, lat, lng *float64, notes *string, googlePlaceID *string) error
	SetCriteria(ctx context.Context, venueID string, criteriaIDs []int) error
	SetVenueFoodItems(ctx context.Context, venueID string, foodItemIDs []int) error
	SetFoodHalalMode(ctx context.Context, venueID string, mode string) error
	SetExcludedProducts(ctx context.Context, venueID string, products []string) error
	ListConfirmingGuides(ctx context.Context, venueID string) ([]repository.ConfirmingGuide, error)
	CountApprovedVenuesByCity(ctx context.Context) ([]repository.CityVenueCount, error)
	CountByDay(ctx context.Context, from, to time.Time) ([]repository.DayCount, error)
	CountToday(ctx context.Context, todayStart, tomorrow time.Time) (int, error)
	GetAllFoodCategoriesWithItems(ctx context.Context) ([]models.FoodCategory, error)
	CreateFoodCategory(ctx context.Context, key, name string) (*models.FoodCategory, error)
	UpdateFoodCategory(ctx context.Context, id int, name string) error
	DeleteFoodCategory(ctx context.Context, id int) error
	GetFoodCategoryImageURL(ctx context.Context, id int) (*string, error)
	SetFoodCategoryImage(ctx context.Context, id int, imageURL string) error
	CreateCustomFoodItem(ctx context.Context, categoryID int, key, name string) (*models.FoodItem, error)
	UpdateFoodItem(ctx context.Context, id int, name string) error
	DeleteFoodItem(ctx context.Context, id int) error
}

// adminGuideStore — rehber başvurusu inceleme akışı.
type adminGuideStore interface {
	ListPending(ctx context.Context) ([]models.GuideApplication, error)
	FindByID(ctx context.Context, id string) (*models.GuideApplication, error)
	UpdateStatus(ctx context.Context, id, adminID string, status models.ApplicationStatus, note *string) error
	CancelOpenByUserID(ctx context.Context, userID string) error
}

// adminUserStore — kullanıcı yönetimi ve rol atama.
type adminUserStore interface {
	List(ctx context.Context) ([]models.User, error)
	FindByID(ctx context.Context, id string) (*models.User, error)
	Create(ctx context.Context, u *models.User) error
	Update(ctx context.Context, id string, name, surname, phone, email *string, role *models.Role, isActive *bool, guideCity *string) error
	Delete(ctx context.Context, id string) error
	EmailExists(ctx context.Context, email string) (bool, error)
	UpdateRole(ctx context.Context, id string, role models.Role) error
	UpdatePassword(ctx context.Context, id, hashedPassword string) error
	SetGuideCity(ctx context.Context, userID, city string) error
	ClearGuideCity(ctx context.Context, userID string) error
	CountGuidesByCity(ctx context.Context) ([]repository.CityGuideCount, error)
	CountByDay(ctx context.Context, from, to time.Time) ([]repository.DayCount, error)
	CountToday(ctx context.Context, todayStart, tomorrow time.Time) (int, error)
}

// adminAuditStore — admin kararlarının denetim kaydı.
type adminAuditStore interface {
	Create(ctx context.Context, l *models.AuditLog) error
	List(ctx context.Context) ([]models.AuditLog, error)
}

type AdminHandler struct {
	venueRepo              adminVenueStore
	guideRepo              adminGuideStore
	userRepo               adminUserStore
	auditRepo              adminAuditStore
	verifLogRepo           *repository.VerificationLogRepo
	reviewRepo             *repository.ReviewRepo
	loginRepo              *repository.LoginRepo
	directionRepo          *repository.DirectionClickRepo
	schedulerSvc           SchedulerRunner
	storageService         *services.StorageService
	verificationPeriodDays int
}

func NewAdminHandler(
	venueRepo *repository.VenueRepo,
	guideRepo *repository.GuideRepo,
	userRepo *repository.UserRepo,
	auditRepo *repository.AuditRepo,
	verifLogRepo *repository.VerificationLogRepo,
	reviewRepo *repository.ReviewRepo,
	loginRepo *repository.LoginRepo,
	directionRepo *repository.DirectionClickRepo,
	schedulerSvc SchedulerRunner,
	storageService *services.StorageService,
	verificationPeriodDays int,
) *AdminHandler {
	return &AdminHandler{
		venueRepo:              venueRepo,
		guideRepo:              guideRepo,
		userRepo:               userRepo,
		auditRepo:              auditRepo,
		verifLogRepo:           verifLogRepo,
		reviewRepo:             reviewRepo,
		loginRepo:              loginRepo,
		directionRepo:          directionRepo,
		schedulerSvc:           schedulerSvc,
		storageService:         storageService,
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
