//go:build integration

package repository_test

import (
	"context"
	"testing"
	"time"

	"github.com/omerkoc/caiz-mi/internal/repository"
)

func TestDirectionClickRepo(t *testing.T) {
	truncate(t)
	ctx := context.Background()
	repo := repository.NewDirectionClickRepo(testPool)

	userID := insertTestUser(t)
	venueID := insertTestVenue(t, userID, venueOpts{})

	// Anonim tıklama (userID nil)
	if err := repo.Create(ctx, venueID, nil); err != nil {
		t.Fatalf("anonim Create hata: %v", err)
	}
	// Auth'lu tıklama
	if err := repo.Create(ctx, venueID, &userID); err != nil {
		t.Fatalf("auth'lu Create hata: %v", err)
	}

	now := time.Now().UTC()
	from := now.AddDate(0, 0, -1)
	to := now.AddDate(0, 0, 1)

	days, err := repo.CountByDay(ctx, from, to)
	if err != nil {
		t.Fatalf("CountByDay hata: %v", err)
	}
	total := 0
	for _, d := range days {
		total += d.Count
	}
	if total != 2 {
		t.Fatalf("CountByDay toplam = %d, beklenen 2", total)
	}

	top, err := repo.TopVenues(ctx, from, to, 10)
	if err != nil {
		t.Fatalf("TopVenues hata: %v", err)
	}
	if len(top) != 1 || top[0].VenueID != venueID || top[0].Count != 2 {
		t.Fatalf("TopVenues beklenmeyen sonuç: %+v", top)
	}
}
