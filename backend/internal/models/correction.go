package models

import "time"

type CorrectionStatus string

const (
	CorrectionStatusPending  CorrectionStatus = "pending"
	CorrectionStatusApproved CorrectionStatus = "approved"
	CorrectionStatusRejected CorrectionStatus = "rejected"
)

type CorrectionSuggestion struct {
	ID          string           `json:"id"`
	VenueID     string           `json:"venue_id"`
	SuggestedBy string           `json:"suggested_by"`
	FieldName   string           `json:"field_name"`
	OldValue    *string          `json:"old_value"`
	NewValue    string           `json:"new_value"`
	Status      CorrectionStatus `json:"status"`
	ReviewedBy  *string          `json:"reviewed_by,omitempty"`
	ReviewedAt  *time.Time       `json:"reviewed_at,omitempty"`
	Note        *string          `json:"note,omitempty"`
	CreatedAt   time.Time        `json:"created_at"`
}
