package repository

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"

	"github.com/omerkoc/caiz-mi/internal/models"
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
		list = append(list, p)
	}
	if list == nil {
		list = []models.VenuePhoto{}
	}
	return list, rows.Err()
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
	return p, err
}
