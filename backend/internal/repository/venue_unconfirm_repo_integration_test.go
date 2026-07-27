//go:build integration

package repository_test

import (
	"context"
	"errors"
	"testing"

	"github.com/omerkoc/itimat-mobile/internal/repository"
)

// TestRemoveConfirmationDropsCount — geri çekme kaydı siler ve rozet sayacını
// aynı anda düşürür (defter ile sayaç tutarlı kalmalı).
func TestRemoveConfirmationDropsCount(t *testing.T) {
	truncate(t)
	ctx := context.Background()
	repo := repository.NewVenueRepo(testPool)

	adder := insertGuideInCity(t, "İstanbul")
	c1 := insertGuideInCity(t, "İstanbul")
	c2 := insertGuideInCity(t, "İstanbul")
	venueID := insertVenueInCity(t, adder, "İstanbul", nil)

	for _, g := range []string{c1, c2} {
		if err := repo.ConfirmVenue(ctx, venueID, g, "İstanbul", 90); err != nil {
			t.Fatalf("ConfirmVenue hata: %v", err)
		}
	}

	if err := repo.RemoveConfirmation(ctx, venueID, c1, 90); err != nil {
		t.Fatalf("RemoveConfirmation hata: %v", err)
	}

	v, err := repo.FindByID(ctx, venueID)
	if err != nil {
		t.Fatalf("FindByID hata: %v", err)
	}
	if v.ConfirmationCount != 1 {
		t.Errorf("ConfirmationCount = %d, want 1", v.ConfirmationCount)
	}

	// Kayıt gerçekten silindi mi?
	var n int
	if err := testPool.QueryRow(ctx,
		`SELECT COUNT(*) FROM venue_confirmations WHERE venue_id = $1 AND guide_id = $2`,
		venueID, c1,
	).Scan(&n); err != nil {
		t.Fatalf("sayım hatası: %v", err)
	}
	if n != 0 {
		t.Errorf("doğrulama kaydı silinmemiş (n=%d)", n)
	}
}

// TestRemoveConfirmationKeepsVenueAlive — EN KRİTİK REGRESYON TESTİ.
// Geri çekme bir güven sinyalidir, mekanı öldürme eylemi değil:
// verified_at ve verification_due_at değişmemelidir.
func TestRemoveConfirmationKeepsVenueAlive(t *testing.T) {
	truncate(t)
	ctx := context.Background()
	repo := repository.NewVenueRepo(testPool)

	adder := insertGuideInCity(t, "İstanbul")
	confirmer := insertGuideInCity(t, "İstanbul")
	venueID := insertVenueInCity(t, adder, "İstanbul", nil)

	// Mekan zaten 'approved' doğuyor (insertVenueInCity); doğrulama penceresini
	// burada doldur ki geri çekmenin ona dokunmadığı ölçülebilsin.
	if _, err := testPool.Exec(ctx,
		`UPDATE venues SET verified_at = NOW(),
		        verification_due_at = NOW() + INTERVAL '90 days'
		 WHERE id = $1`, venueID,
	); err != nil {
		t.Fatalf("doğrulama penceresi ayarlanamadı: %v", err)
	}
	if err := repo.ConfirmVenue(ctx, venueID, confirmer, "İstanbul", 90); err != nil {
		t.Fatalf("ConfirmVenue hata: %v", err)
	}

	before, err := repo.FindByID(ctx, venueID)
	if err != nil {
		t.Fatalf("FindByID hata: %v", err)
	}

	if err := repo.RemoveConfirmation(ctx, venueID, confirmer, 90); err != nil {
		t.Fatalf("RemoveConfirmation hata: %v", err)
	}

	after, err := repo.FindByID(ctx, venueID)
	if err != nil {
		t.Fatalf("FindByID hata: %v", err)
	}

	if after.Status != before.Status {
		t.Errorf("status değişmemeliydi: %s → %s", before.Status, after.Status)
	}
	if !after.VerificationDueAt.Equal(*before.VerificationDueAt) {
		t.Errorf("verification_due_at değişmemeliydi: %v → %v",
			before.VerificationDueAt, after.VerificationDueAt)
	}
	if !after.VerifiedAt.Equal(*before.VerifiedAt) {
		t.Errorf("verified_at değişmemeliydi: %v → %v", before.VerifiedAt, after.VerifiedAt)
	}
}

