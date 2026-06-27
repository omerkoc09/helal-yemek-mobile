//go:build integration

package repository_test

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/omerkoc/caiz-mi/internal/repository"
)

// insertGuideInCity — verilen şehirde guide_city set edilmiş guide oluşturur.
func insertGuideInCity(t *testing.T, city string) string {
	t.Helper()
	var id string
	err := testPool.QueryRow(context.Background(),
		`INSERT INTO users (email, name, password_hash, role, guide_city)
		 VALUES ($1, 'Test Guide', 'hash', 'guide', $2) RETURNING id`,
		fmt.Sprintf("test-%d@example.com", time.Now().UnixNano()), city,
	).Scan(&id)
	if err != nil {
		t.Fatalf("guide eklenemedi: %v", err)
	}
	return id
}

// insertVenueInCity — verilen şehirde approved mekan oluşturur (opsiyonel place_id).
func insertVenueInCity(t *testing.T, addedBy, city string, placeID *string) string {
	t.Helper()
	var id string
	err := testPool.QueryRow(context.Background(),
		`INSERT INTO venues
		   (name, city, location, status, added_by, google_place_id)
		 VALUES
		   ('Test Mekan', $1,
		    ST_SetSRID(ST_MakePoint(29.0, 41.0), 4326)::geography,
		    'approved', $2, $3)
		 RETURNING id`,
		city, addedBy, placeID,
	).Scan(&id)
	if err != nil {
		t.Fatalf("mekan eklenemedi: %v", err)
	}
	return id
}

func TestConfirmVenueIncrementsCount(t *testing.T) {
	truncate(t)
	ctx := context.Background()
	repo := repository.NewVenueRepo(testPool)

	adder := insertGuideInCity(t, "İstanbul")
	confirmer := insertGuideInCity(t, "İstanbul")
	venueID := insertVenueInCity(t, adder, "İstanbul", nil)

	if err := repo.ConfirmVenue(ctx, venueID, confirmer, "İstanbul"); err != nil {
		t.Fatalf("ConfirmVenue hata: %v", err)
	}

	v, err := repo.FindByID(ctx, venueID)
	if err != nil {
		t.Fatalf("FindByID hata: %v", err)
	}
	if v.ConfirmationCount != 1 {
		t.Errorf("ConfirmationCount = %d, want 1", v.ConfirmationCount)
	}
	if !v.IsDoubleVerified {
		t.Errorf("IsDoubleVerified = false, want true")
	}

	// Aynı guide tekrar doğrulayamaz.
	if err := repo.ConfirmVenue(ctx, venueID, confirmer, "İstanbul"); err == nil {
		t.Errorf("ikinci ConfirmVenue hata vermeli (zaten doğrulanmış)")
	}
}

func TestConfirmVenueRejectsWrongCity(t *testing.T) {
	truncate(t)
	ctx := context.Background()
	repo := repository.NewVenueRepo(testPool)

	adder := insertGuideInCity(t, "İstanbul")
	confirmer := insertGuideInCity(t, "Ankara")
	venueID := insertVenueInCity(t, adder, "İstanbul", nil)

	if err := repo.ConfirmVenue(ctx, venueID, confirmer, "Ankara"); err == nil {
		t.Errorf("farklı şehir guide'ı doğrulayamamalı")
	}
}
