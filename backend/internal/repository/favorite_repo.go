package repository

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/omerkoc/caiz-mi/internal/models"
)

type FavoriteRepo struct {
	db *pgxpool.Pool
}

func NewFavoriteRepo(db *pgxpool.Pool) *FavoriteRepo {
	return &FavoriteRepo{db: db}
}

// ListByUser — kullanıcının favori mekanlarını döndürür.
func (r *FavoriteRepo) ListByUser(ctx context.Context, userID string) ([]models.Venue, error) {
	rows, err := r.db.Query(ctx,
		`SELECT v.id, v.name, v.city,
		        ST_Y(v.location::geometry) AS latitude,
		        ST_X(v.location::geometry) AS longitude,
		        v.google_place_id,
		        v.notes, v.status,
		        v.added_by, v.verified_at,
		        v.created_at, v.updated_at
		 FROM favorites f
		 JOIN venues v ON v.id = f.venue_id
		 WHERE f.user_id = $1
		   AND v.deleted_at IS NULL
		 ORDER BY f.created_at DESC`,
		userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanVenueRows(rows, false)
}

// Add — mekana favori ekler; zaten favoriyse sessizce geçer.
func (r *FavoriteRepo) Add(ctx context.Context, userID, venueID string) error {
	_, err := r.db.Exec(ctx,
		`INSERT INTO favorites (user_id, venue_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
		userID, venueID,
	)
	return err
}

// Remove — favoriden çıkarır; bulunamazsa ErrNotFound döner.
func (r *FavoriteRepo) Remove(ctx context.Context, userID, venueID string) error {
	result, err := r.db.Exec(ctx,
		`DELETE FROM favorites WHERE user_id = $1 AND venue_id = $2`,
		userID, venueID,
	)
	if err != nil {
		return err
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}
