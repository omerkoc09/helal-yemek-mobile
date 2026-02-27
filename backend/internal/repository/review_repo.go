package repository

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/omerkoc/caiz-mi/internal/models"
)

type ReviewRepo struct {
	db *pgxpool.Pool
}

func NewReviewRepo(db *pgxpool.Pool) *ReviewRepo {
	return &ReviewRepo{db: db}
}

func (r *ReviewRepo) ListByVenue(ctx context.Context, venueID string) ([]models.Review, error) {
	rows, err := r.db.Query(ctx,
		`SELECT id, venue_id, user_id, rating, comment, created_at, updated_at
		 FROM reviews WHERE venue_id = $1 ORDER BY created_at DESC`,
		venueID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []models.Review
	for rows.Next() {
		rv := models.Review{}
		if err := rows.Scan(&rv.ID, &rv.VenueID, &rv.UserID, &rv.Rating, &rv.Comment, &rv.CreatedAt, &rv.UpdatedAt); err != nil {
			return nil, err
		}
		list = append(list, rv)
	}
	if list == nil {
		list = []models.Review{}
	}
	return list, rows.Err()
}

func (r *ReviewRepo) Create(ctx context.Context, rv *models.Review) error {
	return r.db.QueryRow(ctx,
		`INSERT INTO reviews (venue_id, user_id, rating, comment)
		 VALUES ($1, $2, $3, $4)
		 RETURNING id, created_at, updated_at`,
		rv.VenueID, rv.UserID, rv.Rating, rv.Comment,
	).Scan(&rv.ID, &rv.CreatedAt, &rv.UpdatedAt)
}

func (r *ReviewRepo) FindByID(ctx context.Context, id string) (*models.Review, error) {
	rv := &models.Review{}
	err := r.db.QueryRow(ctx,
		`SELECT id, venue_id, user_id, rating, comment, created_at, updated_at
		 FROM reviews WHERE id = $1`,
		id,
	).Scan(&rv.ID, &rv.VenueID, &rv.UserID, &rv.Rating, &rv.Comment, &rv.CreatedAt, &rv.UpdatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	return rv, err
}

func (r *ReviewRepo) Update(ctx context.Context, rv *models.Review) error {
	result, err := r.db.Exec(ctx,
		`UPDATE reviews SET rating = $1, comment = $2, updated_at = NOW()
		 WHERE id = $3 AND user_id = $4`,
		rv.Rating, rv.Comment, rv.ID, rv.UserID,
	)
	if err != nil {
		return err
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// Delete — admin ise user_id kontrolü yapmaz.
func (r *ReviewRepo) Delete(ctx context.Context, id, userID string, isAdmin bool) error {
	var err error
	var affected int64
	if isAdmin {
		result, e := r.db.Exec(ctx, `DELETE FROM reviews WHERE id = $1`, id)
		err = e
		if e == nil {
			affected = result.RowsAffected()
		}
	} else {
		result, e := r.db.Exec(ctx, `DELETE FROM reviews WHERE id = $1 AND user_id = $2`, id, userID)
		err = e
		if e == nil {
			affected = result.RowsAffected()
		}
	}
	if err != nil {
		return err
	}
	if affected == 0 {
		return ErrNotFound
	}
	return nil
}
