package models

import "time"

type Review struct {
	ID        string    `json:"id"`
	VenueID   string    `json:"venue_id"`
	UserID    string    `json:"user_id"`
	Rating    int       `json:"rating"`
	Comment   *string   `json:"comment"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}
