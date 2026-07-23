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

func nowNano() int64 { return time.Now().UnixNano() }

// insertAdmin — role='admin' bir kullanıcı ekler; reviewed_by UUID FK'sı için gerekli.
func insertAdmin(t *testing.T) string {
	t.Helper()
	var id string
	err := testPool.QueryRow(context.Background(),
		`INSERT INTO users (email, name, password_hash, role)
		 VALUES ($1, 'Test Admin', 'hash', 'admin') RETURNING id`,
		fmt.Sprintf("test-admin-%d@example.com", nowNano()),
	).Scan(&id)
	if err != nil {
		t.Fatalf("test admin eklenemedi: %v", err)
	}
	return id
}

// insertPendingApplication — verilen kullanıcı için pending başvuru ekler, ID döndürür.
func insertPendingApplication(t *testing.T, userID, city string) string {
	t.Helper()
	var id string
	err := testPool.QueryRow(context.Background(),
		`INSERT INTO guide_applications (user_id, status, city) VALUES ($1, 'pending', $2) RETURNING id`,
		userID, city,
	).Scan(&id)
	if err != nil {
		t.Fatalf("başvuru eklenemedi: %v", err)
	}
	return id
}

func userRoleAndCity(t *testing.T, userID string) (string, *string) {
	t.Helper()
	var role string
	var city *string
	err := testPool.QueryRow(context.Background(),
		`SELECT role, guide_city FROM users WHERE id = $1`, userID,
	).Scan(&role, &city)
	if err != nil {
		t.Fatalf("kullanıcı okunamadı: %v", err)
	}
	return role, city
}

func appStatus(t *testing.T, appID string) string {
	t.Helper()
	var s string
	if err := testPool.QueryRow(context.Background(),
		`SELECT status FROM guide_applications WHERE id = $1`, appID).Scan(&s); err != nil {
		t.Fatalf("başvuru durumu okunamadı: %v", err)
	}
	return s
}

func TestApproveApplication_HappyPath(t *testing.T) {
	truncate(t)
	repo := repository.NewGuideRepo(testPool)

	userID := insertTraveler(t)
	adminID := insertAdmin(t)
	appID := insertPendingApplication(t, userID, "İzmir")

	gotUser, err := repo.ApproveApplication(context.Background(), appID, adminID)
	if err != nil {
		t.Fatalf("onay başarısız: %v", err)
	}
	if gotUser != userID {
		t.Fatalf("dönen userID %q, beklenen %q", gotUser, userID)
	}

	// Üç yazma da uygulanmış olmalı: statü, rol, şehir.
	if s := appStatus(t, appID); s != "approved" {
		t.Fatalf("başvuru durumu %q, beklenen approved", s)
	}
	role, city := userRoleAndCity(t, userID)
	if role != "guide" {
		t.Fatalf("rol %q, beklenen guide", role)
	}
	if city == nil || *city != "İzmir" {
		t.Fatalf("guide_city %v, beklenen İzmir", city)
	}
}

func TestApproveApplication_AlreadyReviewed(t *testing.T) {
	truncate(t)
	repo := repository.NewGuideRepo(testPool)

	userID := insertTraveler(t)
	adminID := insertAdmin(t)
	appID := insertPendingApplication(t, userID, "Ankara")

	// İlk onay geçer.
	if _, err := repo.ApproveApplication(context.Background(), appID, adminID); err != nil {
		t.Fatalf("ilk onay başarısız: %v", err)
	}
	// İkinci onay: başvuru artık pending değil → ErrAlreadyReviewed.
	_, err := repo.ApproveApplication(context.Background(), appID, adminID)
	if !errors.Is(err, repository.ErrAlreadyReviewed) {
		t.Fatalf("ErrAlreadyReviewed beklendi, alınan: %v", err)
	}
}

func TestApproveApplication_NotFound(t *testing.T) {
	truncate(t)
	repo := repository.NewGuideRepo(testPool)

	adminID := insertAdmin(t)
	_, err := repo.ApproveApplication(context.Background(), "00000000-0000-0000-0000-000000000000", adminID)
	if !errors.Is(err, repository.ErrNotFound) {
		t.Fatalf("ErrNotFound beklendi, alınan: %v", err)
	}
}

// ATOMİKLİK KANITI: transaction ortasında bağlam iptal edilirse HİÇBİR yazma
// kalıcı olmamalı — ne statü değişir, ne rol, ne şehir. Bu, "guide ama şehirsiz"
// kısmi durumunun artık imkânsız olduğunu gösterir.
func TestApproveApplication_RollbackOnFailure(t *testing.T) {
	truncate(t)
	repo := repository.NewGuideRepo(testPool)

	userID := insertTraveler(t)
	adminID := insertAdmin(t)
	appID := insertPendingApplication(t, userID, "Bursa")

	// Zaten iptal edilmiş bağlam: Begin veya ilk sorgu başarısız olur,
	// transaction commit edilemez.
	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	if _, err := repo.ApproveApplication(ctx, appID, adminID); err == nil {
		t.Fatal("iptal edilmiş bağlamda hata beklenmişti")
	}

	// DB değişmemiş olmalı.
	if s := appStatus(t, appID); s != "pending" {
		t.Fatalf("başvuru durumu %q, beklenen pending (rollback)", s)
	}
	role, city := userRoleAndCity(t, userID)
	if role != "traveler" {
		t.Fatalf("rol %q, beklenen traveler (rollback)", role)
	}
	if city != nil {
		t.Fatalf("guide_city %v, beklenen nil (rollback)", city)
	}
}

// Aynı başvuruya EŞ ZAMANLI iki onay: yalnızca biri başarılı olmalı.
// FOR UPDATE kilidi ikincisini bekletir; o da başvuruyu artık pending
// görmediği için ErrAlreadyReviewed alır — çift rol atama olmaz.
func TestApproveApplication_ConcurrentOnlyOneWins(t *testing.T) {
	truncate(t)
	repo := repository.NewGuideRepo(testPool)

	userID := insertTraveler(t)
	adminID := insertAdmin(t)
	appID := insertPendingApplication(t, userID, "Konya")

	type result struct {
		err error
	}
	results := make(chan result, 2)
	for i := 0; i < 2; i++ {
		go func() {
			_, err := repo.ApproveApplication(context.Background(), appID, adminID)
			results <- result{err}
		}()
	}

	var success, reviewed int
	for i := 0; i < 2; i++ {
		r := <-results
		switch {
		case r.err == nil:
			success++
		case errors.Is(r.err, repository.ErrAlreadyReviewed):
			reviewed++
		default:
			t.Fatalf("beklenmeyen hata: %v", r.err)
		}
	}
	if success != 1 || reviewed != 1 {
		t.Fatalf("tam olarak 1 başarı + 1 already-reviewed beklendi: success=%d reviewed=%d", success, reviewed)
	}

	// Kullanıcı guide olmuş olmalı (bir onay geçti).
	role, _ := userRoleAndCity(t, userID)
	if role != "guide" {
		t.Fatalf("rol %q, beklenen guide", role)
	}
}
