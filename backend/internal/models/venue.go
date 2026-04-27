package models

import "time"

type VenueStatus string

const (
	VenueStatusPending  VenueStatus = "pending"
	VenueStatusApproved VenueStatus = "approved"
	VenueStatusRejected VenueStatus = "rejected"
)

type HalalCriteria struct {
	ID            int     `json:"id"`
	Key           string  `json:"key"`
	LabelTR       string  `json:"label_tr"`
	LabelEN       string  `json:"label_en"`
	DescriptionTR *string `json:"description_tr,omitempty"`
	DescriptionEN *string `json:"description_en,omitempty"`
}

type FoodCategory struct {
	ID      int        `json:"id"`
	Key     string     `json:"key"`
	LabelTR string     `json:"label_tr"`
	LabelEN string     `json:"label_en"`
	Items   []FoodItem `json:"items"`
}

type FoodItem struct {
	ID         int    `json:"id"`
	CategoryID int    `json:"category_id"`
	Key        string `json:"key"`
	LabelTR    string `json:"label_tr"`
	LabelEN    string `json:"label_en"`
	IsCustom   bool   `json:"is_custom"`
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
	Address          string          `json:"address"`
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
	ApprovedBy       *string         `json:"approved_by,omitempty"`
	VerifiedAt       *time.Time      `json:"verified_at,omitempty"`
	Distance         *float64        `json:"distance,omitempty"` // metre cinsinden, yakın mekan sorgusunda dolar
	FoodHalalMode    string          `json:"food_halal_mode"`
	ExcludedProducts []string        `json:"excluded_products"`
	Criteria         []HalalCriteria `json:"criteria"`
	Photos           []VenuePhoto    `json:"photos"`
	FoodItems        []FoodItem      `json:"food_items"`
	AverageRating    *float64        `json:"average_rating,omitempty"`
	ReviewCount      int             `json:"review_count"`
	CategoriesStr    *string         `json:"categories_str,omitempty"`
	CreatedAt        time.Time       `json:"created_at"`
	UpdatedAt        time.Time       `json:"updated_at"`
}
