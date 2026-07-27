package handlers

import (
	"context"

	"github.com/omerkoc/itimat-mobile/internal/models"
	"github.com/omerkoc/itimat-mobile/internal/repository"
	"github.com/omerkoc/itimat-mobile/internal/services"
)

// guideCityGetter — VenueHandler'ın guide_city sorgusunda ihtiyaç duyduğu minimal arayüz.
// *repository.UserRepo bu arayüzü otomatik olarak karşılar; testte sahte (fake) uygulamalar kullanılabilir.
type guideCityGetter interface {
	GetGuideCity(ctx context.Context, userID string) (*string, error)
}

// directionClickCreator — yol tarifi tıklamasını kaydeden minimal arayüz.
// *repository.DirectionClickRepo bu arayüzü otomatik olarak karşılar; testte sahte uygulamalar kullanılabilir.
type directionClickCreator interface {
	Create(ctx context.Context, venueID string, userID *string) error
}

// venueStore — VenueHandler'ın VenueRepo'dan kullandığı metotlar.
//
// Arayüzün bu kadar geniş olması bir tasarım sinyali: VenueHandler 20 endpoint
// ile mekan CRUD, fotoğraf, kriter, yemek kalemi, onaylama ve doğrulama
// sorumluluklarını birlikte taşıyor. Handler mantıksal parçalara bölündüğünde
// bu arayüz de doğal olarak küçük parçalara ayrılmalı (bkz. docs/progress.md).
type venueStore interface {
	// Okuma / listeleme
	FindByID(ctx context.Context, id string) (*models.Venue, error)
	FindByCity(ctx context.Context, city string, lat, lng float64, limit int) ([]models.Venue, error)
	FindByFoodCategory(ctx context.Context, categoryID int) ([]models.Venue, error)
	FindByGooglePlaceID(ctx context.Context, placeID string) (*models.Venue, error)
	FindNearby(ctx context.Context, lat, lng, radiusMeters float64) ([]models.Venue, error)
	FindNearbyApproved(ctx context.Context, lat, lng, radiusMeters float64, limit int) ([]models.Venue, error)
	FindPopular(ctx context.Context, lat, lng, radiusMeters float64, limit int) ([]models.Venue, error)
	FindDistinctCities(ctx context.Context) ([]string, error)
	SearchByText(ctx context.Context, query string) ([]models.Venue, error)

	// Yazma
	Create(ctx context.Context, v *models.Venue) error
	UpdateVenue(ctx context.Context, id string, name, city, district *string, lat, lng *float64, notes *string, googlePlaceID *string) error
	Approve(ctx context.Context, id, adminID string, periodDays int) error

	// Fotoğraf
	AddPhoto(ctx context.Context, photo *models.VenuePhoto) error
	DeletePhoto(ctx context.Context, photoID, venueID string) error
	FindPhotoByID(ctx context.Context, photoID string) (*models.VenuePhoto, error)
	GetPhotosByVenueID(ctx context.Context, venueID string) ([]models.VenuePhoto, error)

	// Kriter ve yemek
	GetAllCriteria(ctx context.Context) ([]models.TrustCriteria, error)
	GetCriteriaByVenueID(ctx context.Context, venueID string) ([]models.TrustCriteria, error)
	SetCriteria(ctx context.Context, venueID string, criteriaIDs []int) error
	GetAllFoodCategories(ctx context.Context) ([]models.FoodCategory, error)
	GetCategoriesByVenueID(ctx context.Context, venueID string) ([]models.FoodCategory, error)
	SetVenueCategories(ctx context.Context, venueID string, categoryIDs []int) error
	SetFoodHalalMode(ctx context.Context, venueID string, mode string) error
	SetExcludedProducts(ctx context.Context, venueID string, products []string) error

	// Onaylama / dönemsel doğrulama
	ConfirmVenue(ctx context.Context, venueID, guideID, guideCity string, periodDays int) error
	RemoveConfirmation(ctx context.Context, venueID, guideID string, periodDays int) error
	HasConfirmed(ctx context.Context, venueID, guideID string) (bool, error)
	VerifyByGuide(ctx context.Context, venueID, guideID string, periodDays int) error
}

// verificationLogger — doğrulama/onay eylemlerinin iz kaydını yazar.
type verificationLogger interface {
	Create(ctx context.Context, venueID, guideID, action string) error
}

type VenueHandler struct {
	venueRepo              venueStore
	userRepo               guideCityGetter
	storageService         *services.StorageService
	placesService          *services.PlacesService
	verifLogRepo           verificationLogger
	directionRepo          directionClickCreator
	verificationPeriodDays int
}

func NewVenueHandler(
	venueRepo *repository.VenueRepo,
	userRepo *repository.UserRepo,
	storageService *services.StorageService,
	placesService *services.PlacesService,
	verifLogRepo *repository.VerificationLogRepo,
	directionRepo *repository.DirectionClickRepo,
	verificationPeriodDays int,
) *VenueHandler {
	return &VenueHandler{
		venueRepo:              venueRepo,
		userRepo:               userRepo,
		storageService:         storageService,
		placesService:          placesService,
		verifLogRepo:           verifLogRepo,
		directionRepo:          directionRepo,
		verificationPeriodDays: verificationPeriodDays,
	}
}
