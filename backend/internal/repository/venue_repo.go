package repository

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/omerkoc/caiz-mi/internal/models"
)

// URLResolver — depolanan dosya anahtarını istemcinin erişebileceği tam URL'e
// çevirir. Arayüz burada tanımlı çünkü services paketi repository'yi import
// ediyor; ters yönde import döngüsü oluşurdu. *services.StorageService bu
// arayüzü yapısal olarak karşılar.
type URLResolver interface {
	PublicURL(key string) string
}

type VenueRepo struct {
	db   *pgxpool.Pool
	urls URLResolver
}

// WithURLResolver — fotoğraf anahtarlarını tam URL'e çeviren çözücüyü bağlar.
// Yapıcı imzasını değiştirmemek için builder olarak eklendi: NewVenueRepo 17
// integration test çağrısında kullanılıyor ve hiçbiri URL üretimine bakmıyor.
// Çözücü bağlanmazsa anahtarlar olduğu gibi döner (testlerde beklenen davranış).
func (r *VenueRepo) WithURLResolver(u URLResolver) *VenueRepo {
	r.urls = u
	return r
}

// publicURL — çözücü yoksa anahtarı olduğu gibi döndürür.
func (r *VenueRepo) publicURL(key string) string {
	if r.urls == nil {
		return key
	}
	return r.urls.PublicURL(key)
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
			v.added_by, u.name AS added_by_name, u.surname AS added_by_surname,
			u.email AS added_by_email, v.verified_at, v.verification_due_at,
			v.created_at, v.updated_at,
			v.rejection_note, v.approved_by,
			v.food_halal_mode, v.excluded_products,
			COALESCE(AVG(rv.rating), 0)::float8 AS average_rating,
			COUNT(rv.id)::int AS review_count,
			v.confirmation_count, v.is_double_verified
		FROM venues v
		LEFT JOIN users u ON u.id = v.added_by
		LEFT JOIN reviews rv ON rv.venue_id = v.id
		WHERE v.id = $1 AND v.deleted_at IS NULL
		GROUP BY v.id, u.name, u.surname, u.email`

	v := &models.Venue{}

	err := r.db.QueryRow(ctx, query, id).Scan(
		&v.ID, &v.Name, &v.City,
		&v.Latitude, &v.Longitude,
		&v.GooglePlaceID,
		&v.Notes, &v.Status,
		&v.AddedBy, &v.AddedByName, &v.AddedBySurname, &v.AddedByEmail, &v.VerifiedAt, &v.VerificationDueAt,
		&v.CreatedAt, &v.UpdatedAt,
		&v.RejectionNote, &v.ApprovedBy,
		&v.FoodHalalMode, &v.ExcludedProducts,
		&v.AverageRating, &v.ReviewCount,
		&v.ConfirmationCount, &v.IsDoubleVerified,
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

	badge := models.BadgeFromCount(v.ConfirmationCount)
	v.Badge = &badge

	return v, nil
}

// FindByGooglePlaceID — verilen Google Place ID'ye sahip aktif mekanı döndürür.
// Erken duplicate kontrolü için kullanılır. Bulunmazsa ErrNotFound.
func (r *VenueRepo) FindByGooglePlaceID(ctx context.Context, placeID string) (*models.Venue, error) {
	query := `
		SELECT v.id, v.name, v.city, v.status,
		       v.added_by, v.confirmation_count, v.is_double_verified
		FROM venues v
		WHERE v.google_place_id = $1 AND v.deleted_at IS NULL
		LIMIT 1`

	v := &models.Venue{}
	err := r.db.QueryRow(ctx, query, placeID).Scan(
		&v.ID, &v.Name, &v.City, &v.Status,
		&v.AddedBy, &v.ConfirmationCount, &v.IsDoubleVerified,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	badge := models.BadgeFromCount(v.ConfirmationCount)
	v.Badge = &badge
	return v, nil
}

// HasConfirmed — verilen rehberin bu mekanı (içinde bulunulan dönemde) doğrulayıp
// doğrulamadığını döner. venue_confirmations'ta kayıt varsa true. Kayıtlar silinmez;
// dönemselliği belirlemek isteyen çağıranlar created_at'i güncel periyot penceresiyle
// karşılaştırmalıdır.
func (r *VenueRepo) HasConfirmed(ctx context.Context, venueID, guideID string) (bool, error) {
	var exists bool
	err := r.db.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM venue_confirmations WHERE venue_id = $1 AND guide_id = $2)`,
		venueID, guideID,
	).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("doğrulama durumu sorgulanamadı: %w", err)
	}
	return exists, nil
}

// ConfirmingGuide — içinde bulunulan dönemde bir mekanı doğrulamış rehber özeti.
type ConfirmingGuide struct {
	GuideID      string    `json:"guide_id"`
	GuideName    string    `json:"guide_name"`
	GuideSurname *string   `json:"guide_surname,omitempty"`
	GuideEmail   string    `json:"guide_email"`
	CreatedAt    time.Time `json:"created_at"`
}

