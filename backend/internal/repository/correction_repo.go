package repository

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/omerkoc/itimat-mobile/internal/models"
)

type CorrectionRepo struct {
	db *pgxpool.Pool
}

func NewCorrectionRepo(db *pgxpool.Pool) *CorrectionRepo {
	return &CorrectionRepo{db: db}
}

func (r *CorrectionRepo) Create(ctx context.Context, cs *models.CorrectionSuggestion) error {
	return r.db.QueryRow(ctx,
		`INSERT INTO correction_suggestions (venue_id, suggested_by, field_name, old_value, new_value)
		 VALUES ($1, $2, $3, $4, $5)
		 RETURNING id, created_at`,
		cs.VenueID, cs.SuggestedBy, cs.FieldName, cs.OldValue, cs.NewValue,
	).Scan(&cs.ID, &cs.CreatedAt)
}

func (r *CorrectionRepo) ListPending(ctx context.Context) ([]models.CorrectionSuggestion, error) {
	rows, err := r.db.Query(ctx,
		`SELECT id, venue_id, suggested_by, field_name, old_value, new_value,
		        status, reviewed_by, reviewed_at, note, created_at
		 FROM correction_suggestions
		 WHERE status = 'pending'
		 ORDER BY created_at`,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanCorrectionRows(rows)
}

func (r *CorrectionRepo) FindByID(ctx context.Context, id string) (*models.CorrectionSuggestion, error) {
	cs := &models.CorrectionSuggestion{}
	err := r.db.QueryRow(ctx,
		`SELECT id, venue_id, suggested_by, field_name, old_value, new_value,
		        status, reviewed_by, reviewed_at, note, created_at
		 FROM correction_suggestions WHERE id = $1`,
		id,
	).Scan(
		&cs.ID, &cs.VenueID, &cs.SuggestedBy, &cs.FieldName, &cs.OldValue, &cs.NewValue,
		&cs.Status, &cs.ReviewedBy, &cs.ReviewedAt, &cs.Note, &cs.CreatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	return cs, err
}

// UpdateStatus — düzeltme önerisinin durumunu günceller (admin işlemi).
func (r *CorrectionRepo) UpdateStatus(ctx context.Context, id, adminID string, status models.CorrectionStatus, note *string) error {
	result, err := r.db.Exec(ctx,
		`UPDATE correction_suggestions
		 SET status = $1, reviewed_by = $2, reviewed_at = NOW(), note = $3
		 WHERE id = $4 AND status = 'pending'`,
		status, adminID, note, id,
	)
	if err != nil {
		return err
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func scanCorrectionRows(rows pgx.Rows) ([]models.CorrectionSuggestion, error) {
	var list []models.CorrectionSuggestion
	for rows.Next() {
		cs := models.CorrectionSuggestion{}
		if err := rows.Scan(
			&cs.ID, &cs.VenueID, &cs.SuggestedBy, &cs.FieldName, &cs.OldValue, &cs.NewValue,
			&cs.Status, &cs.ReviewedBy, &cs.ReviewedAt, &cs.Note, &cs.CreatedAt,
		); err != nil {
			return nil, err
		}
		list = append(list, cs)
	}
	if list == nil {
		list = []models.CorrectionSuggestion{}
	}
	return list, rows.Err()
}
