//go:build integration

package repository_test

import (
	"context"
	"errors"
	"fmt"
	"testing"
	"time"

	"github.com/omerkoc/caiz-mi/internal/models"
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

	if err := repo.ConfirmVenue(ctx, venueID, confirmer, "İstanbul", 90); err != nil {
		t.Fatalf("ConfirmVenue hata: %v", err)
	}

	v, err := repo.FindByID(ctx, venueID)
	if err != nil {
		t.Fatalf("FindByID hata: %v", err)
	}
	if v.ConfirmationCount != 1 {
		t.Errorf("ConfirmationCount = %d, want 1", v.ConfirmationCount)
	}

	// Aynı guide tekrar doğrulayamaz.
	if err := repo.ConfirmVenue(ctx, venueID, confirmer, "İstanbul", 90); err == nil {
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

	if err := repo.ConfirmVenue(ctx, venueID, confirmer, "Ankara", 90); err == nil {
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

	if err := repo.ConfirmVenue(ctx, venueID, c1, "İzmir", 90); err != nil {
		t.Fatalf("c1 confirm: %v", err)
	}
	if err := repo.ConfirmVenue(ctx, venueID, c2, "İzmir", 90); err != nil {
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

// Not: eski TestVerifyByGuideResetsConfirmations / TestVerifyByGuideRejectsNonAdder
// testleri kaldırıldı — VerifyByGuide artık dönemsel onayları silmiyor (ownerless
// model) ve yetkiyi "ekleyen VEYA daha önce doğrulamış rehber"e genişletti.
// Yerlerini alan testler: TestVerifyByGuide_ConfirmerCanReverify ve
// TestVerifyByGuide_UnrelatedGuideRejected (venue_status_repo_integration_test.go).

// TestConfirmVenue_AdderCanConfirm — ownerless doğrulama: mekanı ekleyen kişi
// artık kendi mekanını doğrulayabilmeli ve confirmation_count türetilmiş
// (FreshConfirmationCount ile senkron) olmalı.
// TestFindNearbyIncludesRating — harita listesi (FindNearby) puan/yorum sayısını
// döndürmeli: yorum yoksa 0.0 / 0, yorum varsa ortalama.
func TestFindNearbyIncludesRating(t *testing.T) {
	truncate(t)
	ctx := context.Background()
	repo := repository.NewVenueRepo(testPool)

	adder := insertGuideInCity(t, "İstanbul")
	venueID := insertVenueInCity(t, adder, "İstanbul", nil)

	// İlçe ata: harita sheet'i "İl / İlçe" göstermek için district'i de bekler.
	if _, err := testPool.Exec(ctx,
		`UPDATE venues SET district = 'Fatih' WHERE id = $1`, venueID,
	); err != nil {
		t.Fatalf("district güncellenemedi: %v", err)
	}

	// İki yorum: 4 ve 5 → ortalama 4.5, sayı 2.
	for _, rating := range []int{4, 5} {
		reviewer := insertGuideInCity(t, "İstanbul")
		if _, err := testPool.Exec(ctx,
			`INSERT INTO reviews (venue_id, user_id, rating) VALUES ($1, $2, $3)`,
			venueID, reviewer, rating,
		); err != nil {
			t.Fatalf("yorum eklenemedi: %v", err)
		}
	}

	// Mekan (29.0, 41.0); aynı noktadan geniş yarıçapla ara.
	venues, err := repo.FindNearby(ctx, 41.0, 29.0, 5000)
	if err != nil {
		t.Fatalf("FindNearby hata: %v", err)
	}

	var found *models.Venue
	for i := range venues {
		if venues[i].ID == venueID {
			found = &venues[i]
			break
		}
	}
	if found == nil {
		t.Fatalf("mekan yakın listede yok")
	}
	if found.AverageRating == nil || *found.AverageRating != 4.5 {
		t.Errorf("AverageRating = %v, want 4.5", found.AverageRating)
	}
	if found.ReviewCount != 2 {
		t.Errorf("ReviewCount = %d, want 2", found.ReviewCount)
	}
	if found.District == nil || *found.District != "Fatih" {
		t.Errorf("District = %v, want Fatih", found.District)
	}
}

func TestConfirmVenue_AdderCanConfirm(t *testing.T) {
	truncate(t)
	ctx := context.Background()
	repo := repository.NewVenueRepo(testPool)

	adder := insertTestUser(t)
	venueID := insertTestVenue(t, adder, venueOpts{
		status:            "approved",
		verificationDueAt: time.Now().Add(90 * 24 * time.Hour),
	})

	// Ekleyen artık kendi mekanını doğrulayabilmeli (yeni imza: periodDays'li).
	// guideCity boş bırakılır çünkü insertTestUser guide_city'yi NULL bırakıyor
	// (şehir kontrolü bu durumda atlanır).
	if err := repo.ConfirmVenue(ctx, venueID, adder, "", 90); err != nil {
		t.Fatalf("ekleyen doğrulayamadı: %v", err)
	}

	n, err := repo.FreshConfirmationCount(ctx, venueID, 90)
	if err != nil {
		t.Fatalf("count: %v", err)
	}
	if n != 1 {
		t.Errorf("count = %d, want 1", n)
	}
}
