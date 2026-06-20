package models

import "time"

type Role string

const (
	RoleTraveler Role = "traveler"
	RoleGuide    Role = "guide"
	RoleAdmin    Role = "admin"
)

type User struct {
	ID           string    `json:"id"`
	Email        string    `json:"email"`
	PasswordHash *string   `json:"-"`
	Name         string    `json:"name"`
	Surname      *string   `json:"surname"`
	Phone        *string   `json:"phone"`
	AvatarURL    *string   `json:"avatar_url"`
	Role         Role      `json:"role"`
	Provider     string    `json:"provider"`
	ProviderID   *string   `json:"-"`
	IsActive     bool      `json:"is_active"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}
