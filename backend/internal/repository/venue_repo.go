package repository

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/omerkoc/caiz-mi/internal/models"
)

type VenueRepo struct {
	db *pgxpool.Pool
}

func NewVenueRepo(db *pgxpool.Pool) *VenueRepo {
	return &VenueRepo{db: db}
}

// FindByID — mekan detayını kriterleri ve fotoğraflarıyla birlikte döndürür.
func (r *VenueRepo) FindByID(ctx context.Context, id string) (*models.Venue, error) {
	query := `
		SELECT
			v.id, v.name, v.city,
			ST_Y(v.location::geometry) AS latitude,
			ST_X(v.location::geometry) AS longitude,
			v.google_place_id,
			v.notes, v.status,
			v.added_by, u.name AS added_by_name, v.verified_at, v.verification_due_at,
			v.created_at, v.updated_at,
			v.rejection_note, v.approved_by,
			v.food_halal_mode, v.excluded_products,
			COALESCE(AVG(rv.rating), 0)::float8 AS average_rating,
			COUNT(rv.id)::int AS review_count
		FROM venues v
		LEFT JOIN users u ON u.id = v.added_by
		LEFT JOIN reviews rv ON rv.venue_id = v.id
		WHERE v.id = $1 AND v.deleted_at IS NULL
		GROUP BY v.id, u.name`

	v := &models.Venue{}

	err := r.db.QueryRow(ctx, query, id).Scan(
		&v.ID, &v.Name, &v.City,
		&v.Latitude, &v.Longitude,
		&v.GooglePlaceID,
		&v.Notes, &v.Status,
		&v.AddedBy, &v.AddedByName, &v.VerifiedAt, &v.VerificationDueAt,
		&v.CreatedAt, &v.UpdatedAt,
		&v.RejectionNote, &v.ApprovedBy,
		&v.FoodHalalMode, &v.ExcludedProducts,
		&v.AverageRating, &v.ReviewCount,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("mekan detayı sorgusu başarısız: %w", err)
	}

	// Kriterleri yükle
	criteria, err := r.GetCriteriaByVenueID(ctx, id)
	if err != nil {
		return nil, err
	}
	v.Criteria = criteria

	// Fotoğrafları yükle
	photos, err := r.GetPhotosByVenueID(ctx, id)
	if err != nil {
		return nil, err
	}
	v.Photos = photos

	// Yemek çeşitlerini yükle
	foodItems, err := r.GetFoodItemsByVenueID(ctx, id)
	if err != nil {
		return nil, err
	}
	v.FoodItems = foodItems

	return v, nil
}

// Create — yeni mekan ekler, ID ve timestamp'leri geri doldurur.
func (r *VenueRepo) Create(ctx context.Context, v *models.Venue) error {
	query := `
		INSERT INTO venues (name, city, district, location, google_place_id, notes, added_by, food_halal_mode, excluded_products)
		VALUES ($1, $2, $3, ST_MakePoint($5, $4)::geography, $6, $7, $8, $9, $10)
		RETURNING id, status, created_at, updated_at`
	// ST_MakePoint(lng, lat) — PostGIS koordinat sırası: X=lng, Y=lat

	if v.ExcludedProducts == nil {
		v.ExcludedProducts = []string{}
	}

	err := r.db.QueryRow(ctx, query,
		v.Name, v.City, v.District,
		v.Latitude, v.Longitude,
		v.GooglePlaceID,
		v.Notes, v.AddedBy, v.FoodHalalMode, v.ExcludedProducts,
	).Scan(&v.ID, &v.Status, &v.CreatedAt, &v.UpdatedAt)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return ErrAlreadyExists
		}
		return err
	}
	return nil
}

// UpdateVenue — mekanın temel alanlarını günceller. nil olan alanlar değiştirilmez.
func (r *VenueRepo) UpdateVenue(ctx context.Context, id string,
	name, city, district *string,
	lat, lng *float64,
	notes *string,
	googlePlaceID *string,
) error {
	query := `
		UPDATE venues SET
			name            = COALESCE($2, name),
			city            = COALESCE($3, city),
			district        = COALESCE($4, district),
			location        = CASE WHEN $5::float8 IS NOT NULL AND $6::float8 IS NOT NULL
			                       THEN ST_MakePoint($6, $5)::geography
			                       ELSE location END,
			notes           = COALESCE($7, notes),
			google_place_id = COALESCE($8, google_place_id),
			updated_at      = NOW()
		WHERE id = $1 AND deleted_at IS NULL`

	result, err := r.db.Exec(ctx, query, id, name, city, district, lat, lng, notes, googlePlaceID)
	if err != nil {
		return fmt.Errorf("mekan güncellemesi başarısız: %w", err)
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// SoftDelete — mekanı soft-delete yapar.
func (r *VenueRepo) SoftDelete(ctx context.Context, id string) error {
	result, err := r.db.Exec(ctx,
		`UPDATE venues SET deleted_at = NOW(), updated_at = NOW() WHERE id = $1 AND deleted_at IS NULL`,
		id,
	)
	if err != nil {
		return fmt.Errorf("mekan silme başarısız: %w", err)
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}
