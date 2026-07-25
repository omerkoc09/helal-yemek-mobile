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

// VerifyByGuide — bir rehber (ekleyen VEYA daha önce bu mekanı doğrulamış biri)
// mekanı yeniden doğrular: süreyi uzatır, suspended ise approved yapar.
// Dönem sıfırlama YOK — confirmation kayıtları silinmez, rozet türetilir.
func (r *VenueRepo) VerifyByGuide(ctx context.Context, venueID, guideID string, periodDays int) error {
	result, err := r.db.Exec(ctx,
		`UPDATE venues v
		 SET verified_at = NOW(),
		     verification_due_at = NOW() + ($3 * INTERVAL '1 day'),
		     status = 'approved',
		     updated_at = NOW()
		 WHERE v.id = $1
		   AND (v.added_by = $2 OR EXISTS (
		         SELECT 1 FROM venue_confirmations vc
		         WHERE vc.venue_id = v.id AND vc.guide_id = $2))
		   AND v.status IN ('approved', 'suspended')
		   AND v.deleted_at IS NULL`,
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

// ConfirmVenue — bir Guide onaylı mekana dönemsel doğrulama verir. Mekanı
// ekleyen Guide de dahil (ownerless doğrulama modeli): confirmation_count
// artık türetilmiş bir değerdir (FreshConfirmationCount ile senkron).
// guideCity boşsa şehir kontrolü atlanır (admin / belirsizlik).
func (r *VenueRepo) ConfirmVenue(ctx context.Context, venueID, guideID, guideCity string, periodDays int) error {
	var status string
	var venueCity string
	err := r.db.QueryRow(ctx,
		`SELECT status, city FROM venues WHERE id = $1 AND deleted_at IS NULL`,
		venueID,
	).Scan(&status, &venueCity)
	if errors.Is(err, pgx.ErrNoRows) {
		return ErrNotFound
	}
	if err != nil {
		return err
	}
	if status != "approved" {
		return fmt.Errorf("yalnızca onaylı mekanlar doğrulanabilir")
	}
	if guideCity != "" {
		venueCanonical, vOK := models.NormalizeCity(venueCity)
		guideCanonical, gOK := models.NormalizeCity(guideCity)
		if vOK && gOK && venueCanonical != guideCanonical {
			return fmt.Errorf("yalnızca rehberi olduğunuz şehirdeki mekanı doğrulayabilirsiniz")
		}
	}

	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx) //nolint

	var alreadyConfirmed bool
	_ = tx.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM venue_confirmations WHERE venue_id = $1 AND guide_id = $2)`,
		venueID, guideID,
	).Scan(&alreadyConfirmed)
	if alreadyConfirmed {
		return fmt.Errorf("bu mekanı zaten doğrulamışsınız")
	}

	if _, err := tx.Exec(ctx,
		`INSERT INTO venue_confirmations (venue_id, guide_id, period_start) VALUES ($1, $2, NOW())`,
		venueID, guideID,
	); err != nil {
		return fmt.Errorf("doğrulama kaydı eklenemedi: %w", err)
	}

	// Türetilmiş taze sayı: bu tx içinde eklenen kayıt dahil son periyottaki
	// farklı doğrulayan sayısı (FreshConfirmationCount ile aynı mantık, tx içinde).
	var fresh int
	if err := tx.QueryRow(ctx,
		`SELECT COUNT(DISTINCT guide_id) FROM venue_confirmations
		 WHERE venue_id = $1 AND created_at > NOW() - ($2 * INTERVAL '1 day')`,
		venueID, periodDays,
	).Scan(&fresh); err != nil {
		return fmt.Errorf("taze sayı hesaplanamadı: %w", err)
	}

	if _, err := tx.Exec(ctx,
		`UPDATE venues
		 SET confirmation_count = $2,
		     verified_at = NOW(),
		     updated_at = NOW()
		 WHERE id = $1`,
		venueID, fresh,
	); err != nil {
		return fmt.Errorf("doğrulama güncellemesi başarısız: %w", err)
	}

	return tx.Commit(ctx)
}

// FindDueForWarning — verilen gün sayısı içinde süresi dolacak ve henüz bugün bildirilmemiş mekanlar.
// Her mekanın Recipients'ı ekleyen ∪ son periyottaki doğrulayanlarla doldurulur.
func (r *VenueRepo) FindDueForWarning(ctx context.Context, withinDays, periodDays int) ([]*models.VenueForScheduler, error) {
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
	venues, err := scanVenuesForScheduler(rows)
	rows.Close()
	if err != nil {
		return nil, err
	}
	return r.attachRecipients(ctx, venues, periodDays)
}

// FindDueForSuspension — süresi dolmuş approved mekanlar.
// Her mekanın Recipients'ı ekleyen ∪ son periyottaki doğrulayanlarla doldurulur.
func (r *VenueRepo) FindDueForSuspension(ctx context.Context, periodDays int) ([]*models.VenueForScheduler, error) {
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
	venues, err := scanVenuesForScheduler(rows)
	rows.Close()
	if err != nil {
		return nil, err
	}
	return r.attachRecipients(ctx, venues, periodDays)
}

// attachRecipients — her mekan için alıcı listesini doldurur (N+1 kabul edilebilir;
// scheduler günde bir çalışır).
func (r *VenueRepo) attachRecipients(ctx context.Context, venues []*models.VenueForScheduler, periodDays int) ([]*models.VenueForScheduler, error) {
	for _, v := range venues {
		recs, err := r.loadRecipients(ctx, v.ID, periodDays)
		if err != nil {
			return nil, err
		}
		v.Recipients = recs
	}
	return venues, nil
}

// loadRecipients — mekanın ekleyeni + son periyottaki doğrulayanlarını döner (DISTINCT).
func (r *VenueRepo) loadRecipients(ctx context.Context, venueID string, periodDays int) ([]models.SchedulerRecipient, error) {
	rows, err := r.db.Query(ctx,
		`SELECT DISTINCT u.id, u.email, u.name
		 FROM users u
		 WHERE u.id = (SELECT added_by FROM venues WHERE id = $1)
		    OR u.id IN (
		         SELECT guide_id FROM venue_confirmations
		         WHERE venue_id = $1
		           AND created_at > NOW() - ($2 * INTERVAL '1 day'))`,
		venueID, periodDays,
	)
	if err != nil {
		return nil, fmt.Errorf("alıcılar alınamadı: %w", err)
	}
	defer rows.Close()
	var recs []models.SchedulerRecipient
	for rows.Next() {
		var rec models.SchedulerRecipient
		if err := rows.Scan(&rec.GuideID, &rec.Email, &rec.Name); err != nil {
			return nil, err
		}
		recs = append(recs, rec)
	}
	return recs, rows.Err()
}

// UpdateLastNotified — spam önleme: son bildirim zamanını günceller.
func (r *VenueRepo) UpdateLastNotified(ctx context.Context, id string) error {
	_, err := r.db.Exec(ctx,
		`UPDATE venues SET last_notified_at = NOW() WHERE id = $1`,
		id,
	)
	return err
}

// FreshConfirmationCount — son periodDays gün içinde bu mekana dönemsel
// doğrulama yapmış farklı rehber sayısı. Rozetin (BadgeFromCount) kaynağı.
// Kayıtlar silinmez; eskiyenler bu pencerenin dışında kaldığı için sayılmaz.
func (r *VenueRepo) FreshConfirmationCount(ctx context.Context, venueID string, periodDays int) (int, error) {
	var n int
	err := r.db.QueryRow(ctx,
		`SELECT COUNT(DISTINCT guide_id)
		 FROM venue_confirmations
		 WHERE venue_id = $1
		   AND created_at > NOW() - ($2 * INTERVAL '1 day')`,
		venueID, periodDays,
	).Scan(&n)
	if err != nil {
		return 0, fmt.Errorf("taze doğrulama sayısı alınamadı: %w", err)
	}
	return n, nil
}

// RecomputeConfirmationCounts — TÜM onaylı (silinmemiş) mekanların
// confirmation_count sütununu, mevcut zaman penceresine göre TEK bir
// set-based UPDATE ile yeniden hesaplar. Rozet (BadgeFromCount) zamanla
// bayatlayabilir: ConfirmVenue anında yazılan sayı, doğrulamalar
// periodDays penceresinin dışına çıktıkça güncel değeri yansıtmaz hale
// gelir. Bu metod nightly scheduler'dan çağrılarak o kaymayı düzeltir.
// verified_at'a DOKUNMAZ — bu bir yeniden doğrulama değildir, sadece
// rozet sayacının tazelenmesidir.
func (r *VenueRepo) RecomputeConfirmationCounts(ctx context.Context, periodDays int) (int64, error) {
	result, err := r.db.Exec(ctx,
		`UPDATE venues v
		 SET confirmation_count = COALESCE((
		         SELECT COUNT(DISTINCT vc.guide_id)
		         FROM venue_confirmations vc
		         WHERE vc.venue_id = v.id
		           AND vc.created_at > NOW() - ($1 * INTERVAL '1 day')
		     ), 0),
		     updated_at = NOW()
		 WHERE v.status = 'approved' AND v.deleted_at IS NULL`,
		periodDays,
	)
	if err != nil {
		return 0, fmt.Errorf("confirmation_count yeniden hesaplama başarısız: %w", err)
	}
	return result.RowsAffected(), nil
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
