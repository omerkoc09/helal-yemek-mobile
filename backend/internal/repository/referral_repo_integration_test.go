//go:build integration

package repository_test

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/omerkoc/caiz-mi/internal/models"
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

func TestUserList_IncludesReferralColumns(t *testing.T) {
	truncate(t)
	ctx := context.Background()
	refRepo := repository.NewReferralRepo(testPool)
	userRepo := repository.NewUserRepo(testPool)

	guideID := insertTestUser(t)
	if _, err := refRepo.CreateCode(ctx, guideID); err != nil {
		t.Fatalf("kod üretilemedi: %v", err)
	}
	travelerID := insertTraveler(t)
	if err := refRepo.ApproveGuideTx(ctx, travelerID, guideID); err != nil {
		t.Fatalf("ApproveGuideTx hata: %v", err)
	}

	users, err := userRepo.List(ctx)
	if err != nil {
		t.Fatalf("List hata: %v", err)
	}

	var travelerHasReferrer bool
	var guideCount int
	for _, u := range users {
		if u.ID == travelerID && u.ReferredByName != nil {
			travelerHasReferrer = true
		}
		if u.ID == guideID {
			guideCount = u.ReferralCount
		}
	}
	if !travelerHasReferrer {
		t.Fatalf("yeni guide'ın getiren adı dolu olmalı")
	}
	if guideCount != 1 {
		t.Fatalf("referrer'ın referral_count'u 1 olmalı, bulunan: %d", guideCount)
	}
}

func TestGuideRepoCreate_CodelessApplication(t *testing.T) {
	truncate(t)
	ctx := context.Background()
	guideRepo := repository.NewGuideRepo(testPool)

	travelerID := insertTraveler(t)
	now := time.Now()
	app := &models.GuideApplication{
		UserID:          travelerID,
		TermsAcceptedAt: &now,
	}
	if err := guideRepo.Create(ctx, app); err != nil {
		t.Fatalf("Create hata: %v", err)
	}
	if app.ID == "" {
		t.Fatalf("başvuru id boş")
	}

	// pending durumda, referred_by NULL, terms_accepted_at dolu olmalı.
	var status string
	var referredBy *string
	var termsAcceptedAt *time.Time
	if err := testPool.QueryRow(ctx,
		`SELECT status, referred_by, terms_accepted_at FROM guide_applications WHERE id = $1`, app.ID,
	).Scan(&status, &referredBy, &termsAcceptedAt); err != nil {
		t.Fatalf("sorgu hata: %v", err)
	}
	if status != "pending" {
		t.Fatalf("status pending olmalı, bulunan: %s", status)
	}
	if referredBy != nil {
		t.Fatalf("referred_by NULL olmalı, bulunan: %v", *referredBy)
	}
	if termsAcceptedAt == nil {
		t.Fatalf("terms_accepted_at dolu olmalı")
	}

	// HasPendingApplication true dönmeli.
	has, err := guideRepo.HasPendingApplication(ctx, travelerID)
	if err != nil {
		t.Fatalf("HasPendingApplication hata: %v", err)
	}
	if !has {
		t.Fatalf("bekleyen başvuru true olmalı")
	}
}
