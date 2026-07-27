package repository

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/omerkoc/itimat-mobile/internal/models"
)

// GetAllFoodCategories — tüm yemek (mutfak) kategorilerini döndürür.
func (r *VenueRepo) GetAllFoodCategories(ctx context.Context) ([]models.FoodCategory, error) {
	catRows, err := r.db.Query(ctx,
		`SELECT id, key, name, image_url FROM food_categories ORDER BY id`)
	if err != nil {
		return nil, fmt.Errorf("yemek kategorileri sorgusu başarısız: %w", err)
	}
	defer catRows.Close()

	var categories []models.FoodCategory
	for catRows.Next() {
		c := models.FoodCategory{}
		if err := catRows.Scan(&c.ID, &c.Key, &c.Name, &c.ImageURL); err != nil {
			return nil, err
		}
		// Görsel anahtarı tam URL'e çevrilir (NULL kayıtlar dokunulmadan kalır).
		if c.ImageURL != nil {
			url := r.publicURL(*c.ImageURL)
			c.ImageURL = &url
		}
		categories = append(categories, c)
	}
	if err := catRows.Err(); err != nil {
		return nil, err
	}

	if categories == nil {
		categories = []models.FoodCategory{}
	}
	return categories, nil
}

// SetVenueCategories — mekanın sunduğu mutfak kategorilerini kaydeder (delete+insert).
func (r *VenueRepo) SetVenueCategories(ctx context.Context, venueID string, categoryIDs []int) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx) //nolint

	if _, err := tx.Exec(ctx, `DELETE FROM venue_categories WHERE venue_id = $1`, venueID); err != nil {
		return fmt.Errorf("mekan kategorileri silinemedi: %w", err)
	}

	for _, cid := range categoryIDs {
		if _, err := tx.Exec(ctx,
			`INSERT INTO venue_categories (venue_id, category_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
			venueID, cid,
		); err != nil {
			return fmt.Errorf("mekan kategorisi eklenemedi (id=%d): %w", cid, err)
		}
	}
	return tx.Commit(ctx)
}

// SetFoodHalalMode — mekanın food_halal_mode değerini günceller.
func (r *VenueRepo) SetFoodHalalMode(ctx context.Context, venueID string, mode string) error {
	_, err := r.db.Exec(ctx,
		`UPDATE venues SET food_halal_mode = $1, updated_at = NOW() WHERE id = $2 AND deleted_at IS NULL`,
		mode, venueID,
	)
	return err
}

// SetExcludedProducts — mekanın sakıncalı ürün listesini günceller.
func (r *VenueRepo) SetExcludedProducts(ctx context.Context, venueID string, products []string) error {
	if products == nil {
		products = []string{}
	}
	_, err := r.db.Exec(ctx,
		`UPDATE venues SET excluded_products = $1, updated_at = NOW() WHERE id = $2 AND deleted_at IS NULL`,
		products, venueID,
	)
	return err
}

// GetCategoriesByVenueID — mekanın sunduğu mutfak kategorilerini döndürür.
func (r *VenueRepo) GetCategoriesByVenueID(ctx context.Context, venueID string) ([]models.FoodCategory, error) {
	rows, err := r.db.Query(ctx,
		`SELECT fc.id, fc.key, fc.name
		 FROM food_categories fc
		 JOIN venue_categories vc ON vc.category_id = fc.id
		 WHERE vc.venue_id = $1
		 ORDER BY fc.id`,
		venueID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []models.FoodCategory
	for rows.Next() {
		cat := models.FoodCategory{}
		if err := rows.Scan(&cat.ID, &cat.Key, &cat.Name); err != nil {
			return nil, err
		}
		list = append(list, cat)
	}
	if list == nil {
		list = []models.FoodCategory{}
	}
	return list, rows.Err()
}

// CreateFoodCategory — yeni bir yemek kategorisi oluşturur (admin).
func (r *VenueRepo) CreateFoodCategory(ctx context.Context, key, name string) (*models.FoodCategory, error) {
	cat := &models.FoodCategory{}
	err := r.db.QueryRow(ctx,
		`INSERT INTO food_categories (key, name)
		 VALUES ($1, $2)
		 RETURNING id, key, name, image_url`,
		key, name,
	).Scan(&cat.ID, &cat.Key, &cat.Name, &cat.ImageURL)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return nil, ErrAlreadyExists
		}
		return nil, fmt.Errorf("yemek kategorisi eklenemedi: %w", err)
	}
	return cat, nil
}

// UpdateFoodCategory — bir yemek kategorisinin adını günceller (admin).
func (r *VenueRepo) UpdateFoodCategory(ctx context.Context, id int, name string) error {
	result, err := r.db.Exec(ctx,
		`UPDATE food_categories SET name = $1 WHERE id = $2`,
		name, id,
	)
	if err != nil {
		return fmt.Errorf("yemek kategorisi güncellenemedi: %w", err)
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// SetFoodCategoryImage — bir yemek kategorisinin görsel URL'sini günceller (admin).
func (r *VenueRepo) SetFoodCategoryImage(ctx context.Context, id int, imageURL string) error {
	result, err := r.db.Exec(ctx,
		`UPDATE food_categories SET image_url = $1 WHERE id = $2`,
		imageURL, id,
	)
	if err != nil {
		return fmt.Errorf("kategori görseli güncellenemedi: %w", err)
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// GetFoodCategoryImageURL — bir kategorinin mevcut görsel URL'sini döndürür (eski dosyayı silmek için).
func (r *VenueRepo) GetFoodCategoryImageURL(ctx context.Context, id int) (*string, error) {
	var imageURL *string
	err := r.db.QueryRow(ctx, `SELECT image_url FROM food_categories WHERE id = $1`, id).Scan(&imageURL)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, err
	}
	return imageURL, nil
}

// DeleteFoodCategory — bir yemek (mutfak) kategorisini siler (admin).
// venue_categories.category_id ON DELETE CASCADE olduğu için mekanlardaki
// referanslar otomatik temizlenir.
func (r *VenueRepo) DeleteFoodCategory(ctx context.Context, id int) error {
	result, err := r.db.Exec(ctx, `DELETE FROM food_categories WHERE id = $1`, id)
	if err != nil {
		return fmt.Errorf("yemek kategorisi silinemedi: %w", err)
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}
