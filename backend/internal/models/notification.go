package models

import "time"

type NotificationType string

const (
	NotificationTypeVerificationWarning NotificationType = "verification_warning"
	NotificationTypeVenueSuspended      NotificationType = "venue_suspended"
)

type Notification struct {
	ID        string            `json:"id"`
	UserID    string            `json:"user_id"`
	Type      NotificationType  `json:"type"`
	Title     string            `json:"title"`
	Body      string            `json:"body"`
	Data      map[string]string `json:"data,omitempty"`
	IsRead    bool              `json:"is_read"`
	CreatedAt time.Time         `json:"created_at"`
}

type VerificationLog struct {
	ID        string    `json:"id"`
	VenueID   string    `json:"venue_id"`
	VenueName string    `json:"venue_name,omitempty"`
	GuideID   string    `json:"guide_id"`
	GuideName string    `json:"guide_name,omitempty"`
	City      string    `json:"city,omitempty"`
	Action    string    `json:"action"`
	CreatedAt time.Time `json:"created_at"`
}

// VenueForScheduler — scheduler'ın ihtiyaç duyduğu minimal venue bilgisi.
type VenueForScheduler struct {
	ID                string
	Name              string
	AddedBy           string
	GuideEmail        string
	GuideName         string
	VerificationDueAt *time.Time
}
