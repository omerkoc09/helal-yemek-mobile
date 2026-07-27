//go:build integration

package repository_test

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/omerkoc/itimat-mobile/internal/repository"
)

// insertNamedUser — verilen ad/soyad ile traveler ekler, id döner.
func insertNamedUser(t *testing.T, name, surname string) string {
	t.Helper()
	var id string
	err := testPool.QueryRow(context.Background(),
		`INSERT INTO users (email, name, surname, password_hash, role)
		 VALUES ($1, $2, $3, 'hash', 'traveler') RETURNING id`,
		fmt.Sprintf("test-%d@example.com", time.Now().UnixNano()), name, surname,
	).Scan(&id)
	if err != nil {
		t.Fatalf("kullanıcı eklenemedi: %v", err)
	}
	return id
}

func TestListByVenue_ReturnsDisplayName(t *testing.T) {
	truncate(t)
	ctx := context.Background()

	guideID := insertTestUser(t) // mekanı ekleyen guide
	venueID := insertTestVenue(t, guideID, venueOpts{})

	userID := insertNamedUser(t, "Ahmet", "Yılmaz")
	comment := "harika"
	if _, err := testPool.Exec(ctx,
		`INSERT INTO reviews (venue_id, user_id, rating, comment)
		 VALUES ($1, $2, 5, $3)`,
		venueID, userID, comment,
	); err != nil {
		t.Fatalf("yorum eklenemedi: %v", err)
	}

	repo := repository.NewReviewRepo(testPool)
	reviews, err := repo.ListByVenue(ctx, venueID)
	if err != nil {
		t.Fatalf("ListByVenue hatası: %v", err)
	}
	if len(reviews) != 1 {
		t.Fatalf("1 yorum bekleniyordu, %d geldi", len(reviews))
	}
	if reviews[0].UserName == nil || *reviews[0].UserName != "Ahmet Y." {
		t.Fatalf("görünen ad 'Ahmet Y.' bekleniyordu, %v geldi", reviews[0].UserName)
	}
}

func TestListByVenue_NoSurnameShowsNameOnly(t *testing.T) {
	truncate(t)
	ctx := context.Background()

	guideID := insertTestUser(t)
	venueID := insertTestVenue(t, guideID, venueOpts{})

	userID := insertNamedUser(t, "Mehmet", "")
	if _, err := testPool.Exec(ctx,
		`INSERT INTO reviews (venue_id, user_id, rating) VALUES ($1, $2, 4)`,
		venueID, userID,
	); err != nil {
		t.Fatalf("yorum eklenemedi: %v", err)
	}

	repo := repository.NewReviewRepo(testPool)
	reviews, err := repo.ListByVenue(ctx, venueID)
	if err != nil {
		t.Fatalf("ListByVenue hatası: %v", err)
	}
	if reviews[0].UserName == nil || *reviews[0].UserName != "Mehmet" {
		t.Fatalf("görünen ad 'Mehmet' bekleniyordu, %v geldi", reviews[0].UserName)
	}
}
