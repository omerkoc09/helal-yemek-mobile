package repository

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5/pgconn"
	"github.com/omerkoc/itimat-mobile/internal/models"
)

// SetCriteria — mekana ait kriterleri venue_criteria tablosuna kaydeder.
// Varolan kriterleri silip yeniden yazar (upsert mantığı).
func (r *VenueRepo) SetCriteria(ctx context.Context, venueID string, criteriaIDs []int) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx) //nolint

	if _, err := tx.Exec(ctx, `DELETE FROM venue_criteria WHERE venue_id = $1`, venueID); err != nil {
		return fmt.Errorf("kriterler silinemedi: %w", err)
	}

	for _, cid := range criteriaIDs {
		if _, err := tx.Exec(ctx,
			`INSERT INTO venue_criteria (venue_id, criteria_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
			venueID, cid,
		); err != nil {
			return fmt.Errorf("kriter eklenemedi (id=%d): %w", cid, err)
		}
	}
	return tx.Commit(ctx)
}

// GetCriteriaByVenueID — mekana ait güvenilirlik kriter listesini döndürür.
func (r *VenueRepo) GetCriteriaByVenueID(ctx context.Context, venueID string) ([]models.TrustCriteria, error) {
	query := `
		SELECT hc.id, hc.key, hc.name, hc.description
		FROM trust_criteria hc
		JOIN venue_criteria vc ON vc.criteria_id = hc.id
		WHERE vc.venue_id = $1
		ORDER BY hc.id`

	rows, err := r.db.Query(ctx, query, venueID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []models.TrustCriteria
	for rows.Next() {
		c := models.TrustCriteria{}
		if err := rows.Scan(&c.ID, &c.Key, &c.Name, &c.Description); err != nil {
			return nil, err
		}
		list = append(list, c)
	}
	if list == nil {
		list = []models.TrustCriteria{}
	}
	return list, rows.Err()
}

// GetAllCriteria — tüm güvenilirlik kriterlerini döndürür.
func (r *VenueRepo) GetAllCriteria(ctx context.Context) ([]models.TrustCriteria, error) {
	rows, err := r.db.Query(ctx, `SELECT id, key, name, description FROM trust_criteria ORDER BY id`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []models.TrustCriteria
	for rows.Next() {
		c := models.TrustCriteria{}
		if err := rows.Scan(&c.ID, &c.Key, &c.Name, &c.Description); err != nil {
			return nil, err
		}
		list = append(list, c)
	}
	return list, rows.Err()
}

// CreateTrustCriteria — yeni bir güvenilirlik kriteri oluşturur (admin).
func (r *VenueRepo) CreateTrustCriteria(ctx context.Context, key, name string, description *string) (*models.TrustCriteria, error) {
	c := &models.TrustCriteria{}
	err := r.db.QueryRow(ctx,
		`INSERT INTO trust_criteria (key, name, description)
		 VALUES ($1, $2, $3)
		 RETURNING id, key, name, description`,
		key, name, description,
	).Scan(&c.ID, &c.Key, &c.Name, &c.Description)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return nil, ErrAlreadyExists
		}
		return nil, fmt.Errorf("güvenilirlik kriteri eklenemedi: %w", err)
	}
	return c, nil
}

// UpdateTrustCriteria — bir güvenilirlik kriterinin adını ve açıklamasını günceller (admin).
// key kasıtlı olarak güncellenmez; kalıcı tanımlayıcı olarak kalır.
func (r *VenueRepo) UpdateTrustCriteria(ctx context.Context, id int, name string, description *string) error {
	result, err := r.db.Exec(ctx,
		`UPDATE trust_criteria SET name = $2, description = $3 WHERE id = $1`,
		id, name, description,
	)
	if err != nil {
		return fmt.Errorf("güvenilirlik kriteri güncellenemedi: %w", err)
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// DeleteTrustCriteria — bir güvenilirlik kriterini siler (admin).
// venue_criteria.criteria_id FK ilişkisi nedeniyle önce mekan işaretlemeleri
// temizlenir, ardından kriter silinir (tek transaction).
func (r *VenueRepo) DeleteTrustCriteria(ctx context.Context, id int) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx) //nolint

	if _, err := tx.Exec(ctx, `DELETE FROM venue_criteria WHERE criteria_id = $1`, id); err != nil {
		return fmt.Errorf("kriter mekan bağlantıları silinemedi: %w", err)
	}

	result, err := tx.Exec(ctx, `DELETE FROM trust_criteria WHERE id = $1`, id)
	if err != nil {
		return fmt.Errorf("güvenilirlik kriteri silinemedi: %w", err)
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}

	return tx.Commit(ctx)
}