// ListConfirmingGuides — mekanı doğrulamış tüm rehberlerin listesi (ekleyen dahil,
// eğer ekleyen de doğrulamışsa). Kayıtlar silinmez; yalnızca güncel periyodu görmek
// isteyen çağıranlar sonucu created_at'e göre filtrelemelidir.
func (r *VenueRepo) ListConfirmingGuides(ctx context.Context, venueID string) ([]ConfirmingGuide, error) {
	rows, err := r.db.Query(ctx,
		`SELECT vc.guide_id, u.name, u.surname, u.email, vc.created_at
		 FROM venue_confirmations vc
		 JOIN users u ON u.id = vc.guide_id
		 WHERE vc.venue_id = $1
		 ORDER BY vc.created_at ASC`,
		venueID,
	)
	if err != nil {
		return nil, fmt.Errorf("doğrulayan rehberler listelenemedi: %w", err)
	}
	defer rows.Close()

	var result []ConfirmingGuide
	for rows.Next() {
		var g ConfirmingGuide
		if err := rows.Scan(&g.GuideID, &g.GuideName, &g.GuideSurname, &g.GuideEmail, &g.CreatedAt); err != nil {
			return nil, err
		}
		result = append(result, g)
	}
	return result, rows.Err()
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
	// Konum (lat/lng) güncellendiğinde google_place_id de doğrudan $8'e set edilir
	// (NULL olsa bile). Çünkü yeni konum eski place_id'yi geçersiz kılar — aksi
	// halde "Haritada Aç" eski place_id'nin konumunu açar. Konum değişmiyorsa
	// COALESCE ile eski place_id korunur.
	query := `
		UPDATE venues SET
			name            = COALESCE($2, name),
			city            = COALESCE($3, city),
			district        = COALESCE($4, district),
			location        = CASE WHEN $5::float8 IS NOT NULL AND $6::float8 IS NOT NULL
			                       THEN ST_MakePoint($6, $5)::geography
			                       ELSE location END,
			notes           = COALESCE($7, notes),
			google_place_id = CASE WHEN $5::float8 IS NOT NULL AND $6::float8 IS NOT NULL
			                       THEN $8
			                       ELSE COALESCE($8, google_place_id) END,
			updated_at      = NOW()
		WHERE id = $1 AND deleted_at IS NULL`

	result, err := r.db.Exec(ctx, query, id, name, city, district, lat, lng, notes, googlePlaceID)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			// Aynı google_place_id'yi başka bir mekan kullanıyor.
			return ErrAlreadyExists
		}
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

// FindByUserID — kullanıcının eklediği mekanları liste döner.
func (r *VenueRepo) FindByUserID(ctx context.Context, userID string) ([]models.Venue, error) {
	rows, err := r.db.Query(ctx,
		`SELECT id, name, city, status, created_at
		 FROM venues
		 WHERE added_by = $1 AND deleted_at IS NULL
		 ORDER BY created_at DESC`,
		userID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []models.Venue
	for rows.Next() {
		v := models.Venue{}
		if err := rows.Scan(&v.ID, &v.Name, &v.City, &v.Status, &v.CreatedAt); err != nil {
			return nil, err
		}
		list = append(list, v)
	}
	if list == nil {
		list = []models.Venue{}
	}
	return list, rows.Err()
}

// CountToday — [todayStart, tomorrow) aralığında oluşturulan mekan sayısını döner.
func (r *VenueRepo) CountToday(ctx context.Context, todayStart, tomorrow time.Time) (int, error) {
	var count int
	err := r.db.QueryRow(ctx,
		`SELECT COUNT(*) FROM venues WHERE created_at >= $1 AND created_at < $2 AND deleted_at IS NULL`,
		todayStart, tomorrow,
	).Scan(&count)
	return count, err
}

// CountByDay — [from, to) aralığında gün bazlı yeni mekan sayılarını döner.
func (r *VenueRepo) CountByDay(ctx context.Context, from, to time.Time) ([]DayCount, error) {
	rows, err := r.db.Query(ctx,
		`SELECT DATE(created_at AT TIME ZONE 'UTC') AS day, COUNT(*)::int
		 FROM venues WHERE created_at >= $1 AND created_at < $2 AND deleted_at IS NULL
		 GROUP BY day ORDER BY day`,
		from, to,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []DayCount
	for rows.Next() {
		var dc DayCount
		var day time.Time
		if err := rows.Scan(&day, &dc.Count); err != nil {
			return nil, err
		}
		dc.Date = day.Format("2006-01-02")
		list = append(list, dc)
	}
	if list == nil {
		list = []DayCount{}
	}
	return list, rows.Err()
}
