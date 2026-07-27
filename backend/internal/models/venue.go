package models

import "time"

type VenueStatus string

const (
	VenueStatusPending   VenueStatus = "pending"
	VenueStatusApproved  VenueStatus = "approved"
	VenueStatusRejected  VenueStatus = "rejected"
	VenueStatusSuspended VenueStatus = "suspended"
)

type TrustCriteria struct {
	ID          int     `json:"id"`
	Key         string  `json:"key"`
	Name        string  `json:"name"`
	Description *string `json:"description,omitempty"`
}

type FoodCategory struct {
	ID       int     `json:"id"`
	Key      string  `json:"key"`
	Name     string  `json:"name"`
	ImageURL *string `json:"image_url,omitempty"`
}

type VenuePhoto struct {
	ID         string    `json:"id"`
	VenueID    string    `json:"venue_id"`
	URL        string    `json:"url"`
	UploadedBy string    `json:"uploaded_by"`
	IsPrimary  bool      `json:"is_primary"`
	CreatedAt  time.Time `json:"created_at"`
}

type Venue struct {
	ID               string          `json:"id"`
	Name             string          `json:"name"`
	City             string          `json:"city"`
	District         *string         `json:"district,omitempty"`
	Latitude         float64         `json:"latitude"`
	Longitude        float64         `json:"longitude"`
	GooglePlaceID    *string         `json:"google_place_id,omitempty"`
	Notes            *string         `json:"notes"`
	Status           VenueStatus     `json:"status"`
	RejectionNote    *string         `json:"rejection_note,omitempty"`
	AddedBy          string          `json:"added_by"`
	AddedByName      *string         `json:"added_by_name,omitempty"`
	AddedBySurname   *string         `json:"added_by_surname,omitempty"`
	AddedByEmail     *string         `json:"added_by_email,omitempty"`
	ApprovedBy       *string         `json:"approved_by,omitempty"`
	VerifiedAt          *time.Time      `json:"verified_at,omitempty"`
	VerificationDueAt   *time.Time      `json:"verification_due_at,omitempty"`
	LastNotifiedAt      *time.Time      `json:"last_notified_at,omitempty"`
	Distance            *float64        `json:"distance,omitempty"` // metre cinsinden, yakın mekan sorgusunda dolar
	FoodHalalMode    string          `json:"food_halal_mode"`
	ExcludedProducts []string        `json:"excluded_products"`
	TrustCriteria    []TrustCriteria `json:"trust_criteria"`
	Photos           []VenuePhoto    `json:"photos"`
	Categories       []FoodCategory  `json:"categories"`
	AverageRating    *float64        `json:"average_rating,omitempty"`
	ReviewCount      int             `json:"review_count"`
	ConfirmationCount int             `json:"confirmation_count"`
	Badge            *Badge          `json:"badge,omitempty"`
	// ConfirmedByMe — yalnızca giriş yapmış viewer için detay sorgusunda doldurulur:
	// bu kullanıcı mekanı içinde bulunulan dönemde doğrulamış mı? Anonim/diğer
	// sorgularda nil kalır (omitempty ile JSON'a yazılmaz).
	ConfirmedByMe    *bool           `json:"confirmed_by_me,omitempty"`
	// ConfirmedAt — yalnızca "doğruladığım mekanlar" listesinde dolar: bu
	// rehberin mekanı ne zaman doğruladığı. Diğer sorgularda nil kalır.
	ConfirmedAt      *time.Time      `json:"confirmed_at,omitempty"`
	CategoriesStr    *string         `json:"categories_str,omitempty"`
	CreatedAt        time.Time       `json:"created_at"`
	UpdatedAt        time.Time       `json:"updated_at"`
}

// Badge — mekanın dönemsel taze onay sayısından türetilen güven rozeti.
type Badge struct {
	Level string `json:"level"` // base | bronze | silver | gold | platinum
	Count int    `json:"count"` // son periyottaki farklı doğrulayan sayısı (ekleyen dahil)
}

// BadgeFromCount — dönemsel onay sayısını rozet seviyesine çevirir.
func BadgeFromCount(count int) Badge {
	level := "base"
	switch {
	case count >= 11:
		level = "platinum"
	case count >= 6:
		level = "gold"
	case count >= 2:
		level = "silver"
	case count >= 1:
		level = "bronze"
	}
	return Badge{Level: level, Count: count}
}
