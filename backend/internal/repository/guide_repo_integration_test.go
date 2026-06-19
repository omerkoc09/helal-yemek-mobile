//go:build integration

package repository_test

import (
	"context"
	"testing"

	"github.com/omerkoc/caiz-mi/internal/repository"
)

func TestCancelOpenByUserID_CancelsPendingAndApproved(t *testing.T) {
	truncate(t)
	ctx := context.Background()
	repo := repository.NewGuideRepo(testPool)

	userID := insertTraveler(t)

	// Açık (pending) ve onaylı (approved) iki kayıt ekle.
	if _, err := testPool.Exec(ctx,
		`INSERT INTO guide_applications (user_id, status) VALUES ($1, 'approved'), ($1, 'pending')`,
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
