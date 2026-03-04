package repository

import (
	"context"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5"

	"github.com/omerkoc/caiz-mi/internal/models"
)

// FindNearby — PostGIS ST_DWithin ile yakındaki onaylı mekanları döndürür.
// $1=lat, $2=lng, $3=radius(metre)
func (r *VenueRepo) FindNearby(ctx context.Context, lat, lng, radiusMeters float64) ([]models.Venue, error) {
	query := `
		SELECT
			v.id, v.name, v.address, v.city,
			ST_Y(v.location::geometry) AS latitude,
			ST_X(v.location::geometry) AS longitude,
			v.notes, v.status,
			v.added_by, v.verified_at,
			v.created_at, v.updated_at,
			ST_Distance(v.location, ST_MakePoint($2, $1)::geography) AS distance
		FROM venues v
		WHERE v.status IN ('approved', 'pending')
		  AND v.deleted_at IS NULL
		  AND ST_DWithin(v.location, ST_MakePoint($2, $1)::geography, $3)
		ORDER BY CASE WHEN v.status = 'approved' THEN 0 ELSE 1 END, distance
		LIMIT 100`

	rows, err := r.db.Query(ctx, query, lat, lng, radiusMeters)
	if err != nil {
		return nil, fmt.Errorf("yakın mekan sorgusu başarısız: %w", err)
	}
	defer rows.Close()

	return r.scanVenueRowsWithPhotos(ctx, rows, true)
}

