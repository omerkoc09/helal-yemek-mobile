//go:build integration

package repository_test

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/omerkoc/caiz-mi/internal/repository"
)

// insertTraveler — role='traveler' ile bir test kullanıcısı ekler ve ID döndürür.
func insertTraveler(t *testing.T) string {
	t.Helper()
	var id string
	err := testPool.QueryRow(context.Background(),
		`INSERT INTO users (email, name, password_hash, role)
		 VALUES ($1, 'Test Traveler', 'hash', 'traveler') RETURNING id`,
		fmt.Sprintf("test-traveler-%d@example.com", time.Now().UnixNano()),
	).Scan(&id)
	if err != nil {
		t.Fatalf("test traveler eklenemedi: %v", err)
	}
	return id
}

func TestCancelOpenByUserID_CancelsPendingAndApproved(t *testing.T) {
	truncate(t)
	ctx := context.Background()
	repo := repository.NewGuideRepo(testPool)

	userID := insertTraveler(t)

	// Açık (pending) ve onaylı (approved) iki kayıt ekle.
	if _, err := testPool.Exec(ctx,
		`INSERT INTO guide_applications (user_id, status, city) VALUES ($1, 'approved', 'İstanbul'), ($1, 'pending', 'İstanbul')`,
		userID,
	); err != nil {
		t.Fatalf("başvuru eklenemedi: %v", err)
	}

	if err := repo.CancelOpenByUserID(ctx, userID); err != nil {
		t.Fatalf("CancelOpenByUserID hatası: %v", err)
	}

	// Artık pending başvuru kalmamalı.
	hasPending, err := repo.HasPendingApplication(ctx, userID)
	if err != nil {
		t.Fatalf("HasPendingApplication hatası: %v", err)
	}
	if hasPending {
		t.Fatalf("pending başvuru kalmamalıydı")
	}

	// İki kayıt da cancelled olmalı.
	var openCount int
	if err := testPool.QueryRow(ctx,
		`SELECT COUNT(*) FROM guide_applications WHERE user_id = $1 AND status IN ('pending','approved')`,
		userID,
	).Scan(&openCount); err != nil {
		t.Fatalf("sayım hatası: %v", err)
	}
	if openCount != 0 {
		t.Fatalf("açık başvuru kalmamalıydı, %d kaldı", openCount)
	}
}

func TestCancelOpenByUserID_NoOpenIsIdempotent(t *testing.T) {
	truncate(t)
	ctx := context.Background()
	repo := repository.NewGuideRepo(testPool)

	userID := insertTraveler(t)
	// Hiç başvuru yok — hata vermemeli.
	if err := repo.CancelOpenByUserID(ctx, userID); err != nil {
		t.Fatalf("açık başvuru yokken hata olmamalıydı: %v", err)
	}
}
