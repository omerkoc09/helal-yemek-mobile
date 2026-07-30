package repository

import (
	"context"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5"

	"github.com/omerkoc/itimat-mobile/internal/models"
)

// FindNearby — PostGIS ST_DWithin ile yakındaki onaylı mekanları döndürür.
// $1=lat, $2=lng, $3=radius(metre)
func (r *VenueRepo) FindNearby(ctx context.Context, lat, lng, radiusMeters float64) ([]models.Venue, error) {
	query := `
		SELECT
			v.id, v.name, v.city, v.district,
			ST_Y(v.location::geometry) AS latitude,
			ST_X(v.location::geometry) AS longitude,
			v.google_place_id,
			v.notes, v.status,
			v.added_by, v.verified_at,
			v.created_at, v.updated_at,
			ST_Distance(v.location, ST_MakePoint($2, $1)::geography) AS distance,
			v.confirmation_count,
			COALESCE(AVG(rv.rating), 0)::float8 AS avg_rating,
			COUNT(rv.id)::int AS review_count
		FROM venues v
		LEFT JOIN reviews rv ON rv.venue_id = v.id
		WHERE v.status = 'approved'
		  AND v.deleted_at IS NULL
		  AND ST_DWithin(v.location, ST_MakePoint($2, $1)::geography, $3)
		GROUP BY v.id
		ORDER BY distance
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

// SearchByText — mekan adı, şehir, ilçe veya yemek kategorisi içinde serbest
// metin araması yapar. Eşleşme Türkçe karakter duyarsızdır (unaccent).
// Yalnızca onaylı mekanlar döner: yeni eklenen mekanlar `pending` doğduğu için
// admin onaylayana kadar aramada görünmez.
//
// lat/lng kullanıcı konumudur; 0,0 gönderilirse mesafe NULL döner ve sıralama
// puana düşer. Sütun sırası FindByCity ile birebir aynıdır; bu yüzden ortak
// scanVenueCityRows tarayıcısı kullanılır.
//
// Not: unaccent() immutable olmadığı için bu sütunlara fonksiyonel index
// kurulamaz; mevcut veri ölçeğinde seq scan kabul edilebilir.
func (r *VenueRepo) SearchByText(ctx context.Context, query string, lat, lng float64) ([]models.Venue, error) {
	query = escapeILIKE(query)
	q := `
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
				SELECT STRING_AGG(fc.name, ' · ')
				FROM (
					SELECT DISTINCT fc2.name
					FROM venue_categories vc2
					JOIN food_categories fc2 ON fc2.id = vc2.category_id
					WHERE vc2.venue_id = v.id
					LIMIT 2
				) fc
			) AS categories_str,
			v.confirmation_count
		FROM venues v
		LEFT JOIN reviews rv ON rv.venue_id = v.id
		WHERE v.status = 'approved'
		  AND v.deleted_at IS NULL
		  AND (
		    unaccent(v.name) ILIKE '%' || unaccent($1) || '%'
		    OR unaccent(v.city) ILIKE '%' || unaccent($1) || '%'
		    OR unaccent(COALESCE(v.district, '')) ILIKE '%' || unaccent($1) || '%'
		    OR EXISTS (
		      SELECT 1
		      FROM venue_categories vcs
		      JOIN food_categories fcs ON fcs.id = vcs.category_id
		      WHERE vcs.venue_id = v.id
		        AND unaccent(fcs.name) ILIKE '%' || unaccent($1) || '%'
		    )
		  )
		GROUP BY v.id
		ORDER BY distance ASC NULLS LAST, avg_rating DESC, v.name ASC
		LIMIT 50`

	rows, err := r.db.Query(ctx, q, query, lat, lng)
	if err != nil {
		return nil, fmt.Errorf("metin arama sorgusu başarısız: %w", err)
	}
	defer rows.Close()

	return r.scanVenueCityRows(ctx, rows)
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
				SELECT STRING_AGG(fc.name, ' · ')
				FROM (
					SELECT DISTINCT fc2.name
					FROM venue_categories vc2
					JOIN food_categories fc2 ON fc2.id = vc2.category_id
					WHERE vc2.venue_id = v.id
					LIMIT 2
				) fc
			) AS categories_str,
			v.confirmation_count
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

// FindByCityDistrict — belirli bir şehrin belirli bir ilçesindeki onaylı mekanları
// döndürür. Arama önerisinden "İstanbul / Fatih" seçildiğinde kullanılır: serbest
// metin aramasının aksine başka ildeki aynı adlı ilçeler ve adında o kelime geçen
// mekanlar karışmaz.
//
// lat, lng: kullanıcı konumu (mesafe hesabı için); 0,0 gönderilirse mesafe NULL döner.
// limit: 0 ise tüm mekanlar döner.
// Sütun sırası FindByCity ile birebir aynıdır (ortak scanVenueCityRows kullanılır).
func (r *VenueRepo) FindByCityDistrict(ctx context.Context, city, district string, lat, lng float64, limit int) ([]models.Venue, error) {
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
			CASE WHEN $3 != 0.0 AND $4 != 0.0
			     THEN ST_Distance(v.location, ST_MakePoint($4, $3)::geography)
			     ELSE NULL END AS distance,
			COALESCE(AVG(rv.rating), 0)::float8 AS avg_rating,
			COUNT(rv.id)::int AS review_count,
			(
				SELECT STRING_AGG(fc.name, ' · ')
				FROM (
					SELECT DISTINCT fc2.name
					FROM venue_categories vc2
					JOIN food_categories fc2 ON fc2.id = vc2.category_id
					WHERE vc2.venue_id = v.id
					LIMIT 2
				) fc
			) AS categories_str,
			v.confirmation_count
		FROM venues v
		LEFT JOIN reviews rv ON rv.venue_id = v.id
		WHERE v.city ILIKE $1
		  AND v.district ILIKE $2
		  AND v.status = 'approved'
		  AND v.deleted_at IS NULL
		GROUP BY v.id
		ORDER BY distance ASC NULLS LAST, v.name ASC
		%s`, limitClause)

	rows, err := r.db.Query(ctx, query, escapeILIKE(city), escapeILIKE(district), lat, lng)
	if err != nil {
		return nil, fmt.Errorf("şehir/ilçe sorgusu başarısız: %w", err)
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

// FindConfirmedBy — rehberin doğruladığı (confirm ettiği) tüm mekanları, kendi
// doğrulama tarihiyle birlikte döndürür. Taze/eski ayrımı yapılmaz: kayıt
// silinmediği sürece (rehber doğrulamasını geri çekmediği sürece) listede kalır.
// ConfirmedAt sütunu ortak scanVenueRows sırasına girmediği için tarama burada.
func (r *VenueRepo) FindConfirmedBy(ctx context.Context, guideID string) ([]models.Venue, error) {
	rows, err := r.db.Query(ctx,
		`SELECT v.id, v.name, v.city,
		        ST_Y(v.location::geometry) AS latitude,
		        ST_X(v.location::geometry) AS longitude,
		        v.google_place_id,
		        v.notes, v.status,
		        v.added_by, v.verified_at,
		        v.created_at, v.updated_at,
		        v.confirmation_count,
		        vc.created_at AS confirmed_at
		 FROM venues v
		 JOIN venue_confirmations vc ON vc.venue_id = v.id
		 WHERE vc.guide_id = $1
		   AND v.deleted_at IS NULL
		 ORDER BY vc.created_at DESC`,
		guideID,
	)
	if err != nil {
		return nil, fmt.Errorf("doğrulanan mekanlar sorgusu başarısız: %w", err)
	}
	defer rows.Close()

	var venues []models.Venue
	for rows.Next() {
		v := models.Venue{}
		if err := rows.Scan(
			&v.ID, &v.Name, &v.City,
			&v.Latitude, &v.Longitude,
			&v.GooglePlaceID,
			&v.Notes, &v.Status,
			&v.AddedBy, &v.VerifiedAt,
			&v.CreatedAt, &v.UpdatedAt,
			&v.ConfirmationCount,
			&v.ConfirmedAt,
		); err != nil {
			return nil, err
		}
		v.TrustCriteria = []models.TrustCriteria{}
		v.Photos = []models.VenuePhoto{}
		venues = append(venues, v)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if venues == nil {
		return []models.Venue{}, nil
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
		        u.name AS added_by_name, u.surname AS added_by_surname, u.email AS added_by_email,
		        COALESCE(AVG(rv.rating), 0)::float8 AS avg_rating,
		        COUNT(rv.id) AS review_count
		 FROM venues v
		 LEFT JOIN users u ON u.id = v.added_by
		 LEFT JOIN reviews rv ON rv.venue_id = v.id
		 WHERE v.deleted_at IS NULL
		 GROUP BY v.id, u.name, u.surname, u.email
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
			&v.AddedByName, &v.AddedBySurname, &v.AddedByEmail,
			&avgRating, &reviewCount,
		); err != nil {
			return nil, fmt.Errorf("tüm mekan taraması başarısız: %w", err)
		}
		v.AverageRating = &avgRating
		v.ReviewCount = reviewCount
		v.TrustCriteria = []models.TrustCriteria{}
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
				SELECT STRING_AGG(fc.name, ' · ')
				FROM (
					SELECT DISTINCT fc2.name
					FROM venue_categories vc2
					JOIN food_categories fc2 ON fc2.id = vc2.category_id
					WHERE vc2.venue_id = v.id
					LIMIT 2
				) fc
			) AS categories_str,
			v.confirmation_count
		FROM venues v
		JOIN venue_categories vc ON vc.venue_id = v.id
		LEFT JOIN reviews rv ON rv.venue_id = v.id
		WHERE vc.category_id = $1
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
				SELECT STRING_AGG(fc.name, ' · ')
				FROM (
					SELECT DISTINCT fc2.name
					FROM venue_categories vc2
					JOIN food_categories fc2 ON fc2.id = vc2.category_id
					WHERE vc2.venue_id = v.id
					LIMIT 2
				) fc
			) AS categories_str,
			v.confirmation_count
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

// FindPopular — popülerlik skoruna göre onaylı mekanları döndürür.
// Skor = avg_rating * LOG(review_count+1) + 0.5 * LOG(direction_click_count+1).
// Yol tarifi tıklamaları (venue_direction_clicks) ikincil bir ilgi sinyali olarak
// skora eklenir; rating*review_count terimi baskın kalır, tıklama sayısı sadece
// yakın puanlı mekanlar arasında ayrıştırıcı bir boost sağlar.
// limit=0 ise tüm mekanlar döner; limit>0 ise en fazla limit kadar döner.
// radiusMeters<=0 ise yarıçap kısıtı uygulanmaz (sınırsız): konumu uzak olsa da
// tüm onaylı mekanlar listeye girer. lat/lng yine gereklidir; mesafe (distance)
// hesaplanmaya devam ettiği için uzaklık gösterimi ve yakınlığa göre sıralama çalışır.
func (r *VenueRepo) FindPopular(ctx context.Context, lat, lng, radiusMeters float64, limit int) ([]models.Venue, error) {
	limitClause := ""
	if limit > 0 {
		limitClause = fmt.Sprintf("LIMIT %d", limit)
	}

	// Yarıçap kısıtı yalnızca radiusMeters>0 iken uygulanır; aksi halde $3
	// argümanı hiç kullanılmadığından sorgu parametrelerinden de çıkarılır.
	radiusClause := ""
	args := []any{lat, lng}
	if radiusMeters > 0 {
		radiusClause = "AND ST_DWithin(v.location, ST_MakePoint($2, $1)::geography, $3)"
		args = append(args, radiusMeters)
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
				SELECT STRING_AGG(fc.name, ' · ')
				FROM (
					SELECT DISTINCT fc2.name
					FROM venue_categories vc2
					JOIN food_categories fc2 ON fc2.id = vc2.category_id
					WHERE vc2.venue_id = v.id
					LIMIT 2
				) fc
			) AS categories_str,
			v.confirmation_count
		FROM venues v
		LEFT JOIN reviews rv ON rv.venue_id = v.id
		LEFT JOIN (
			SELECT venue_id, COUNT(*)::int AS click_count
			FROM venue_direction_clicks
			GROUP BY venue_id
		) dc ON dc.venue_id = v.id
		WHERE v.status = 'approved'
		  AND v.deleted_at IS NULL
		  %s
		GROUP BY v.id, dc.click_count
		ORDER BY (
			COALESCE(AVG(rv.rating), 0) * LOG(COUNT(rv.id) + 1)
			+ 0.5 * LOG(COALESCE(dc.click_count, 0) + 1)
		) DESC, distance ASC
		%s`, radiusClause, limitClause)

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("popüler mekan sorgusu başarısız: %w", err)
	}
	defer rows.Close()

	return r.scanVenueRowsWithRatingAndPhotos(ctx, rows)
}

// scanVenueRowsNearbyWithPhotos — FindNearby sorgusundan dönen satırları tarar.
// Sütun sırası: id, name, city, district, lat, lng, google_place_id,
//               notes, status, added_by, verified_at, created_at, updated_at,
//               distance, confirmation_count, avg_rating, review_count
func (r *VenueRepo) scanVenueRowsNearbyWithPhotos(ctx context.Context, rows pgx.Rows) ([]models.Venue, error) {
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
			&v.ConfirmationCount,
			&v.AverageRating,
			&v.ReviewCount,
		)
		if err != nil {
			return nil, err
		}
		badge := models.BadgeFromCount(v.ConfirmationCount)
		v.Badge = &badge
		v.TrustCriteria = []models.TrustCriteria{}
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
// confirmation_count içeren satırları tarar.
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
			&v.ConfirmationCount,
		)
		if err != nil {
			return nil, err
		}
		badge := models.BadgeFromCount(v.ConfirmationCount)
		v.Badge = &badge
		v.TrustCriteria = []models.TrustCriteria{}
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

		categories, err := r.GetCategoriesByVenueID(ctx, venues[i].ID)
		if err != nil {
			return nil, err
		}
		venues[i].Categories = categories
	}
	return venues, nil
}

// scanVenueCityRows — FindByCity sorgusundan dönen satırları tarar.
// Sütun sırası: id, name, city, district, lat, lng, google_place_id,
//               notes, status, added_by, verified_at, created_at, updated_at,
//               distance, avg_rating, review_count, categories_str,
//               confirmation_count
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
			&v.ConfirmationCount,
		)
		if err != nil {
			return nil, err
		}
		badge := models.BadgeFromCount(v.ConfirmationCount)
		v.Badge = &badge
		v.TrustCriteria = []models.TrustCriteria{}
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

		categories, err := r.GetCategoriesByVenueID(ctx, venues[i].ID)
		if err != nil {
			return nil, err
		}
		venues[i].Categories = categories
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
		v.TrustCriteria = []models.TrustCriteria{}
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

// CityDistrict — şehir/ilçe çifti (arama önerileri için).
type CityDistrict struct {
	City     string `json:"city"`
	District string `json:"district"`
}

// FindDistinctDistricts — approved mekanlardaki benzersiz şehir/ilçe çiftlerini
// alfabetik döndürür. Arama ekranında "İstanbul / Fatih" gibi ilçe önerileri
// bu listeden üretilir; yalnızca gerçekten mekanı olan ilçeler önerilir.
func (r *VenueRepo) FindDistinctDistricts(ctx context.Context) ([]CityDistrict, error) {
	rows, err := r.db.Query(ctx, `
		SELECT DISTINCT city, district
		FROM venues
		WHERE status = 'approved'
		  AND deleted_at IS NULL
		  AND city != ''
		  AND district IS NOT NULL
		  AND district != ''
		ORDER BY city ASC, district ASC
	`)
	if err != nil {
		return nil, fmt.Errorf("ilçe listesi sorgusu başarısız: %w", err)
	}
	defer rows.Close()

	list := []CityDistrict{}
	for rows.Next() {
		var cd CityDistrict
		if err := rows.Scan(&cd.City, &cd.District); err != nil {
			return nil, err
		}
		list = append(list, cd)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("ilçe listesi taranması başarısız: %w", err)
	}
	return list, nil
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
