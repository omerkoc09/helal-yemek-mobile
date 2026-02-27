package models

import "time"

type Favorite struct {
	UserID    string    `json:"user_id"`
	VenueID   string    `json:"venue_id"`
	CreatedAt time.Time `json:"created_at"`
}