// TestRemoveConfirmationOnlyOwnRecord — başkasının kaydı silinemez; kaydı
// olmayan rehber için ErrNotFound döner.
func TestRemoveConfirmationOnlyOwnRecord(t *testing.T) {
	truncate(t)
	ctx := context.Background()
	repo := repository.NewVenueRepo(testPool)

	adder := insertGuideInCity(t, "İstanbul")
	confirmer := insertGuideInCity(t, "İstanbul")
	stranger := insertGuideInCity(t, "İstanbul")
	venueID := insertVenueInCity(t, adder, "İstanbul", nil)

	if err := repo.ConfirmVenue(ctx, venueID, confirmer, "İstanbul", 90); err != nil {
		t.Fatalf("ConfirmVenue hata: %v", err)
	}

	err := repo.RemoveConfirmation(ctx, venueID, stranger, 90)
	if !errors.Is(err, repository.ErrNotFound) {
		t.Fatalf("ErrNotFound beklendi, alınan: %v", err)
	}

	// confirmer'ın kaydı duruyor olmalı.
	v, err := repo.FindByID(ctx, venueID)
	if err != nil {
		t.Fatalf("FindByID hata: %v", err)
	}
	if v.ConfirmationCount != 1 {
		t.Errorf("ConfirmationCount = %d, want 1 (yabancı silme etkilememeli)", v.ConfirmationCount)
	}
}

// TestRemoveConfirmationAllowsReconfirm — geri çekme kalıcı ceza değildir:
// rehber aynı mekanı tekrar doğrulayabilmeli.
func TestRemoveConfirmationAllowsReconfirm(t *testing.T) {
	truncate(t)
	ctx := context.Background()
	repo := repository.NewVenueRepo(testPool)

	adder := insertGuideInCity(t, "İstanbul")
	confirmer := insertGuideInCity(t, "İstanbul")
	venueID := insertVenueInCity(t, adder, "İstanbul", nil)

	if err := repo.ConfirmVenue(ctx, venueID, confirmer, "İstanbul", 90); err != nil {
		t.Fatalf("ilk ConfirmVenue hata: %v", err)
	}
	if err := repo.RemoveConfirmation(ctx, venueID, confirmer, 90); err != nil {
		t.Fatalf("RemoveConfirmation hata: %v", err)
	}
	if err := repo.ConfirmVenue(ctx, venueID, confirmer, "İstanbul", 90); err != nil {
		t.Fatalf("tekrar ConfirmVenue hata vermemeliydi: %v", err)
	}

	v, err := repo.FindByID(ctx, venueID)
	if err != nil {
		t.Fatalf("FindByID hata: %v", err)
	}
	if v.ConfirmationCount != 1 {
		t.Errorf("ConfirmationCount = %d, want 1", v.ConfirmationCount)
	}
}

// TestFindConfirmedByReturnsOwnConfirmations — liste yalnızca ilgili rehberin
// doğrulamalarını, en yeni önce olacak şekilde döndürür ve confirmed_at dolar.
func TestFindConfirmedByReturnsOwnConfirmations(t *testing.T) {
	truncate(t)
	ctx := context.Background()
	repo := repository.NewVenueRepo(testPool)

	adder := insertGuideInCity(t, "İstanbul")
	me := insertGuideInCity(t, "İstanbul")
	other := insertGuideInCity(t, "İstanbul")

	v1 := insertVenueInCity(t, adder, "İstanbul", nil)
	v2 := insertVenueInCity(t, adder, "İstanbul", nil)
	v3 := insertVenueInCity(t, adder, "İstanbul", nil)

	for _, id := range []string{v1, v2} {
		if err := repo.ConfirmVenue(ctx, id, me, "İstanbul", 90); err != nil {
			t.Fatalf("ConfirmVenue hata: %v", err)
		}
	}
	// v3'ü başkası doğruladı — benim listemde çıkmamalı.
	if err := repo.ConfirmVenue(ctx, v3, other, "İstanbul", 90); err != nil {
		t.Fatalf("ConfirmVenue hata: %v", err)
	}

	venues, err := repo.FindConfirmedBy(ctx, me)
	if err != nil {
		t.Fatalf("FindConfirmedBy hata: %v", err)
	}
	if len(venues) != 2 {
		t.Fatalf("2 mekan beklendi, %d alındı", len(venues))
	}
	// En yeni doğrulama önce: v2, sonra v1.
	if venues[0].ID != v2 || venues[1].ID != v1 {
		t.Errorf("sıralama yanlış: %s, %s (beklenen %s, %s)",
			venues[0].ID, venues[1].ID, v2, v1)
	}
	for _, v := range venues {
		if v.ConfirmedAt == nil {
			t.Errorf("mekan %s: confirmed_at dolmalıydı", v.ID)
		}
	}

	// Geri çekince listeden düşer.
	if err := repo.RemoveConfirmation(ctx, v2, me, 90); err != nil {
		t.Fatalf("RemoveConfirmation hata: %v", err)
	}
	venues, err = repo.FindConfirmedBy(ctx, me)
	if err != nil {
		t.Fatalf("FindConfirmedBy hata: %v", err)
	}
	if len(venues) != 1 || venues[0].ID != v1 {
		t.Errorf("geri çekilen mekan listeden düşmeliydi, alınan: %+v", venues)
	}
}