// escapeILIKE — ILIKE meta-karakterlerini (%_\) escape eder.
func escapeILIKE(s string) string {
	r := strings.NewReplacer(`\`, `\\`, `%`, `\%`, `_`, `\_`)
	return r.Replace(s)
}

// SearchByText — mekan adı, şehir veya adres içinde serbest metin araması yapar.
func (r *VenueRepo) SearchByText(ctx context.Context, query string) ([]models.Venue, error) {
	query = escapeILIKE(query)
	q := `
		SELECT
			v.id, v.name, v.address, v.city,
			ST_Y(v.location::geometry) AS latitude,
			ST_X(v.location::geometry) AS longitude,
			v.notes, v.status,
			v.added_by, v.verified_at,
			v.created_at, v.updated_at
		FROM venues v
		WHERE v.status IN ('approved', 'pending')
		  AND v.deleted_at IS NULL
		  AND (
		    v.name ILIKE '%' || $1 || '%'
		    OR v.city ILIKE '%' || $1 || '%'
		    OR v.address ILIKE '%' || $1 || '%'
		  )
		ORDER BY CASE WHEN v.status = 'approved' THEN 0 ELSE 1 END, v.name
		LIMIT 50`

	rows, err := r.db.Query(ctx, q, query)
	if err != nil {
		return nil, fmt.Errorf("metin arama sorgusu başarısız: %w", err)
	}
	defer rows.Close()

	return r.scanVenueRowsWithPhotos(ctx, rows, false)
}

// FindByCity — şehir adına göre onaylı mekanları döndürür.
func (r *VenueRepo) FindByCity(ctx context.Context, city string) ([]models.Venue, error) {
	query := `
		SELECT
			v.id, v.name, v.address, v.city,
			ST_Y(v.location::geometry) AS latitude,
			ST_X(v.location::geometry) AS longitude,
			v.notes, v.status,
			v.added_by, v.verified_at,
			v.created_at, v.updated_at
		FROM venues v
		WHERE v.status IN ('approved', 'pending')
		  AND v.deleted_at IS NULL
		  AND LOWER(v.city) = LOWER($1)
		ORDER BY CASE WHEN v.status = 'approved' THEN 0 ELSE 1 END, v.name`

	rows, err := r.db.Query(ctx, query, city)
	if err != nil {
		return nil, fmt.Errorf("şehir sorgusu başarısız: %w", err)
	}
	defer rows.Close()

	return r.scanVenueRowsWithPhotos(ctx, rows, false)
}

// FindByAddedBy — guide'ın eklediği tüm mekanları döndürür (tüm durumlar dahil).
func (r *VenueRepo) FindByAddedBy(ctx context.Context, userID string) ([]models.Venue, error) {
	rows, err := r.db.Query(ctx,
		`SELECT v.id, v.name, v.address, v.city,
		        ST_Y(v.location::geometry) AS latitude,
		        ST_X(v.location::geometry) AS longitude,
		        v.notes, v.status,
		        v.added_by, v.verified_at,
		        v.created_at, v.updated_at
		 FROM venues v
		 WHERE v.added_by = $1
		   AND v.deleted_at IS NULL
		 ORDER BY v.created_at DESC`,
		userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return r.scanVenueRowsWithPhotos(ctx, rows, false)
}

// FindAll — admin için tüm mekanları döndürür (tüm durumlar dahil).
func (r *VenueRepo) FindAll(ctx context.Context) ([]models.Venue, error) {
	rows, err := r.db.Query(ctx,
		`SELECT v.id, v.name, v.address, v.city,
		        ST_Y(v.location::geometry) AS latitude,
		        ST_X(v.location::geometry) AS longitude,
		        v.notes, v.status,
		        v.added_by, v.verified_at,
		        v.created_at, v.updated_at
		 FROM venues v
		 WHERE v.deleted_at IS NULL
		 ORDER BY v.created_at DESC`,
	)
	if err != nil {
		return nil, fmt.Errorf("tüm mekan sorgusu başarısız: %w", err)
	}
	defer rows.Close()
	return r.scanVenueRowsWithPhotos(ctx, rows, false)
}

// FindPending — admin incelemesi için bekleyen mekanları döndürür.
func (r *VenueRepo) FindPending(ctx context.Context) ([]models.Venue, error) {
	rows, err := r.db.Query(ctx,
		`SELECT v.id, v.name, v.address, v.city,
		        ST_Y(v.location::geometry) AS latitude,
		        ST_X(v.location::geometry) AS longitude,
		        v.notes, v.status,
		        v.added_by, v.verified_at,
		        v.created_at, v.updated_at
		 FROM venues v
		 WHERE v.status = 'pending'
		   AND v.deleted_at IS NULL
		 ORDER BY v.created_at`,
	)
	if err != nil {
		return nil, fmt.Errorf("bekleyen mekan sorgusu başarısız: %w", err)
	}
	defer rows.Close()
	return r.scanVenueRowsWithPhotos(ctx, rows, false)
}

// scanVenueRows — rows'u []Venue'ya dönüştürür.
// withDistance: ST_Distance sütunu sorguya dahilse true.
func scanVenueRows(rows pgx.Rows, withDistance bool) ([]models.Venue, error) {
	var venues []models.Venue
	for rows.Next() {
		v := models.Venue{}

		var err error
		if withDistance {
			err = rows.Scan(
				&v.ID, &v.Name, &v.Address, &v.City,
				&v.Latitude, &v.Longitude,
				&v.Notes, &v.Status,
				&v.AddedBy, &v.VerifiedAt,
				&v.CreatedAt, &v.UpdatedAt,
				&v.Distance,
			)
		} else {
			err = rows.Scan(
				&v.ID, &v.Name, &v.Address, &v.City,
				&v.Latitude, &v.Longitude,
				&v.Notes, &v.Status,
				&v.AddedBy, &v.VerifiedAt,
				&v.CreatedAt, &v.UpdatedAt,
			)
		}
		if err != nil {
			return nil, err
		}
		v.Criteria = []models.HalalCriteria{}
		v.Photos = []models.VenuePhoto{}
		venues = append(venues, v)
	}
	if venues == nil {
		venues = []models.Venue{}
	}
	return venues, rows.Err()
}

// scanVenueRowsWithPhotos — mekanları tarar ve her biri için fotoğrafları yükler.
func (r *VenueRepo) scanVenueRowsWithPhotos(ctx context.Context, rows pgx.Rows, withDistance bool) ([]models.Venue, error) {
	venues, err := scanVenueRows(rows, withDistance)
	if err != nil {
		return nil, err
	}

	for i := range venues {
		photos, err := r.GetPhotosByVenueID(ctx, venues[i].ID)
		if err != nil {
			return nil, err
		}
		venues[i].Photos = photos
	}

	return venues, nil
}
