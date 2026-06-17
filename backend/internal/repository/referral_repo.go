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
		`SELECT id, guide_id, code, status, created_at
		 FROM referral_codes WHERE code = $1 AND status = 'active'`,
		code,
	).Scan(&rc.ID, &rc.GuideID, &rc.Code, &rc.Status, &rc.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	return rc, err
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

// ApproveGuideTx — referans kodu ile başvuran kullanıcıyı tek transaction içinde
// guide'a yükseltir: guide_applications'a approved kayıt yazar, rolü günceller ve
// yeni guide'a kalıcı referans kodunu üretir. Hepsi atomiktir.
func (r *ReferralRepo) ApproveGuideTx(ctx context.Context, userID, referrerGuideID string) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx) //nolint

	// 1. Onaylı başvuru kaydı (davet kayıt defteri).
	if _, err := tx.Exec(ctx,
		`INSERT INTO guide_applications (user_id, status, referred_by, reviewed_at)
		 VALUES ($1, 'approved', $2, NOW())`,
		userID, referrerGuideID,
	); err != nil {
		return fmt.Errorf("başvuru kaydı eklenemedi: %w", err)
	}

	// 2. Rolü guide'a yükselt.
	res, err := tx.Exec(ctx,
		`UPDATE users SET role = 'guide', updated_at = NOW() WHERE id = $1`,
		userID,
	)
	if err != nil {
		return fmt.Errorf("rol güncellenemedi: %w", err)
	}
	if res.RowsAffected() == 0 {
		return ErrNotFound
	}

	// 3. Yeni guide'a kalıcı referans kodu üret (unique çakışmada yeniden dene).
	const maxRetries = 5
	for i := 0; i < maxRetries; i++ {
		code, err := generateCode()
		if err != nil {
			return err
		}
		_, err = tx.Exec(ctx,
			`INSERT INTO referral_codes (guide_id, code) VALUES ($1, $2)`,
			userID, code,
		)
		if err == nil {
			return tx.Commit(ctx)
		}
		if strings.Contains(err.Error(), "duplicate key") || strings.Contains(err.Error(), "unique") {
			continue
		}
		return err
	}
	return fmt.Errorf("referans kodu üretilemedi: %d deneme sonrası benzersiz kod bulunamadı", maxRetries)
}

// RevokeByGuideID — guide demote edildiğinde aktif referans kodunu iptal eder.
// Aktif kod yoksa sessizce geçer (idempotent).
func (r *ReferralRepo) RevokeByGuideID(ctx context.Context, guideID string) error {
	_, err := r.db.Exec(ctx,
		`UPDATE referral_codes SET status = 'revoked' WHERE guide_id = $1 AND status = 'active'`,
		guideID,
	)
	return err
}

// GetActiveByGuideID — guide'ın aktif referans kodunu getirir.
func (r *ReferralRepo) GetActiveByGuideID(ctx context.Context, guideID string) (*models.ReferralCode, error) {
	rc := &models.ReferralCode{}
	err := r.db.QueryRow(ctx,
		`SELECT id, guide_id, code, status, created_at
		 FROM referral_codes WHERE guide_id = $1 AND status = 'active'`,
		guideID,
	).Scan(&rc.ID, &rc.GuideID, &rc.Code, &rc.Status, &rc.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	return rc, err
}
