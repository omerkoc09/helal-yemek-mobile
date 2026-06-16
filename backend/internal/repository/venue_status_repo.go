package repository

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/omerkoc/caiz-mi/internal/models"
)

// Approve — mekanı onaylar ve ilk doğrulama süresini başlatır.
func (r *VenueRepo) Approve(ctx context.Context, id, adminID string, periodDays int) error {
	result, err := r.db.Exec(ctx,
		`UPDATE venues
		 SET status = 'approved',
		     approved_by = $1,
		     verified_at = NOW(),
		     verification_due_at = NOW() + ($3 * INTERVAL '1 day'),
		     updated_at = NOW()
		 WHERE id = $2 AND status IN ('pending', 'rejected') AND deleted_at IS NULL`,
		adminID, id, periodDays,
	)
	if err != nil {
		return fmt.Errorf("mekan onaylama başarısız: %w", err)
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// SetStatus — admin düzenleme modalı için kaynak duruma bakmadan mekanın
// statüsünü doğrudan ayarlar ve her hedef duruma uygun yan-etki sütunlarını
// (approved_by, verified_at, verification_due_at, rejection_note) tutarlı hale
// getirir. Durum-geçiş kuralı olan akışlar (scheduler, guide doğrulaması) için
// Approve/Reject/Suspend kullanılmaya devam edilmeli; bu fonksiyon yalnızca
// adminin tam yetkili manuel düzenlemesi içindir.
func (r *VenueRepo) SetStatus(ctx context.Context, id string, status models.VenueStatus, adminID string, note *string, periodDays int) error {
	// Her hedef durum farklı yan-etki sütunlarını ve argüman setini gerektirdiği
	// için sorgu ve argümanlar burada seçilir; ortak çalıştırma/sonuç kontrolü
	// switch sonrasında tek noktada yapılır.
	var (
		query string
		args  []any
	)

	switch status {
	case models.VenueStatusApproved:
		query = `UPDATE venues
			 SET status = 'approved', approved_by = $1, verified_at = NOW(),
			     verification_due_at = NOW() + ($3 * INTERVAL '1 day'),
			     rejection_note = NULL, updated_at = NOW()
			 WHERE id = $2 AND deleted_at IS NULL`
		args = []any{adminID, id, periodDays}
	case models.VenueStatusRejected:
		query = `UPDATE venues
			 SET status = 'rejected', approved_by = $1, rejection_note = $2,
			     verified_at = NULL, verification_due_at = NULL, updated_at = NOW()
			 WHERE id = $3 AND deleted_at IS NULL`
		args = []any{adminID, note, id}
	case models.VenueStatusPending:
		query = `UPDATE venues
			 SET status = 'pending', approved_by = NULL, verified_at = NULL,
			     verification_due_at = NULL, rejection_note = NULL, updated_at = NOW()
			 WHERE id = $1 AND deleted_at IS NULL`
		args = []any{id}
	case models.VenueStatusSuspended:
		query = `UPDATE venues
			 SET status = 'suspended', verification_due_at = NULL, updated_at = NOW()
			 WHERE id = $1 AND deleted_at IS NULL`
		args = []any{id}
	default:
		return fmt.Errorf("geçersiz mekan durumu: %s", status)
	}

	result, err := r.db.Exec(ctx, query, args...)
	if err != nil {
		return fmt.Errorf("mekan durumu güncellenemedi: %w", err)
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// Suspend — onaylı veya reddedilmiş mekanı tekrar pending durumuna alır.
// TODO: dead code silebilirsin kullanmayacaksan buton olarak falan
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

// SuspendForVerification — doğrulama yapılmadığı için mekânı askıya alır.
func (r *VenueRepo) SuspendForVerification(ctx context.Context, id string) error {
	result, err := r.db.Exec(ctx,
		`UPDATE venues
		 SET status = 'suspended',
		     updated_at = NOW()
		 WHERE id = $1 AND status = 'approved' AND deleted_at IS NULL`,
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

// VerifyByGuide — rehberin kendi mekanını doğrulaması.
// Sadece mekan sahibi guide çağırabilir.
func (r *VenueRepo) VerifyByGuide(ctx context.Context, venueID, guideID string, periodDays int) error {
	result, err := r.db.Exec(ctx,
		`UPDATE venues
		 SET verified_at = NOW(),
		     verification_due_at = NOW() + ($3 * INTERVAL '1 day'),
		     status = 'approved',
		     updated_at = NOW()
		 WHERE id = $1
		   AND added_by = $2
		   AND status IN ('approved', 'suspended')
		   AND deleted_at IS NULL`,
		venueID, guideID, periodDays,
	)
	if err != nil {
		return fmt.Errorf("mekan doğrulama başarısız: %w", err)
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// ReactivateVenue — admin'in suspended mekânı manuel olarak yeniden açması.
func (r *VenueRepo) ReactivateVenue(ctx context.Context, id string, periodDays int) error {
	result, err := r.db.Exec(ctx,
		`UPDATE venues
		 SET status = 'approved',
		     verified_at = NOW(),
		     verification_due_at = NOW() + ($2 * INTERVAL '1 day'),
		     updated_at = NOW()
		 WHERE id = $1 AND status = 'suspended' AND deleted_at IS NULL`,
		id, periodDays,
	)
	if err != nil {
		return fmt.Errorf("mekan yeniden aktive edilemedi: %w", err)
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// ResetToPending — onaylı mekanın statüsünü pending'e düşürür (guide düzenlemesi sonrası).
func (r *VenueRepo) ResetToPending(ctx context.Context, id string) error {
	result, err := r.db.Exec(ctx,
		`UPDATE venues
		 SET status = 'pending',
		     updated_at = NOW()
		 WHERE id = $1 AND status = 'approved' AND deleted_at IS NULL`,
		id,
	)
	if err != nil {
		return fmt.Errorf("mekan statü sıfırlama başarısız: %w", err)
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// ConfirmVenue — başka bir Guide onaylı mekana doğrulama verir.
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

	// Doğrulama tarihini güncelle
	if _, err := tx.Exec(ctx,
		`UPDATE venues
		 SET verified_at = NOW(),
		     updated_at = NOW()
		 WHERE id = $1`,
		venueID,
	); err != nil {
		return fmt.Errorf("doğrulama güncellemesi başarısız: %w", err)
	}

	return tx.Commit(ctx)
}

// FindDueForWarning — verilen gün sayısı içinde süresi dolacak ve henüz bugün bildirilmemiş mekanlar.
func (r *VenueRepo) FindDueForWarning(ctx context.Context, withinDays int) ([]*models.VenueForScheduler, error) {
	rows, err := r.db.Query(ctx,
		`SELECT v.id, v.name, v.added_by, u.email, u.name, v.verification_due_at
		 FROM venues v
		 JOIN users u ON u.id = v.added_by
		 WHERE v.status = 'approved'
		   AND v.verification_due_at < NOW() + ($1 * INTERVAL '1 day')
		   AND v.verification_due_at > NOW()
		   AND (v.last_notified_at IS NULL OR v.last_notified_at < NOW() - INTERVAL '1 day')`,
		withinDays,
	)
	if err != nil {
		return nil, fmt.Errorf("uyarı listesi alınamadı: %w", err)
	}
	defer rows.Close()
	return scanVenuesForScheduler(rows)
}

// FindDueForSuspension — süresi dolmuş approved mekanlar.
func (r *VenueRepo) FindDueForSuspension(ctx context.Context) ([]*models.VenueForScheduler, error) {
	rows, err := r.db.Query(ctx,
		`SELECT v.id, v.name, v.added_by, u.email, u.name, v.verification_due_at
		 FROM venues v
		 JOIN users u ON u.id = v.added_by
		 WHERE v.status = 'approved'
		   AND v.verification_due_at < NOW()`,
	)
	if err != nil {
		return nil, fmt.Errorf("askıya alınacaklar listesi alınamadı: %w", err)
	}
	defer rows.Close()
	return scanVenuesForScheduler(rows)
}

// UpdateLastNotified — spam önleme: son bildirim zamanını günceller.
func (r *VenueRepo) UpdateLastNotified(ctx context.Context, id string) error {
	_, err := r.db.Exec(ctx,
		`UPDATE venues SET last_notified_at = NOW() WHERE id = $1`,
		id,
	)
	return err
}

func scanVenuesForScheduler(rows interface {
	Next() bool
	Scan(...any) error
	Err() error
}) ([]*models.VenueForScheduler, error) {
	var result []*models.VenueForScheduler
	for rows.Next() {
		v := &models.VenueForScheduler{}
		if err := rows.Scan(&v.ID, &v.Name, &v.AddedBy, &v.GuideEmail, &v.GuideName, &v.VerificationDueAt); err != nil {
			return nil, err
		}
		result = append(result, v)
	}
	return result, rows.Err()
}
