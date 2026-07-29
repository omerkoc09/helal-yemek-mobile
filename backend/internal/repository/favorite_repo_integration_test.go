//go:build integration

package repository_test

import (
	"context"
	"testing"
	"time"

	"github.com/omerkoc/itimat-mobile/internal/repository"
)

// Favoriler listesi, mekan kartının gösterebilmesi için şehir/ilçe, puan,
// yorum sayısı, mutfak özeti, rozet ve fotoğrafları da taşımalı. Eksik
// dönerse kullanıcı favorilerinde yalnızca mekan adını görür.
func TestFavoritesListReturnsCardFields(t *testing.T) {
	truncate(t)
	ctx := context.Background()

	guideID := insertTestUser(t)
	userID := insertTestUser(t)
	venueID := insertTestVenue(t, guideID, venueOpts{
		verificationDueAt: time.Now().Add(90 * 24 * time.Hour),
	})

	// İlçe: kart "İstanbul / Fatih" satırını buradan kurar.
	if _, err := testPool.Exec(ctx,
		`UPDATE venues SET district = 'Fatih' WHERE id = $1`, venueID,
	); err != nil {
		t.Fatalf("ilçe güncellenemedi: %v", err)
	}

	// Puan ortalaması ve yorum sayısı için iki yorum (4 ve 5 => ortalama 4.5).
	for _, rating := range []int{4, 5} {
		reviewerID := insertTestUser(t)
		if _, err := testPool.Exec(ctx,
			`INSERT INTO reviews (venue_id, user_id, rating, comment)
			 VALUES ($1, $2, $3, 'test')`,
			venueID, reviewerID, rating,
		); err != nil {
			t.Fatalf("yorum eklenemedi: %v", err)
		}
	}

	// Mutfak kategorisi: kart alt satırında "categories_str" olarak görünür.
	var categoryID int
	if err := testPool.QueryRow(ctx,
		`SELECT id FROM food_categories ORDER BY id LIMIT 1`,
	).Scan(&categoryID); err != nil {
		t.Fatalf("kategori bulunamadı: %v", err)
	}
	if _, err := testPool.Exec(ctx,
		`INSERT INTO venue_categories (venue_id, category_id) VALUES ($1, $2)`,
		venueID, categoryID,
	); err != nil {
		t.Fatalf("mekan kategorisi eklenemedi: %v", err)
	}

	// Fotoğraf: kart görseli.
	if _, err := testPool.Exec(ctx,
		`INSERT INTO venue_photos (venue_id, url, uploaded_by)
		 VALUES ($1, 'venues/test.jpg', $2)`,
		venueID, guideID,
	); err != nil {
		t.Fatalf("fotoğraf eklenemedi: %v", err)
	}

	if _, err := testPool.Exec(ctx,
		`INSERT INTO favorites (user_id, venue_id) VALUES ($1, $2)`,
		userID, venueID,
	); err != nil {
		t.Fatalf("favori eklenemedi: %v", err)
	}

	repo := repository.NewFavoriteRepo(testPool)
	venues, err := repo.ListByUser(ctx, userID)
	if err != nil {
		t.Fatalf("ListByUser hatası: %v", err)
	}
	if len(venues) != 1 {
		t.Fatalf("1 favori bekleniyordu, %d geldi", len(venues))
	}

	v := venues[0]

	if v.District == nil || *v.District != "Fatih" {
		t.Errorf("ilçe 'Fatih' bekleniyordu, geldi: %v", v.District)
	}
	if v.AverageRating == nil || *v.AverageRating < 4.4 || *v.AverageRating > 4.6 {
		t.Errorf("ortalama puan ~4.5 bekleniyordu, geldi: %v", v.AverageRating)
	}
	if v.ReviewCount != 2 {
		t.Errorf("yorum sayısı 2 bekleniyordu, geldi: %d", v.ReviewCount)
	}
	if v.CategoriesStr == nil || *v.CategoriesStr == "" {
		t.Errorf("mutfak özeti bekleniyordu, geldi: %v", v.CategoriesStr)
	}
	if v.Badge == nil {
		t.Error("rozet bekleniyordu, nil geldi")
	}
	if len(v.Photos) != 1 {
		t.Errorf("1 fotoğraf bekleniyordu, %d geldi", len(v.Photos))
	}
	if len(v.Categories) != 1 {
		t.Errorf("1 kategori bekleniyordu, %d geldi", len(v.Categories))
	}
}

// Favorilerin en yeni eklenen önce gelmesi (mevcut davranış) korunmalı.
func TestFavoritesListOrderedByNewestFirst(t *testing.T) {
	truncate(t)
	ctx := context.Background()

	guideID := insertTestUser(t)
	userID := insertTestUser(t)
	firstID := insertTestVenue(t, guideID, venueOpts{
		verificationDueAt: time.Now().Add(90 * 24 * time.Hour),
	})
	secondID := insertTestVenue(t, guideID, venueOpts{
		verificationDueAt: time.Now().Add(90 * 24 * time.Hour),
	})

	if _, err := testPool.Exec(ctx,
		`INSERT INTO favorites (user_id, venue_id, created_at)
		 VALUES ($1, $2, NOW() - INTERVAL '1 hour'), ($1, $3, NOW())`,
		userID, firstID, secondID,
	); err != nil {
		t.Fatalf("favoriler eklenemedi: %v", err)
	}

	repo := repository.NewFavoriteRepo(testPool)
	venues, err := repo.ListByUser(ctx, userID)
	if err != nil {
		t.Fatalf("ListByUser hatası: %v", err)
	}
	if len(venues) != 2 {
		t.Fatalf("2 favori bekleniyordu, %d geldi", len(venues))
	}
	if venues[0].ID != secondID {
		t.Errorf("en son eklenen favori ilk sırada olmalıydı")
	}
}
