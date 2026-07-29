package models

import "time"

// PasswordResetToken — şifre sıfırlama kodunun DB kaydı.
// code_hash bcrypt ile hash'lenmiş 6 haneli kodu tutar; ham kod saklanmaz.
type PasswordResetToken struct {
	ID        string     `json:"id"`
	UserID    string     `json:"user_id"`
	CodeHash  string     `json:"-"`
	ExpiresAt time.Time  `json:"expires_at"`
	Attempts  int        `json:"attempts"`
	UsedAt    *time.Time `json:"used_at"`
	CreatedAt time.Time  `json:"created_at"`
}
