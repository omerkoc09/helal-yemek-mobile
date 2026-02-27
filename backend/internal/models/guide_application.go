package models

import "time"

type ApplicationStatus string

const (
	ApplicationStatusPending  ApplicationStatus = "pending"
	ApplicationStatusApproved ApplicationStatus = "approved"
	ApplicationStatusRejected ApplicationStatus = "rejected"
)

type GuideApplication struct {
	ID         string            `json:"id"`
	UserID     string            `json:"user_id"`
	Status     ApplicationStatus `json:"status"`
	Note       *string           `json:"note,omitempty"`
	ReviewedBy *string           `json:"reviewed_by,omitempty"`
	ReviewedAt *time.Time        `json:"reviewed_at,omitempty"`
	CreatedAt  time.Time         `json:"created_at"`
}
