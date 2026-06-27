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
			v.id, v.name, v.city,
			ST_Y(v.location::geometry) AS latitude,
			ST_X(v.location::geometry) AS longitude,
			v.google_place_id,
			v.notes, v.status,
			v.added_by, v.verified_at,
			v.created_at, v.updated_at,
			ST_Distance(v.location, ST_MakePoint($2, $1)::geography) AS distance,
			v.confirmation_count, v.is_double_verified
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

	return r.scanVenueRowsNearbyWithPhotos(ctx, rows)
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
			v.id, v.name, v.city,
			ST_Y(v.location::geometry) AS latitude,
			ST_X(v.location::geometry) AS longitude,
			v.google_place_id,
			v.notes, v.status,
			v.added_by, v.verified_at,
			v.created_at, v.updated_at
		FROM venues v
		WHERE v.status IN ('approved', 'pending')
		  AND v.deleted_at IS NULL
		  AND (
		    v.name ILIKE '%' || $1 || '%'
		    OR v.city ILIKE '%' || $1 || '%'
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
// lat, lng: kullanıcı konumu (mesafe hesabı için); 0,0 gönderilirse mesafe NULL döner.
// limit: döndürülecek max mekan sayısı; 0 ise tüm mekanlar döner.
func (r *VenueRepo) FindByCity(ctx context.Context, city string, lat, lng float64, limit int) ([]models.Venue, error) {
	limitClause := ""
	if limit > 0 {
		limitClause = fmt.Sprintf("LIMIT %d", limit)
	}

	query := fmt.Sprintf(`
		SELECT
			v.id, v.name, v.city, v.district,
			ST_Y(v.location::geometry) AS latitude,
			ST_X(v.location::geometry) AS longitude,
			v.google_place_id,
			v.notes, v.status,
			v.added_by, v.verified_at,
			v.created_at, v.updated_at,
			CASE WHEN $2 != 0.0 AND $3 != 0.0
			     THEN ST_Distance(v.location, ST_MakePoint($3, $2)::geography)
			     ELSE NULL END AS distance,
			COALESCE(AVG(rv.rating), 0)::float8 AS avg_rating,
			COUNT(rv.id)::int AS review_count,
			(
				SELECT STRING_AGG(fc.label_tr, ' · ')
				FROM (
					SELECT DISTINCT fc2.label_tr
					FROM venue_food_items vfi2
					JOIN food_items fi2 ON fi2.id = vfi2.food_item_id
					JOIN food_categories fc2 ON fc2.id = fi2.category_id
					WHERE vfi2.venue_id = v.id
					LIMIT 2
				) fc
			) AS categories_str,
			v.confirmation_count, v.is_double_verified
		FROM venues v
		LEFT JOIN reviews rv ON rv.venue_id = v.id
		WHERE v.city ILIKE $1
		  AND v.status = 'approved'
		  AND v.deleted_at IS NULL
		GROUP BY v.id
		ORDER BY distance ASC NULLS LAST, v.name ASC
		%s`, limitClause)

	rows, err := r.db.Query(ctx, query, city, lat, lng)
	if err != nil {
		return nil, fmt.Errorf("şehir sorgusu başarısız: %w", err)
	}
	defer rows.Close()

	return r.scanVenueCityRows(ctx, rows)
}

// FindByAddedBy — guide'ın eklediği tüm mekanları döndürür (tüm durumlar dahil).
func (r *VenueRepo) FindByAddedBy(ctx context.Context, userID string) ([]models.Venue, error) {
	rows, err := r.db.Query(ctx,
		`SELECT v.id, v.name, v.city,
		        ST_Y(v.location::geometry) AS latitude,
		        ST_X(v.location::geometry) AS longitude,
		        v.google_place_id,
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
	// Admin paneli liste görünümü için zenginleştirilmiş sorgu:
	// ekleyen kullanıcının isim/email'i (users join) ve puan/yorum istatistikleri (reviews join).
	rows, err := r.db.Query(ctx,
		`SELECT v.id, v.name, v.city, v.district,
		        ST_Y(v.location::geometry) AS latitude,
		        ST_X(v.location::geometry) AS longitude,
		        v.google_place_id,
		        v.notes, v.status,
		        v.added_by, v.verified_at,
		        v.created_at, v.updated_at,
		        u.name AS added_by_name, u.email AS added_by_email,
		        COALESCE(AVG(rv.rating), 0)::float8 AS avg_rating,
		        COUNT(rv.id) AS review_count
		 FROM venues v
		 LEFT JOIN users u ON u.id = v.added_by
		 LEFT JOIN reviews rv ON rv.venue_id = v.id
		 WHERE v.deleted_at IS NULL
		 GROUP BY v.id, u.name, u.email
		 ORDER BY v.created_at DESC`,
	)
	if err != nil {
		return nil, fmt.Errorf("tüm mekan sorgusu başarısız: %w", err)
	}
	defer rows.Close()

	var venues []models.Venue
	for rows.Next() {
		v := models.Venue{}
		var avgRating float64
		var reviewCount int
		if err := rows.Scan(
			&v.ID, &v.Name, &v.City, &v.District,
			&v.Latitude, &v.Longitude,
			&v.GooglePlaceID,
			&v.Notes, &v.Status,
			&v.AddedBy, &v.VerifiedAt,
			&v.CreatedAt, &v.UpdatedAt,
			&v.AddedByName, &v.AddedByEmail,
			&avgRating, &reviewCount,
		); err != nil {
			return nil, fmt.Errorf("tüm mekan taraması başarısız: %w", err)
		}
		v.AverageRating = &avgRating
		v.ReviewCount = reviewCount
		v.Criteria = []models.HalalCriteria{}
		v.Photos = []models.VenuePhoto{}
		venues = append(venues, v)
	}
	if venues == nil {
		venues = []models.Venue{}
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("tüm mekan satırları hatası: %w", err)
	}

	// Fotoğrafları yükle (fotoğraf sayısı kolonu için).
	for i := range venues {
		photos, err := r.GetPhotosByVenueID(ctx, venues[i].ID)
		if err != nil {
			return nil, err
		}
		venues[i].Photos = photos
	}

	return venues, nil
}

// FindPending — admin incelemesi için bekleyen mekanları döndürür.
func (r *VenueRepo) FindPending(ctx context.Context) ([]models.Venue, error) {
	rows, err := r.db.Query(ctx,
		`SELECT v.id, v.name, v.city,
		        ST_Y(v.location::geometry) AS latitude,
		        ST_X(v.location::geometry) AS longitude,
		        v.google_place_id,
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

// FindByFoodCategory — belirli yemek kategorisindeki tüm onaylı mekanları döndürür.
func (r *VenueRepo) FindByFoodCategory(ctx context.Context, categoryID int) ([]models.Venue, error) {
	query := `
		SELECT DISTINCT ON (v.id)
			v.id, v.name, v.city, v.district,
			ST_Y(v.location::geometry) AS latitude,
			ST_X(v.location::geometry) AS longitude,
			v.google_place_id,
			v.notes, v.status,
			v.added_by, v.verified_at,
			v.created_at, v.updated_at,
			NULL::float8 AS distance,
			COALESCE(AVG(rv.rating) OVER (PARTITION BY v.id), 0)::float8 AS avg_rating,
			COUNT(rv.id) OVER (PARTITION BY v.id)::int AS review_count,
			(
				SELECT STRING_AGG(fc.label_tr, ' · ')
				FROM (
					SELECT DISTINCT fc2.label_tr
					FROM venue_food_items vfi2
					JOIN food_items fi2 ON fi2.id = vfi2.food_item_id
					JOIN food_categories fc2 ON fc2.id = fi2.category_id
					WHERE vfi2.venue_id = v.id
					LIMIT 2
				) fc
			) AS categories_str,
			v.confirmation_count, v.is_double_verified
		FROM venues v
		JOIN venue_food_items vfi ON vfi.venue_id = v.id
		JOIN food_items fi ON fi.id = vfi.food_item_id
		LEFT JOIN reviews rv ON rv.venue_id = v.id
		WHERE fi.category_id = $1
		  AND v.status = 'approved'
		  AND v.deleted_at IS NULL
		ORDER BY v.id, v.name
		LIMIT 200`

	rows, err := r.db.Query(ctx, query, categoryID)
	if err != nil {
		return nil, fmt.Errorf("kategori bazlı mekan sorgusu başarısız: %w", err)
	}
	defer rows.Close()

	return r.scanVenueRowsWithRatingAndPhotos(ctx, rows)
}

// FindNearbyApproved — onaylı mekanları mesafeye göre döndürür.
// limit=0 ise tüm mekanlar döner; limit>0 ise en fazla limit kadar döner.
func (r *VenueRepo) FindNearbyApproved(ctx context.Context, lat, lng, radiusMeters float64, limit int) ([]models.Venue, error) {
	limitClause := ""
	if limit > 0 {
		limitClause = fmt.Sprintf("LIMIT %d", limit)
	}
	query := fmt.Sprintf(`
		SELECT
			v.id, v.name, v.city, v.district,
			ST_Y(v.location::geometry) AS latitude,
			ST_X(v.location::geometry) AS longitude,
			v.google_place_id,
			v.notes, v.status,
			v.added_by, v.verified_at,
			v.created_at, v.updated_at,
			ST_Distance(v.location, ST_MakePoint($2, $1)::geography) AS distance,
			COALESCE(AVG(rv.rating), 0)::float8 AS avg_rating,
			COUNT(rv.id)::int AS review_count,
			(
				SELECT STRING_AGG(fc.label_tr, ' · ')
				FROM (
					SELECT DISTINCT fc2.label_tr
					FROM venue_food_items vfi2
					JOIN food_items fi2 ON fi2.id = vfi2.food_item_id
					JOIN food_categories fc2 ON fc2.id = fi2.category_id
					WHERE vfi2.venue_id = v.id
					LIMIT 2
				) fc
			) AS categories_str,
			v.confirmation_count, v.is_double_verified
		FROM venues v
		LEFT JOIN reviews rv ON rv.venue_id = v.id
		WHERE v.status = 'approved'
		  AND v.deleted_at IS NULL
		  AND ST_DWithin(v.location, ST_MakePoint($2, $1)::geography, $3)
		GROUP BY v.id
		ORDER BY distance ASC
		%s`, limitClause)

	rows, err := r.db.Query(ctx, query, lat, lng, radiusMeters)
	if err != nil {
		return nil, fmt.Errorf("yakın onaylı mekan sorgusu başarısız: %w", err)
	}
	defer rows.Close()

	return r.scanVenueRowsWithRatingAndPhotos(ctx, rows)
}

// FindPopular — popülerlik skoruna göre (avg_rating * log(review_count+1)) onaylı mekanları döndürür.
// limit=0 ise tüm mekanlar döner; limit>0 ise en fazla limit kadar döner.
func (r *VenueRepo) FindPopular(ctx context.Context, lat, lng, radiusMeters float64, limit int) ([]models.Venue, error) {
	limitClause := ""
	if limit > 0 {
		limitClause = fmt.Sprintf("LIMIT %d", limit)
	}
	query := fmt.Sprintf(`
		SELECT
			v.id, v.name, v.city, v.district,
			ST_Y(v.location::geometry) AS latitude,
			ST_X(v.location::geometry) AS longitude,
			v.google_place_id,
			v.notes, v.status,
			v.added_by, v.verified_at,
			v.created_at, v.updated_at,
			ST_Distance(v.location, ST_MakePoint($2, $1)::geography) AS distance,
			COALESCE(AVG(rv.rating), 0)::float8 AS avg_rating,
			COUNT(rv.id)::int AS review_count,
			(
				SELECT STRING_AGG(fc.label_tr, ' · ')
				FROM (
					SELECT DISTINCT fc2.label_tr
					FROM venue_food_items vfi2
					JOIN food_items fi2 ON fi2.id = vfi2.food_item_id
					JOIN food_categories fc2 ON fc2.id = fi2.category_id
					WHERE vfi2.venue_id = v.id
					LIMIT 2
				) fc
			) AS categories_str,
			v.confirmation_count, v.is_double_verified
		FROM venues v
		LEFT JOIN reviews rv ON rv.venue_id = v.id
		WHERE v.status = 'approved'
		  AND v.deleted_at IS NULL
		  AND ST_DWithin(v.location, ST_MakePoint($2, $1)::geography, $3)
		GROUP BY v.id
		ORDER BY (COALESCE(AVG(rv.rating), 0) * LOG(COUNT(rv.id) + 1)) DESC, distance ASC
		%s`, limitClause)

	rows, err := r.db.Query(ctx, query, lat, lng, radiusMeters)
	if err != nil {
		return nil, fmt.Errorf("popüler mekan sorgusu başarısız: %w", err)
	}
	defer rows.Close()

	return r.scanVenueRowsWithRatingAndPhotos(ctx, rows)
}

// scanVenueRowsNearbyWithPhotos — FindNearby sorgusundan dönen satırları tarar.
// Sütun sırası: id, name, city, lat, lng, google_place_id,
//               notes, status, added_by, verified_at, created_at, updated_at,
//               distance, confirmation_count, is_double_verified
func (r *VenueRepo) scanVenueRowsNearbyWithPhotos(ctx context.Context, rows pgx.Rows) ([]models.Venue, error) {
	var venues []models.Venue
	for rows.Next() {
		v := models.Venue{}
		err := rows.Scan(
			&v.ID, &v.Name, &v.City,
			&v.Latitude, &v.Longitude,
			&v.GooglePlaceID,
			&v.Notes, &v.Status,
			&v.AddedBy, &v.VerifiedAt,
			&v.CreatedAt, &v.UpdatedAt,
			&v.Distance,
			&v.ConfirmationCount, &v.IsDoubleVerified,
		)
		if err != nil {
			return nil, err
		}
		badge := models.BadgeFromCount(v.ConfirmationCount)
		v.Badge = &badge
		v.Criteria = []models.HalalCriteria{}
		v.Photos = []models.VenuePhoto{}
		venues = append(venues, v)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if venues == nil {
		venues = []models.Venue{}
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

// scanVenueRowsWithRatingAndPhotos — distance + avg_rating + review_count + categories_str +
// confirmation_count + is_double_verified içeren satırları tarar.
// FindNearbyApproved ve FindPopular tarafından kullanılır.
func (r *VenueRepo) scanVenueRowsWithRatingAndPhotos(ctx context.Context, rows pgx.Rows) ([]models.Venue, error) {
	var venues []models.Venue
	for rows.Next() {
		v := models.Venue{}
		err := rows.Scan(
			&v.ID, &v.Name, &v.City, &v.District,
			&v.Latitude, &v.Longitude,
			&v.GooglePlaceID,
			&v.Notes, &v.Status,
			&v.AddedBy, &v.VerifiedAt,
			&v.CreatedAt, &v.UpdatedAt,
			&v.Distance,
			&v.AverageRating,
			&v.ReviewCount,
			&v.CategoriesStr,
			&v.ConfirmationCount, &v.IsDoubleVerified,
		)
		if err != nil {
			return nil, err
		}
		badge := models.BadgeFromCount(v.ConfirmationCount)
		v.Badge = &badge
		v.Criteria = []models.HalalCriteria{}
		v.Photos = []models.VenuePhoto{}
		venues = append(venues, v)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if venues == nil {
		venues = []models.Venue{}
	}

	for i := range venues {
		photos, err := r.GetPhotosByVenueID(ctx, venues[i].ID)
		if err != nil {
			return nil, err
		}
		venues[i].Photos = photos

		foodItems, err := r.GetFoodItemsByVenueID(ctx, venues[i].ID)
		if err != nil {
			return nil, err
		}
		venues[i].FoodItems = foodItems
	}
	return venues, nil
}

// scanVenueCityRows — FindByCity sorgusundan dönen satırları tarar.
// Sütun sırası: id, name, city, district, lat, lng, google_place_id,
//               notes, status, added_by, verified_at, created_at, updated_at,
//               distance, avg_rating, review_count, categories_str,
//               confirmation_count, is_double_verified
func (r *VenueRepo) scanVenueCityRows(ctx context.Context, rows pgx.Rows) ([]models.Venue, error) {
	var venues []models.Venue
	for rows.Next() {
		v := models.Venue{}
		err := rows.Scan(
			&v.ID, &v.Name, &v.City, &v.District,
			&v.Latitude, &v.Longitude,
			&v.GooglePlaceID,
			&v.Notes, &v.Status,
			&v.AddedBy, &v.VerifiedAt,
			&v.CreatedAt, &v.UpdatedAt,
			&v.Distance,
			&v.AverageRating,
			&v.ReviewCount,
			&v.CategoriesStr,
			&v.ConfirmationCount, &v.IsDoubleVerified,
		)
		if err != nil {
			return nil, err
		}
		badge := models.BadgeFromCount(v.ConfirmationCount)
		v.Badge = &badge
		v.Criteria = []models.HalalCriteria{}
		v.Photos = []models.VenuePhoto{}
		venues = append(venues, v)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if venues == nil {
		venues = []models.Venue{}
	}

	for i := range venues {
		photos, err := r.GetPhotosByVenueID(ctx, venues[i].ID)
		if err != nil {
			return nil, err
		}
		venues[i].Photos = photos

		foodItems, err := r.GetFoodItemsByVenueID(ctx, venues[i].ID)
		if err != nil {
			return nil, err
		}
		venues[i].FoodItems = foodItems
	}
	return venues, nil
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
				&v.ID, &v.Name, &v.City,
				&v.Latitude, &v.Longitude,
				&v.GooglePlaceID,
				&v.Notes, &v.Status,
				&v.AddedBy, &v.VerifiedAt,
				&v.CreatedAt, &v.UpdatedAt,
				&v.Distance,
			)
		} else {
			err = rows.Scan(
				&v.ID, &v.Name, &v.City,
				&v.Latitude, &v.Longitude,
				&v.GooglePlaceID,
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

// FindDistinctCities — approved mekanlardaki benzersiz şehirleri alfabetik döndürür.
func (r *VenueRepo) FindDistinctCities(ctx context.Context) ([]string, error) {
	rows, err := r.db.Query(ctx, `
		SELECT DISTINCT city
		FROM venues
		WHERE status = 'approved'
		  AND deleted_at IS NULL
		  AND city != ''
		ORDER BY city ASC
	`)
	if err != nil {
		return nil, fmt.Errorf("şehir listesi sorgusu başarısız: %w", err)
	}
	defer rows.Close()

	var cities []string
	for rows.Next() {
		var city string
		if err := rows.Scan(&city); err != nil {
			return nil, err
		}
		cities = append(cities, city)
	}
	if cities == nil {
		cities = []string{}
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("şehir listesi taranması başarısız: %w", err)
	}
	return cities, nil
}

// CityVenueCount — şehir bazlı onaylı mekan sayımı (admin paneli haritası).
type CityVenueCount struct {
	City  string `json:"city"`
	Count int    `json:"count"`
}

// CountApprovedVenuesByCity — şehir bazlı onaylı mekan sayısını azalan döndürür.
func (r *VenueRepo) CountApprovedVenuesByCity(ctx context.Context) ([]CityVenueCount, error) {
	rows, err := r.db.Query(ctx, `
		SELECT city, COUNT(*) AS cnt
		FROM venues
		WHERE status = 'approved'
		  AND deleted_at IS NULL
		  AND city != ''
		GROUP BY city
		ORDER BY cnt DESC, city
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []CityVenueCount
	for rows.Next() {
		var c CityVenueCount
		if err := rows.Scan(&c.City, &c.Count); err != nil {
			return nil, err
		}
		list = append(list, c)
	}
	if list == nil {
		list = []CityVenueCount{}
	}
	return list, rows.Err()
}
