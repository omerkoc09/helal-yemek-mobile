package repository

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type PasswordResetRepo struct {
	db *pgxpool.Pool
}

func NewPasswordResetRepo(db *pgxpool.Pool) *PasswordResetRepo {
	return &PasswordResetRepo{db: db}
}

// Create — yeni sıfırlama kodu kaydı ekler. codeHash bcrypt hash'idir.
func (r *PasswordResetRepo) Create(ctx context.Context, userID, codeHash string, expiresAt time.Time) error {
	_, err := r.db.Exec(ctx,
		`INSERT INTO password_reset_tokens (user_id, code_hash, expires_at)
		 VALUES ($1, $2, $3)`,
		userID, codeHash, expiresAt,
	)
	return err
}

// ClaimAttempt — kullanıcının en yeni aktif tokenının deneme sayacını ATOMİK
// olarak artırır ve hâlâ geçerliyse code_hash'i döner.
//
// Tek sorguda yapılması şart: "bul → kontrol et → artır" üç ayrı sorgu olsaydı
// paralel istekler attempts=4 iken aynı satırı okuyup 5 limitini aşabilirdi.
// Geçersiz (limit dolu / süresi geçmiş / kullanılmış / hiç yok) ise ErrNotFound.
func (r *PasswordResetRepo) ClaimAttempt(ctx context.Context, userID string) (string, string, error) {
	var tokenID, codeHash string
	err := r.db.QueryRow(ctx,
		`UPDATE password_reset_tokens
		    SET attempts = attempts + 1
		  WHERE id = (
		        SELECT id FROM password_reset_tokens
		         WHERE user_id = $1 AND used_at IS NULL
		         ORDER BY created_at DESC
		         LIMIT 1
		  )
		    AND attempts < 5
		    AND used_at IS NULL
		    AND expires_at > now()
		RETURNING id, code_hash`,
		userID,
	).Scan(&tokenID, &codeHash)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", "", ErrNotFound
	}
	if err != nil {
		return "", "", err
	}
	return tokenID, codeHash, nil
}

// MarkUsed — tokenı tek kullanımlık olarak damgalar. Yalnızca henüz
// kullanılmamışsa yazar; ikinci çağrı ErrNotFound döner.
func (r *PasswordResetRepo) MarkUsed(ctx context.Context, tokenID string) error {
	tag, err := r.db.Exec(ctx,
		`UPDATE password_reset_tokens
		    SET used_at = now()
		  WHERE id = $1 AND used_at IS NULL`,
		tokenID,
	)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// CountRecentByUserID — since'ten sonra oluşturulmuş token sayısı (saatlik limit).
func (r *PasswordResetRepo) CountRecentByUserID(ctx context.Context, userID string, since time.Time) (int, error) {
	var n int
	err := r.db.QueryRow(ctx,
		`SELECT COUNT(*) FROM password_reset_tokens
		  WHERE user_id = $1 AND created_at > $2`,
		userID, since,
	).Scan(&n)
	return n, err
}

// InvalidateActiveByUserID — kullanıcının açık tokenlarını kapatır.
func (r *PasswordResetRepo) InvalidateActiveByUserID(ctx context.Context, userID string) error {
	_, err := r.db.Exec(ctx,
		`UPDATE password_reset_tokens
		    SET used_at = now()
		  WHERE user_id = $1 AND used_at IS NULL`,
		userID,
	)
	return err
}

// DeleteExpiredBefore — fırsatçı temizlik; eski satırların sonsuza dek
// birikmesini önler.
func (r *PasswordResetRepo) DeleteExpiredBefore(ctx context.Context, cutoff time.Time) error {
	_, err := r.db.Exec(ctx,
		`DELETE FROM password_reset_tokens WHERE expires_at < $1`,
		cutoff,
	)
	return err
}
