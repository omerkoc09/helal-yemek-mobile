package models

import "time"

type ApplicationStatus string

const (
	ApplicationStatusPending  ApplicationStatus = "pending"
	ApplicationStatusApproved ApplicationStatus = "approved"
	ApplicationStatusRejected ApplicationStatus = "rejected"
)

type GuideApplication struct {
	ID           string            `json:"id"`
	UserID       string            `json:"user_id"`
	Status       ApplicationStatus `json:"status"`
	Note         *string           `json:"note,omitempty"`
	ReviewedBy   *string           `json:"reviewed_by,omitempty"`
	ReviewedAt   *time.Time        `json:"reviewed_at,omitempty"`
	ReferredBy      *string    `json:"referred_by,omitempty"`
	TermsAcceptedAt *time.Time `json:"terms_accepted_at,omitempty"`
	ReferrerName    *string    `json:"referrer_name,omitempty"`
	UserName     *string           `json:"user_name,omitempty"`
	UserEmail    *string           `json:"user_email,omitempty"`
	CreatedAt    time.Time         `json:"created_at"`
}
