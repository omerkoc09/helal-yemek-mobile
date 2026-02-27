package repository

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
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
			v.id, v.name, v.address, v.city, v.country,
			ST_Y(v.location::geometry) AS latitude,
			ST_X(v.location::geometry) AS longitude,
			v.working_hours, v.notes, v.status,
			v.added_by, v.verified_at, v.confirmation_count, v.is_double_verified,
			v.created_at, v.updated_at,
			v.rejection_note, v.approved_by,
			v.all_food_halal,
			COALESCE(AVG(rv.rating), 0)::float8 AS average_rating,
			COUNT(rv.id)::int AS review_count
		FROM venues v
		LEFT JOIN reviews rv ON rv.venue_id = v.id
		WHERE v.id = $1 AND v.deleted_at IS NULL
		GROUP BY v.id`

	v := &models.Venue{}
	var whJSON []byte

	err := r.db.QueryRow(ctx, query, id).Scan(
		&v.ID, &v.Name, &v.Address, &v.City, &v.Country,
		&v.Latitude, &v.Longitude,
		&whJSON, &v.Notes, &v.Status,
		&v.AddedBy, &v.VerifiedAt, &v.ConfirmationCount, &v.IsDoubleVerified,
		&v.CreatedAt, &v.UpdatedAt,
		&v.RejectionNote, &v.ApprovedBy,
		&v.AllFoodHalal,
		&v.AverageRating, &v.ReviewCount,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("mekan detayı sorgusu başarısız: %w", err)
	}
	if whJSON != nil {
		_ = json.Unmarshal(whJSON, &v.WorkingHours)
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
	whJSON, _ := json.Marshal(v.WorkingHours)

	query := `
		INSERT INTO venues (name, address, city, country, location, working_hours, notes, added_by, all_food_halal)
		VALUES ($1, $2, $3, $4, ST_MakePoint($6, $5)::geography, $7, $8, $9, $10)
		RETURNING id, status, confirmation_count, is_double_verified, created_at, updated_at`
	// ST_MakePoint(lng, lat) — PostGIS koordinat sırası: X=lng, Y=lat

	return r.db.QueryRow(ctx, query,
		v.Name, v.Address, v.City, v.Country,
		v.Latitude, v.Longitude,
		whJSON, v.Notes, v.AddedBy, v.AllFoodHalal,
	).Scan(&v.ID, &v.Status, &v.ConfirmationCount, &v.IsDoubleVerified, &v.CreatedAt, &v.UpdatedAt)
}

// UpdateVenue — mekanın temel alanlarını günceller. nil olan alanlar değiştirilmez.
func (r *VenueRepo) UpdateVenue(ctx context.Context, id string,
	name, address, city, country *string,
	lat, lng *float64,
	wh *models.WorkingHours,
	notes *string,
) error {
	query := `
		UPDATE venues SET
			name           = COALESCE($2, name),
			address        = COALESCE($3, address),
			city           = COALESCE($4, city),
			country        = COALESCE($5, country),
			location       = CASE WHEN $6::float8 IS NOT NULL AND $7::float8 IS NOT NULL
			                      THEN ST_MakePoint($7, $6)::geography
			                      ELSE location END,
			working_hours  = CASE WHEN $8::jsonb IS NOT NULL THEN $8 ELSE working_hours END,
			notes          = COALESCE($9, notes),
			updated_at     = NOW()
		WHERE id = $1 AND deleted_at IS NULL`

	var whJSON []byte
	if wh != nil {
		whJSON, _ = json.Marshal(wh)
	}

	result, err := r.db.Exec(ctx, query, id, name, address, city, country, lat, lng, whJSON, notes)
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
