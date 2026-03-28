package models

import "time"

type ReferralStatus string

const (
	ReferralStatusActive ReferralStatus = "active"
	ReferralStatusUsed   ReferralStatus = "used"
)

type ReferralCode struct {
	ID        string     `json:"id"`
	GuideID   string     `json:"guide_id"`
	Code      string     `json:"code"`
	Status    string     `json:"status"`
	UsedBy    *string    `json:"used_by,omitempty"`
	UsedAt    *time.Time `json:"used_at,omitempty"`
	CreatedAt time.Time  `json:"created_at"`
}
