package repository

import (
	"context"
	"crypto/rand"
	"errors"
	"fmt"
	"math/big"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/omerkoc/caiz-mi/internal/models"
)

const codeCharset = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // I,O,0,1 hariç (karışmaması için)
const codeLength = 5

type ReferralRepo struct {
	db *pgxpool.Pool
}

func NewReferralRepo(db *pgxpool.Pool) *ReferralRepo {
	return &ReferralRepo{db: db}
}

// generateCode — 5 karakterlik rastgele büyük harf/rakam kodu üretir.
func generateCode() (string, error) {
	b := make([]byte, codeLength)
	for i := range b {
		n, err := rand.Int(rand.Reader, big.NewInt(int64(len(codeCharset))))
		if err != nil {
			return "", err
		}
		b[i] = codeCharset[n.Int64()]
	}
	return string(b), nil
}

// FindActiveByCode — aktif referans kodunu bulur.
func (r *ReferralRepo) FindActiveByCode(ctx context.Context, code string) (*models.ReferralCode, error) {
	rc := &models.ReferralCode{}
	err := r.db.QueryRow(ctx,
		`SELECT id, guide_id, code, status, used_by, used_at, created_at
		 FROM referral_codes WHERE code = $1 AND status = 'active'`,
		code,
	).Scan(&rc.ID, &rc.GuideID, &rc.Code, &rc.Status, &rc.UsedBy, &rc.UsedAt, &rc.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	return rc, err
}

// UseCode — referans kodunu kullanılmış olarak işaretler.
func (r *ReferralRepo) UseCode(ctx context.Context, codeID, usedByUserID string) error {
	result, err := r.db.Exec(ctx,
		`UPDATE referral_codes SET status = 'used', used_by = $1, used_at = NOW()
		 WHERE id = $2 AND status = 'active'`,
		usedByUserID, codeID,
	)
	if err != nil {
		return err
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// CreateCode — guide için yeni aktif referans kodu üretir.
// Unique constraint ihlalinde en fazla 5 kez yeni kod dener.
func (r *ReferralRepo) CreateCode(ctx context.Context, guideID string) (*models.ReferralCode, error) {
	const maxRetries = 5
	for i := 0; i < maxRetries; i++ {
		code, err := generateCode()
		if err != nil {
			return nil, err
		}

		rc := &models.ReferralCode{
			GuideID: guideID,
			Code:    code,
			Status:  string(models.ReferralStatusActive),
		}
		err = r.db.QueryRow(ctx,
			`INSERT INTO referral_codes (guide_id, code) VALUES ($1, $2) RETURNING id, created_at`,
			guideID, code,
		).Scan(&rc.ID, &rc.CreatedAt)
		if err == nil {
			return rc, nil
		}
		if strings.Contains(err.Error(), "duplicate key") || strings.Contains(err.Error(), "unique") {
			continue
		}
		return nil, err
	}
	return nil, fmt.Errorf("referans kodu üretilemedi: %d deneme sonrası benzersiz kod bulunamadı", maxRetries)
}

// GetActiveByGuideID — guide'ın aktif referans kodunu getirir.
func (r *ReferralRepo) GetActiveByGuideID(ctx context.Context, guideID string) (*models.ReferralCode, error) {
	rc := &models.ReferralCode{}
	err := r.db.QueryRow(ctx,
		`SELECT id, guide_id, code, status, used_by, used_at, created_at
		 FROM referral_codes WHERE guide_id = $1 AND status = 'active'`,
		guideID,
	).Scan(&rc.ID, &rc.GuideID, &rc.Code, &rc.Status, &rc.UsedBy, &rc.UsedAt, &rc.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	return rc, err
}
