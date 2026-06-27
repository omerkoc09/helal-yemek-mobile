//go:build integration

package repository_test

import (
	"context"
	"errors"
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

func TestFindByIDIncludesBadge(t *testing.T) {
	truncate(t)
	ctx := context.Background()
	repo := repository.NewVenueRepo(testPool)

	adder := insertGuideInCity(t, "İzmir")
	c1 := insertGuideInCity(t, "İzmir")
	c2 := insertGuideInCity(t, "İzmir")
	venueID := insertVenueInCity(t, adder, "İzmir", nil)

	if err := repo.ConfirmVenue(ctx, venueID, c1, "İzmir"); err != nil {
		t.Fatalf("c1 confirm: %v", err)
	}
	if err := repo.ConfirmVenue(ctx, venueID, c2, "İzmir"); err != nil {
		t.Fatalf("c2 confirm: %v", err)
	}

	v, err := repo.FindByID(ctx, venueID)
	if err != nil {
		t.Fatalf("FindByID hata: %v", err)
	}
	if v.ConfirmationCount != 2 {
		t.Errorf("ConfirmationCount = %d, want 2", v.ConfirmationCount)
	}
	if v.Badge == nil || v.Badge.Level != "silver" {
		t.Errorf("Badge = %+v, want level silver", v.Badge)
	}
}

func TestFindByGooglePlaceID(t *testing.T) {
	truncate(t)
	ctx := context.Background()
	repo := repository.NewVenueRepo(testPool)

	adder := insertGuideInCity(t, "Bursa")
	placeID := "ChIJ_test_dup_123"
	venueID := insertVenueInCity(t, adder, "Bursa", &placeID)

	found, err := repo.FindByGooglePlaceID(ctx, placeID)
	if err != nil {
		t.Fatalf("FindByGooglePlaceID hata: %v", err)
	}
	if found.ID != venueID {
		t.Errorf("ID = %s, want %s", found.ID, venueID)
	}
	if found.Badge == nil {
		t.Errorf("Badge nil olmamalı")
	}

	_, err = repo.FindByGooglePlaceID(ctx, "ChIJ_yok_olmayan")
	if !errors.Is(err, repository.ErrNotFound) {
		t.Errorf("olmayan place_id için ErrNotFound bekleniyor, got %v", err)
	}
}

func TestVerifyByGuideResetsConfirmations(t *testing.T) {
	truncate(t)
	ctx := context.Background()
	repo := repository.NewVenueRepo(testPool)

	adder := insertGuideInCity(t, "İstanbul")
	c1 := insertGuideInCity(t, "İstanbul")
	c2 := insertGuideInCity(t, "İstanbul")
	venueID := insertVenueInCity(t, adder, "İstanbul", nil)

	if err := repo.ConfirmVenue(ctx, venueID, c1, "İstanbul"); err != nil {
		t.Fatalf("c1 confirm: %v", err)
	}
	if err := repo.ConfirmVenue(ctx, venueID, c2, "İstanbul"); err != nil {
		t.Fatalf("c2 confirm: %v", err)
	}

	// Ekleyen yeniden doğrular → reset tetiklenir.
	dropped, err := repo.VerifyByGuide(ctx, venueID, adder, 30)
	if err != nil {
		t.Fatalf("VerifyByGuide: %v", err)
	}

	// İki dönemsel onay düşmeli.
	if len(dropped) != 2 {
		t.Errorf("dropped guide sayısı = %d, want 2", len(dropped))
	}
	gotSet := map[string]bool{}
	for _, g := range dropped {
		gotSet[g] = true
	}
	if !gotSet[c1] || !gotSet[c2] {
		t.Errorf("dropped = %v, c1=%s c2=%s beklendi", dropped, c1, c2)
	}

	v, err := repo.FindByID(ctx, venueID)
	if err != nil {
		t.Fatalf("FindByID: %v", err)
	}
	if v.ConfirmationCount != 0 {
		t.Errorf("ConfirmationCount = %d, want 0", v.ConfirmationCount)
	}
	if v.IsDoubleVerified {
		t.Errorf("IsDoubleVerified = true, want false")
	}
	if v.Badge == nil || v.Badge.Level != "base" {
		t.Errorf("Badge = %+v, want level base", v.Badge)
	}

	// venue_confirmations gerçekten temizlendi mi?
	var remaining int
	_ = testPool.QueryRow(ctx,
		`SELECT COUNT(*) FROM venue_confirmations WHERE venue_id = $1`, venueID,
	).Scan(&remaining)
	if remaining != 0 {
		t.Errorf("kalan confirmation = %d, want 0", remaining)
	}
}

func TestVerifyByGuideRejectsNonAdder(t *testing.T) {
	truncate(t)
	ctx := context.Background()
	repo := repository.NewVenueRepo(testPool)

	adder := insertGuideInCity(t, "İstanbul")
	other := insertGuideInCity(t, "İstanbul")
	venueID := insertVenueInCity(t, adder, "İstanbul", nil)

	// added_by olmayan biri re-verify edemez → ErrNotFound, reset olmaz.
	if _, err := repo.VerifyByGuide(ctx, venueID, other, 30); err == nil {
		t.Errorf("added_by olmayan için hata bekleniyor")
	}
}
