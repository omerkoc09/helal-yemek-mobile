package repository

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/omerkoc/caiz-mi/internal/models"
)

type VerificationLogRepo struct {
	db *pgxpool.Pool
}

func NewVerificationLogRepo(db *pgxpool.Pool) *VerificationLogRepo {
	return &VerificationLogRepo{db: db}
}

func (r *VerificationLogRepo) Create(ctx context.Context, venueID, guideID, action string) error {
	_, err := r.db.Exec(ctx,
		`INSERT INTO venue_verification_logs (venue_id, guide_id, action) VALUES ($1, $2, $3)`,
		venueID, guideID, action,
	)
	return err
}

// ListVerified — son doğrulanan mekanlar (action='verified')
func (r *VerificationLogRepo) ListVerified(ctx context.Context, limit, offset int) ([]*models.VerificationLog, error) {
	return r.queryLogs(ctx,
		`SELECT vl.id, vl.venue_id, v.name, vl.guide_id, u.name, v.city, vl.action, vl.created_at
		 FROM venue_verification_logs vl
		 JOIN venues v ON v.id = vl.venue_id
		 JOIN users u ON u.id = vl.guide_id
		 WHERE vl.action = 'verified'
		 ORDER BY vl.created_at DESC
		 LIMIT $1 OFFSET $2`,
		limit, offset,
	)
}

// ListSuspended — askıdaki mekanlar
func (r *VerificationLogRepo) ListSuspended(ctx context.Context) ([]*models.VerificationLog, error) {
	rows, err := r.db.Query(ctx,
		`SELECT
		   COALESCE(vl.id::text, ''),
		   v.id::text,
		   v.name,
		   COALESCE(vl.guide_id::text, ''),
		   u.name,
		   v.city,
		   COALESCE(vl.action, ''),
		   COALESCE(vl.created_at, v.updated_at)
		 FROM venues v
		 JOIN users u ON u.id = v.added_by
		 LEFT JOIN LATERAL (
		   SELECT id, guide_id, action, created_at
		   FROM venue_verification_logs
		   WHERE venue_id = v.id
		   ORDER BY created_at DESC
		   LIMIT 1
		 ) vl ON true
		 WHERE v.status = 'suspended'
		   AND v.deleted_at IS NULL
		 ORDER BY v.updated_at DESC`,
	)
	if err != nil {
		return nil, fmt.Errorf("askıdaki mekanlar listelenemedi: %w", err)
	}
	defer rows.Close()
	return scanLogs(rows)
}

// ListWarningsSent — scheduler'ın gönderdiği uyarı bildirimleri
func (r *VerificationLogRepo) ListWarningsSent(ctx context.Context, limit, offset int) ([]*models.VerificationLog, error) {
	return r.queryLogs(ctx,
		`SELECT vl.id, vl.venue_id, v.name, vl.guide_id, u.name, v.city, vl.action, vl.created_at
		 FROM venue_verification_logs vl
		 JOIN venues v ON v.id = vl.venue_id
		 JOIN users u ON u.id = vl.guide_id
		 WHERE vl.action = 'warning_sent'
		 ORDER BY vl.created_at DESC
		 LIMIT $1 OFFSET $2`,
		limit, offset,
	)
}

// ListUpcoming — yaklaşan süresi bitenler (sonraki X gün içinde)
func (r *VerificationLogRepo) ListUpcoming(ctx context.Context, withinDays int) ([]*models.VerificationLog, error) {
	rows, err := r.db.Query(ctx,
		`SELECT
		   COALESCE(vl.id::text, ''),
		   v.id::text,
		   v.name,
		   COALESCE(vl.guide_id::text, ''),
		   u.name,
		   v.city,
		   COALESCE(vl.action, ''),
		   COALESCE(vl.created_at, v.updated_at)
		 FROM venues v
		 JOIN users u ON u.id = v.added_by
		 LEFT JOIN LATERAL (
		   SELECT id, guide_id, action, created_at
		   FROM venue_verification_logs
		   WHERE venue_id = v.id
		   ORDER BY created_at DESC
		   LIMIT 1
		 ) vl ON true
		 WHERE v.status = 'approved'
		   AND v.verification_due_at < NOW() + ($1 * INTERVAL '1 day')
		   AND v.verification_due_at > NOW()
		 ORDER BY v.verification_due_at ASC`,
		withinDays,
	)
	if err != nil {
		return nil, fmt.Errorf("yaklaşan doğrulamalar listelenemedi: %w", err)
	}
	defer rows.Close()
	return scanLogs(rows)
}

// ListByVenue — belirli bir mekanın tüm doğrulama/uyarı geçmişi (en yeni önce).
func (r *VerificationLogRepo) ListByVenue(ctx context.Context, venueID string) ([]*models.VerificationLog, error) {
	return r.queryLogs(ctx,
		`SELECT vl.id, vl.venue_id, v.name, vl.guide_id, u.name, v.city, vl.action, vl.created_at
		 FROM venue_verification_logs vl
		 JOIN venues v ON v.id = vl.venue_id
		 JOIN users u ON u.id = vl.guide_id
		 WHERE vl.venue_id = $1
		 ORDER BY vl.created_at DESC`,
		venueID,
	)
}

func (r *VerificationLogRepo) queryLogs(ctx context.Context, query string, args ...any) ([]*models.VerificationLog, error) {
	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("log sorgusu başarısız: %w", err)
	}
	defer rows.Close()
	return scanLogs(rows)
}

func scanLogs(rows interface {
	Next() bool
	Scan(...any) error
	Err() error
}) ([]*models.VerificationLog, error) {
	var result []*models.VerificationLog
	for rows.Next() {
		l := &models.VerificationLog{}
		if err := rows.Scan(&l.ID, &l.VenueID, &l.VenueName, &l.GuideID, &l.GuideName, &l.City, &l.Action, &l.CreatedAt); err != nil {
			return nil, err
		}
		result = append(result, l)
	}
	return result, rows.Err()
}
