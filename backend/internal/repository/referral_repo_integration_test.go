//go:build integration

package repository_test

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/omerkoc/caiz-mi/internal/repository"
)

// insertTraveler — test için traveler rolünde kullanıcı ekler, id döner.
func insertTraveler(t *testing.T) string {
	t.Helper()
	var id string
	err := testPool.QueryRow(context.Background(),
		`INSERT INTO users (email, name, password_hash, role)
		 VALUES ($1, 'Test Traveler', 'hash', 'traveler') RETURNING id`,
		fmt.Sprintf("test-%d@example.com", time.Now().UnixNano()),
	).Scan(&id)
	if err != nil {
		t.Fatalf("traveler eklenemedi: %v", err)
	}
	return id
}

func TestApproveGuideTx_PromotesAndCreatesCode(t *testing.T) {
	truncate(t)
	ctx := context.Background()
	repo := repository.NewReferralRepo(testPool)

	guideID := insertTestUser(t) // role guide
	if _, err := repo.CreateCode(ctx, guideID); err != nil {
		t.Fatalf("referrer kodu üretilemedi: %v", err)
	}
	travelerID := insertTraveler(t)

	if err := repo.ApproveGuideTx(ctx, travelerID, guideID); err != nil {
		t.Fatalf("ApproveGuideTx hata: %v", err)
	}

	// Rol guide olmalı.
	var role string
	if err := testPool.QueryRow(ctx, `SELECT role FROM users WHERE id = $1`, travelerID).Scan(&role); err != nil {
		t.Fatalf("rol sorgusu hata: %v", err)
	}
	if role != "guide" {
		t.Fatalf("rol guide olmalı, bulunan: %s", role)
	}

	// Yeni guide'ın kendi aktif kodu olmalı.
	rc, err := repo.GetActiveByGuideID(ctx, travelerID)
	if err != nil {
		t.Fatalf("yeni guide kodu bulunamadı: %v", err)
	}
	if rc.Code == "" {
		t.Fatalf("kod boş")
	}

	// Başvuru approved + referred_by doğru olmalı.
	var status, referredBy string
	if err := testPool.QueryRow(ctx,
		`SELECT status, referred_by FROM guide_applications WHERE user_id = $1`, travelerID,
	).Scan(&status, &referredBy); err != nil {
		t.Fatalf("başvuru sorgusu hata: %v", err)
	}
	if status != "approved" || referredBy != guideID {
		t.Fatalf("başvuru beklenenden farklı: status=%s referred_by=%s", status, referredBy)
	}
}

func TestRevokeByGuideID_DeactivatesCode(t *testing.T) {
	truncate(t)
	ctx := context.Background()
	repo := repository.NewReferralRepo(testPool)

	guideID := insertTestUser(t)
	if _, err := repo.CreateCode(ctx, guideID); err != nil {
		t.Fatalf("kod üretilemedi: %v", err)
	}

	if err := repo.RevokeByGuideID(ctx, guideID); err != nil {
		t.Fatalf("RevokeByGuideID hata: %v", err)
	}

	// Artık aktif kod bulunamamalı.
	if _, err := repo.GetActiveByGuideID(ctx, guideID); err != repository.ErrNotFound {
		t.Fatalf("aktif kod kalmamalıydı, err=%v", err)
	}
}

func TestRevokeByGuideID_NoActiveCode_NoError(t *testing.T) {
	truncate(t)
	ctx := context.Background()
	repo := repository.NewReferralRepo(testPool)

	guideID := insertTestUser(t)
	// Hiç kod üretilmedi; idempotent olmalı.
	if err := repo.RevokeByGuideID(ctx, guideID); err != nil {
		t.Fatalf("aktif kod yokken hata dönmemeli: %v", err)
	}
}
