package models

import "time"

type ReferralStatus string

const (
	ReferralStatusActive  ReferralStatus = "active"
	ReferralStatusRevoked ReferralStatus = "revoked"
)

type ReferralCode struct {
	ID        string    `json:"id"`
	GuideID   string    `json:"guide_id"`
	Code      string    `json:"code"`
	Status    string    `json:"status"`
	CreatedAt time.Time `json:"created_at"`
}
