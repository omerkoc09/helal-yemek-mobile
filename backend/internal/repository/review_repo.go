package repository

import (
	"context"
	"errors"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/omerkoc/caiz-mi/internal/models"
)

type ReviewRepo struct {
	db *pgxpool.Pool
}

type ReviewWithVenue struct {
	models.Review
	VenueName string `json:"venue_name"`
}

func NewReviewRepo(db *pgxpool.Pool) *ReviewRepo {
	return &ReviewRepo{db: db}
}

func (r *ReviewRepo) ListByVenue(ctx context.Context, venueID string) ([]models.Review, error) {
	rows, err := r.db.Query(ctx,
		`SELECT r.id, r.venue_id, r.user_id, r.rating, r.comment, r.created_at, r.updated_at,
		        u.name, u.surname, u.avatar_url
		 FROM reviews r
		 LEFT JOIN users u ON u.id = r.user_id
		 WHERE r.venue_id = $1
		 ORDER BY r.created_at DESC`,
		venueID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []models.Review
	for rows.Next() {
		rv := models.Review{}
		var name, surname, avatar *string
		if err := rows.Scan(&rv.ID, &rv.VenueID, &rv.UserID, &rv.Rating, &rv.Comment,
			&rv.CreatedAt, &rv.UpdatedAt, &name, &surname, &avatar); err != nil {
			return nil, err
		}
		display := displayName(name, surname)
		rv.UserName = &display
		rv.UserAvatar = avatar
		list = append(list, rv)
	}
	if list == nil {
		list = []models.Review{}
	}
	return list, rows.Err()
}

// displayName — "Ad S." formatında görünen ad üretir. Ad boşsa "Kullanıcı" döner.
func displayName(name, surname *string) string {
	n := ""
	if name != nil {
		n = strings.TrimSpace(*name)
	}
	if n == "" {
		return "Kullanıcı"
	}
	s := ""
	if surname != nil {
		s = strings.TrimSpace(*surname)
	}
	if s == "" {
		return n
	}
	initial := []rune(s)[0]
	return n + " " + strings.ToUpper(string(initial)) + "."
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

// FindByUserID — kullanıcının yazdığı yorumları mekan adıyla birlikte döner.
func (r *ReviewRepo) FindByUserID(ctx context.Context, userID string) ([]ReviewWithVenue, error) {
	rows, err := r.db.Query(ctx,
		`SELECT r.id, r.venue_id, r.user_id, r.rating, r.comment, r.created_at, r.updated_at,
		        v.name
		 FROM reviews r
		 LEFT JOIN venues v ON v.id = r.venue_id
		 WHERE r.user_id = $1
		 ORDER BY r.created_at DESC`,
		userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []ReviewWithVenue
	for rows.Next() {
		var rv ReviewWithVenue
		if err := rows.Scan(
			&rv.ID, &rv.VenueID, &rv.UserID, &rv.Rating, &rv.Comment,
			&rv.CreatedAt, &rv.UpdatedAt, &rv.VenueName,
		); err != nil {
			return nil, err
		}
		list = append(list, rv)
	}
	if list == nil {
		list = []ReviewWithVenue{}
	}
	return list, rows.Err()
}
