package repository

import (
	"context"
	"fmt"

	"github.com/omerkoc/caiz-mi/internal/models"
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
