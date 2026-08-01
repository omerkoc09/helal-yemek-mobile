package repository

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"

	"github.com/omerkoc/itimat-mobile/internal/models"
)

// AddPhoto — mekana yeni fotoğraf ekler.
func (r *VenueRepo) AddPhoto(ctx context.Context, photo *models.VenuePhoto) error {
	query := `
		INSERT INTO venue_photos (venue_id, url, uploaded_by, is_primary)
		VALUES ($1, $2, $3, $4)
		RETURNING id, created_at`
	return r.db.QueryRow(ctx, query,
		photo.VenueID, photo.URL, photo.UploadedBy, photo.IsPrimary,
	).Scan(&photo.ID, &photo.CreatedAt)
}

// GetPhotosByVenueID — mekana ait fotoğrafları döndürür.
func (r *VenueRepo) GetPhotosByVenueID(ctx context.Context, venueID string) ([]models.VenuePhoto, error) {
	rows, err := r.db.Query(ctx,
		`SELECT id, venue_id, url, uploaded_by, is_primary, created_at
		 FROM venue_photos WHERE venue_id = $1 ORDER BY is_primary DESC, created_at`,
		venueID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []models.VenuePhoto
	for rows.Next() {
		p := models.VenuePhoto{}
		if err := rows.Scan(&p.ID, &p.VenueID, &p.URL, &p.UploadedBy, &p.IsPrimary, &p.CreatedAt); err != nil {
			return nil, err
		}
		// DB'de anahtar saklanır; istemciye tam URL gider.
		p.URL = r.publicURL(p.URL)
		list = append(list, p)
	}
	if list == nil {
		list = []models.VenuePhoto{}
	}
	return list, rows.Err()
}

// SetPrimaryPhoto — verilen fotoğrafı mekanın kapağı yapar, diğerlerinin
// kapak işaretini kaldırır.
//
// Tek işlemde (transaction) yapılır: iki UPDATE arasında hata olursa mekan ya
// kapaksız ya da çift kapaklı kalırdı; `is_primary` üzerinde DB kısıtı yok,
// tekilliği bu katman korur.
// Fotoğraf bu mekana ait değilse ErrNotFound döner.
func (r *VenueRepo) SetPrimaryPhoto(ctx context.Context, photoID, venueID string) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx) //nolint:errcheck // commit sonrası no-op

	result, err := tx.Exec(ctx,
		`UPDATE venue_photos SET is_primary = true WHERE id = $1 AND venue_id = $2`,
		photoID, venueID,
	)
	if err != nil {
		return err
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}

	if _, err := tx.Exec(ctx,
		`UPDATE venue_photos SET is_primary = false WHERE venue_id = $1 AND id <> $2`,
		venueID, photoID,
	); err != nil {
		return err
	}

	return tx.Commit(ctx)
}

// PromoteAnyPhotoToPrimary — mekanda kapak kalmadıysa en eski fotoğrafı kapak yapar.
//
// Kapak fotoğrafı silindiğinde mekan kapaksız kalıyordu; galeri sıralaması
// (`is_primary DESC, created_at`) yine bir şey gösterse de `is_primary` ile
// kapak arayan istemciler boş dönerdi. Kapak zaten varsa hiçbir şey yapmaz.
func (r *VenueRepo) PromoteAnyPhotoToPrimary(ctx context.Context, venueID string) error {
	_, err := r.db.Exec(ctx,
		`UPDATE venue_photos SET is_primary = true
		 WHERE id = (
		     SELECT id FROM venue_photos
		     WHERE venue_id = $1
		       AND NOT EXISTS (
		           SELECT 1 FROM venue_photos WHERE venue_id = $1 AND is_primary
		       )
		     ORDER BY created_at
		     LIMIT 1
		 )`,
		venueID,
	)
	return err
}

// DeletePhoto — fotoğrafı veritabanından siler.
func (r *VenueRepo) DeletePhoto(ctx context.Context, photoID, venueID string) error {
	result, err := r.db.Exec(ctx,
		`DELETE FROM venue_photos WHERE id = $1 AND venue_id = $2`,
		photoID, venueID,
	)
	if err != nil {
		return err
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// FindPhotoByID — fotoğrafı ID ile bulur.
func (r *VenueRepo) FindPhotoByID(ctx context.Context, photoID string) (*models.VenuePhoto, error) {
	p := &models.VenuePhoto{}
	err := r.db.QueryRow(ctx,
		`SELECT id, venue_id, url, uploaded_by, is_primary, created_at FROM venue_photos WHERE id = $1`,
		photoID,
	).Scan(&p.ID, &p.VenueID, &p.URL, &p.UploadedBy, &p.IsPrimary, &p.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	// Tam URL'e çevrilir; silme akışı da bunu kabul eder (Delete filepath.Base
	// kullandığı için hem anahtar hem tam URL ile çalışır).
	p.URL = r.publicURL(p.URL)
	return p, err
}
