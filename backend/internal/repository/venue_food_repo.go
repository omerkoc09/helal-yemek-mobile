package repository

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/omerkoc/caiz-mi/internal/models"
)

// GetAllFoodCategoriesWithItems — tüm yemek kategorilerini çeşitleriyle birlikte döndürür.
func (r *VenueRepo) GetAllFoodCategoriesWithItems(ctx context.Context) ([]models.FoodCategory, error) {
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
		c.Items = []models.FoodItem{}
		categories = append(categories, c)
	}
	if err := catRows.Err(); err != nil {
		return nil, err
	}

	// Tüm item'ları tek sorguda çek
	itemRows, err := r.db.Query(ctx,
		`SELECT id, category_id, key, name, is_custom FROM food_items ORDER BY category_id, id`)
	if err != nil {
		return nil, fmt.Errorf("yemek çeşitleri sorgusu başarısız: %w", err)
	}
	defer itemRows.Close()

	// category_id → index map
	catIndex := make(map[int]int)
	for i, c := range categories {
		catIndex[c.ID] = i
	}

	for itemRows.Next() {
		item := models.FoodItem{}
		if err := itemRows.Scan(&item.ID, &item.CategoryID, &item.Key, &item.Name, &item.IsCustom); err != nil {
			return nil, err
		}
		if idx, ok := catIndex[item.CategoryID]; ok {
			categories[idx].Items = append(categories[idx].Items, item)
		}
	}

	if categories == nil {
		categories = []models.FoodCategory{}
	}
	return categories, itemRows.Err()
}

// SetVenueFoodItems — mekanın yemek çeşitlerini kaydeder (delete+insert).
func (r *VenueRepo) SetVenueFoodItems(ctx context.Context, venueID string, foodItemIDs []int) error {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx) //nolint

	if _, err := tx.Exec(ctx, `DELETE FROM venue_food_items WHERE venue_id = $1`, venueID); err != nil {
		return fmt.Errorf("yemek çeşitleri silinemedi: %w", err)
	}

	for _, fid := range foodItemIDs {
		if _, err := tx.Exec(ctx,
			`INSERT INTO venue_food_items (venue_id, food_item_id) VALUES ($1, $2) ON CONFLICT DO NOTHING`,
			venueID, fid,
		); err != nil {
			return fmt.Errorf("yemek çeşidi eklenemedi (id=%d): %w", fid, err)
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

// GetFoodItemsByVenueID — mekanın seçili yemek çeşitlerini döndürür.
func (r *VenueRepo) GetFoodItemsByVenueID(ctx context.Context, venueID string) ([]models.FoodItem, error) {
	rows, err := r.db.Query(ctx,
		`SELECT fi.id, fi.category_id, fi.key, fi.name, fi.is_custom
		 FROM food_items fi
		 JOIN venue_food_items vfi ON vfi.food_item_id = fi.id
		 WHERE vfi.venue_id = $1
		 ORDER BY fi.category_id, fi.id`,
		venueID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []models.FoodItem
	for rows.Next() {
		item := models.FoodItem{}
		if err := rows.Scan(&item.ID, &item.CategoryID, &item.Key, &item.Name, &item.IsCustom); err != nil {
			return nil, err
		}
		list = append(list, item)
	}
	if list == nil {
		list = []models.FoodItem{}
	}
	return list, rows.Err()
}

// CreateCustomFoodItem — kullanıcının eklediği özel yemek çeşidini kaydeder.
func (r *VenueRepo) CreateCustomFoodItem(ctx context.Context, categoryID int, key, name string) (*models.FoodItem, error) {
	item := &models.FoodItem{}
	err := r.db.QueryRow(ctx,
		`INSERT INTO food_items (category_id, key, name, is_custom)
		 VALUES ($1, $2, $3, true)
		 ON CONFLICT (category_id, key) DO UPDATE SET key = food_items.key
		 RETURNING id, category_id, key, name, is_custom`,
		categoryID, key, name,
	).Scan(&item.ID, &item.CategoryID, &item.Key, &item.Name, &item.IsCustom)
	if err != nil {
		return nil, fmt.Errorf("özel yemek çeşidi eklenemedi: %w", err)
	}
	return item, nil
}

// CreateFoodCategory — yeni bir yemek kategorisi oluşturur (admin).
func (r *VenueRepo) CreateFoodCategory(ctx context.Context, key, name string) (*models.FoodCategory, error) {
	cat := &models.FoodCategory{Items: []models.FoodItem{}}
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

// DeleteFoodCategory — bir yemek kategorisini ve altındaki çeşitleri siler (admin).
// food_items.category_id ON DELETE CASCADE olduğu için alt çeşitler otomatik silinir;
// venue_food_items de food_items üzerinden CASCADE ile temizlenir.
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

// UpdateFoodItem — bir yemek çeşidinin adını günceller (admin).
func (r *VenueRepo) UpdateFoodItem(ctx context.Context, id int, name string) error {
	result, err := r.db.Exec(ctx,
		`UPDATE food_items SET name = $1 WHERE id = $2`,
		name, id,
	)
	if err != nil {
		return fmt.Errorf("yemek çeşidi güncellenemedi: %w", err)
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// DeleteFoodItem — bir yemek çeşidini siler (admin).
// venue_food_items.food_item_id ON DELETE CASCADE olduğu için mekanlardaki
// referanslar otomatik temizlenir.
func (r *VenueRepo) DeleteFoodItem(ctx context.Context, id int) error {
	result, err := r.db.Exec(ctx, `DELETE FROM food_items WHERE id = $1`, id)
	if err != nil {
		return fmt.Errorf("yemek çeşidi silinemedi: %w", err)
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}
