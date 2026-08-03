package models

import "time"

type VenueReport struct {
	ID              string    `json:"id"`
	VenueID         string    `json:"venue_id"`
	VenueName       string    `json:"venue_name"`
	VenueCity       string    `json:"venue_city"`
	AddedByName     *string   `json:"added_by_name"`
	AddedByEmail    *string   `json:"added_by_email"`
	VenueAddedAt    time.Time `json:"venue_added_at"`
	UserID          string    `json:"user_id"`
	ReporterName    string    `json:"reporter_name"`
	ReporterSurname *string   `json:"reporter_surname"`
	ReporterEmail   string    `json:"reporter_email"`
	ReporterPhone   *string   `json:"reporter_phone"`
	ReporterRole    string    `json:"reporter_role"`
	Reason          string    `json:"reason"`
	Description     *string   `json:"description"`
	Status          string    `json:"status"`
	CreatedAt       time.Time `json:"created_at"`
}
