package repository

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/omerkoc/itimat-mobile/internal/models"
)

type FavoriteRepo struct {
	db     *pgxpool.Pool
	venues *VenueRepo
}

func NewFavoriteRepo(db *pgxpool.Pool) *FavoriteRepo {
	return &FavoriteRepo{db: db, venues: NewVenueRepo(db)}
}

// WithURLResolver — favori mekanların fotoğraf anahtarlarını tam URL'e çevirir.
// Bağlanmazsa anahtarlar olduğu gibi döner (VenueRepo ile aynı davranış).
func (r *FavoriteRepo) WithURLResolver(u URLResolver) *FavoriteRepo {
	r.venues.WithURLResolver(u)
	return r
}

// ListByUser — kullanıcının favori mekanlarını döndürür.
// Mekan kartı şehir/ilçe, puan, yorum sayısı, mutfak özeti, rozet ve fotoğraf
// gösterdiği için sorgu FindByCity ile aynı alan kümesini döndürür; aksi halde
// favoriler listesinde yalnızca mekan adı görünür.
// Mesafe sütunu NULL: favoriler kullanıcı konumundan bağımsız listelenir.
func (r *FavoriteRepo) ListByUser(ctx context.Context, userID string) ([]models.Venue, error) {
	rows, err := r.db.Query(ctx,
		`SELECT
			v.id, v.name, v.city, v.district,
			ST_Y(v.location::geometry) AS latitude,
			ST_X(v.location::geometry) AS longitude,
			v.google_place_id,
			v.notes, v.status,
			v.added_by, v.verified_at,
			v.created_at, v.updated_at,
			NULL::float8 AS distance,
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
		 FROM favorites f
		 JOIN venues v ON v.id = f.venue_id
		 LEFT JOIN reviews rv ON rv.venue_id = v.id
		 WHERE f.user_id = $1
		   AND v.deleted_at IS NULL
		 GROUP BY v.id, f.created_at
		 ORDER BY f.created_at DESC`,
		userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return r.venues.scanVenueCityRows(ctx, rows)
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
