package repository

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
)

// Approve — mekanı onaylar: status=approved, approved_by, verified_at güncellenir.
func (r *VenueRepo) Approve(ctx context.Context, id, adminID string) error {
	result, err := r.db.Exec(ctx,
		`UPDATE venues
		 SET status = 'approved',
		     approved_by = $1,
		     verified_at = NOW(),
		     confirmation_count = GREATEST(confirmation_count, 1),
		     updated_at = NOW()
		 WHERE id = $2 AND status IN ('pending', 'rejected') AND deleted_at IS NULL`,
		adminID, id,
	)
	if err != nil {
		return fmt.Errorf("mekan onaylama başarısız: %w", err)
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// Suspend — onaylı veya reddedilmiş mekanı tekrar pending durumuna alır.
func (r *VenueRepo) Suspend(ctx context.Context, id, adminID string) error {
	result, err := r.db.Exec(ctx,
		`UPDATE venues
		 SET status = 'pending',
		     approved_by = NULL,
		     verified_at = NULL,
		     rejection_note = NULL,
		     updated_at = NOW()
		 WHERE id = $1 AND status IN ('approved', 'rejected') AND deleted_at IS NULL`,
		id,
	)
	if err != nil {
		return fmt.Errorf("mekan askıya alma başarısız: %w", err)
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// Reject — mekanı reddeder: status=rejected, rejection_note güncellenir.
func (r *VenueRepo) Reject(ctx context.Context, id, adminID string, note *string) error {
	result, err := r.db.Exec(ctx,
		`UPDATE venues
		 SET status = 'rejected',
		     approved_by = $1,
		     rejection_note = $2,
		     updated_at = NOW()
		 WHERE id = $3 AND status = 'pending' AND deleted_at IS NULL`,
		adminID, note, id,
	)
	if err != nil {
		return fmt.Errorf("mekan reddetme başarısız: %w", err)
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// ConfirmVenue — başka bir Guide onaylı mekana doğrulama verir.
// confirmation_count artar, >=2 olduğunda is_double_verified=true olur.
// Aynı guide kendi eklediği mekanı veya zaten doğruladığı mekanı tekrar doğrulayamaz.
func (r *VenueRepo) ConfirmVenue(ctx context.Context, venueID, guideID string) error {
	// Mekanı bul ve kontrol et
	var addedBy string
	var status string
	err := r.db.QueryRow(ctx,
		`SELECT added_by, status FROM venues WHERE id = $1 AND deleted_at IS NULL`,
		venueID,
	).Scan(&addedBy, &status)
	if errors.Is(err, pgx.ErrNoRows) {
		return ErrNotFound
	}
	if err != nil {
		return err
	}
	if status != "approved" {
		return fmt.Errorf("yalnızca onaylı mekanlar doğrulanabilir")
	}
	if addedBy == guideID {
		return fmt.Errorf("kendi eklediğiniz mekanı doğrulayamazsınız")
	}

	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx) //nolint

	// Tekrar doğrulama kontrolü
	var alreadyConfirmed bool
	_ = tx.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM venue_confirmations WHERE venue_id = $1 AND guide_id = $2)`,
		venueID, guideID,
	).Scan(&alreadyConfirmed)
	if alreadyConfirmed {
		return fmt.Errorf("bu mekanı zaten doğrulamışsınız")
	}

	// Doğrulama kaydını ekle
	if _, err := tx.Exec(ctx,
		`INSERT INTO venue_confirmations (venue_id, guide_id) VALUES ($1, $2)`,
		venueID, guideID,
	); err != nil {
		return fmt.Errorf("doğrulama kaydı eklenemedi: %w", err)
	}

	// confirmation_count artır ve is_double_verified güncelle
	if _, err := tx.Exec(ctx,
		`UPDATE venues
		 SET confirmation_count = confirmation_count + 1,
		     is_double_verified = CASE WHEN confirmation_count + 1 >= 2 THEN true ELSE false END,
		     verified_at = NOW(),
		     updated_at = NOW()
		 WHERE id = $1`,
		venueID,
	); err != nil {
		return fmt.Errorf("doğrulama güncellemesi başarısız: %w", err)
	}

	return tx.Commit(ctx)
}
