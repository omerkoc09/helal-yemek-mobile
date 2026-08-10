//go:build integration

package repository_test

import (
	"context"
	"errors"
	"fmt"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/testcontainers/testcontainers-go"
	tcpostgres "github.com/testcontainers/testcontainers-go/modules/postgres"
	"github.com/testcontainers/testcontainers-go/wait"

	"github.com/omerkoc/itimat-mobile/internal/database"
	"github.com/omerkoc/itimat-mobile/internal/models"
	"github.com/omerkoc/itimat-mobile/internal/repository"
)

// testPool, tüm integration testleri boyunca paylaşılan bağlantı havuzu.
var testPool *pgxpool.Pool

func TestMain(m *testing.M) {
	ctx := context.Background()

	pgC, err := tcpostgres.Run(ctx,
		"postgis/postgis:16-3.4",
		tcpostgres.WithDatabase("itimat_test"),
		tcpostgres.WithUsername("itimat"),
		tcpostgres.WithPassword("secret"),
		testcontainers.WithWaitStrategy(
			wait.ForLog("database system is ready to accept connections").
				WithOccurrence(2),
		),
	)
	if err != nil {
		panic(fmt.Sprintf("postgres container başlatılamadı: %v", err))
	}
	defer pgC.Terminate(ctx) //nolint:errcheck

	dsn, err := pgC.ConnectionString(ctx, "sslmode=disable")
	if err != nil {
		panic(fmt.Sprintf("connection string alınamadı: %v", err))
	}

	if err := database.RunMigrations(dsn); err != nil {
		panic(fmt.Sprintf("migration çalıştırılamadı: %v", err))
	}

	pool, err := database.NewPool(dsn)
	if err != nil {
		panic(fmt.Sprintf("DB pool oluşturulamadı: %v", err))
	}
	defer pool.Close()

	testPool = pool
	m.Run()
}

// truncate her testten önce tabloları temizler.
func truncate(t *testing.T) {
	t.Helper()
	ctx := context.Background()
	if _, err := testPool.Exec(ctx, "TRUNCATE TABLE venues CASCADE"); err != nil {
		t.Fatalf("venues truncate hatası: %v", err)
	}
	// users(id)'ye FK ile bağlı tablolar (guide_applications)
	// CASCADE içermediği için kullanıcıları silmeden önce temizlenmeli.
	if _, err := testPool.Exec(ctx, "TRUNCATE TABLE guide_applications CASCADE"); err != nil {
		t.Fatalf("başvuru temizleme hatası: %v", err)
	}
	if _, err := testPool.Exec(ctx, "DELETE FROM users WHERE email LIKE 'test-%@example.com'"); err != nil {
		t.Fatalf("users temizleme hatası: %v", err)
	}
}

func insertTestUser(t *testing.T) string {
	t.Helper()
	var id string
	err := testPool.QueryRow(context.Background(),
		`INSERT INTO users (email, name, password_hash, role)
		 VALUES ($1, 'Test Guide', 'hash', 'guide') RETURNING id`,
		fmt.Sprintf("test-%d@example.com", time.Now().UnixNano()),
	).Scan(&id)
	if err != nil {
		t.Fatalf("test kullanıcı eklenemedi: %v", err)
	}
	return id
}

type venueOpts struct {
	status            string
	verificationDueAt time.Time
	lastNotifiedAt    *time.Time
}

func insertTestVenue(t *testing.T, userID string, opts venueOpts) string {
	t.Helper()
	if opts.status == "" {
		opts.status = "approved"
	}
	var id string
	err := testPool.QueryRow(context.Background(),
		`INSERT INTO venues
		   (name, city, location, status, added_by, verification_due_at, last_notified_at)
		 VALUES
		   ('Test Mekan', 'İstanbul',
		    ST_SetSRID(ST_MakePoint(29.0, 41.0), 4326)::geography,
		    $1, $2, $3, $4)
		 RETURNING id`,
		opts.status, userID, opts.verificationDueAt, opts.lastNotifiedAt,
	).Scan(&id)
	if err != nil {
		t.Fatalf("test mekan eklenemedi: %v", err)
	}
	return id
}

// TC-01: 14 gün eşiği içinde dolacak mekan döndürülmeli
func TestFindDueForWarning_ReturnsVenueWithinWindow(t *testing.T) {
	truncate(t)
	userID := insertTestUser(t)
	insertTestVenue(t, userID, venueOpts{
		verificationDueAt: time.Now().Add(10 * 24 * time.Hour),
	})

	repo := repository.NewVenueRepo(testPool)
	venues, err := repo.FindDueForWarning(context.Background(), 14, 90)

	if err != nil {
		t.Fatalf("FindDueForWarning hatası: %v", err)
	}
	if len(venues) != 1 {
		t.Fatalf("TC-01: 1 mekan beklendi, %d geldi", len(venues))
	}
}

// TC-02: Bugün bildirilmiş mekan tekrar sorguya girmemeli
func TestFindDueForWarning_SkipsAlreadyNotifiedToday(t *testing.T) {
	truncate(t)
	userID := insertTestUser(t)
	now := time.Now()
	insertTestVenue(t, userID, venueOpts{
		verificationDueAt: time.Now().Add(5 * 24 * time.Hour),
		lastNotifiedAt:    &now,
	})

	repo := repository.NewVenueRepo(testPool)
	venues, err := repo.FindDueForWarning(context.Background(), 14, 90)

	if err != nil {
		t.Fatalf("FindDueForWarning hatası: %v", err)
	}
	if len(venues) != 0 {
		t.Fatalf("TC-02: bugün bildirilmiş mekan tekrar sorguya girmemeli, %d geldi", len(venues))
	}
}

// TC-03: 14 gün eşiği dışında dolacak mekan dönmemeli
func TestFindDueForWarning_IgnoresVenueOutsideWindow(t *testing.T) {
	truncate(t)
	userID := insertTestUser(t)
	insertTestVenue(t, userID, venueOpts{
		verificationDueAt: time.Now().Add(20 * 24 * time.Hour),
	})

	repo := repository.NewVenueRepo(testPool)
	venues, err := repo.FindDueForWarning(context.Background(), 14, 90)

	if err != nil {
		t.Fatalf("FindDueForWarning hatası: %v", err)
	}
	if len(venues) != 0 {
		t.Fatalf("TC-03: eşik dışı mekan dönmemeli, %d geldi", len(venues))
	}
}

// TC-04: Dün bildirilmiş mekan tekrar uyarı listesine girmeli
func TestFindDueForWarning_IncludesNotifiedYesterday(t *testing.T) {
	truncate(t)
	userID := insertTestUser(t)
	yesterday := time.Now().Add(-25 * time.Hour)
	insertTestVenue(t, userID, venueOpts{
		verificationDueAt: time.Now().Add(5 * 24 * time.Hour),
		lastNotifiedAt:    &yesterday,
	})

	repo := repository.NewVenueRepo(testPool)
	venues, err := repo.FindDueForWarning(context.Background(), 14, 90)

	if err != nil {
		t.Fatalf("FindDueForWarning hatası: %v", err)
	}
	if len(venues) != 1 {
		t.Fatalf("TC-04: dün bildirilmiş mekan tekrar uyarı listesine girmeli, %d geldi", len(venues))
	}
}

// TC-05: FindDueForSuspension süresi dolmuş approved mekanı döndürmeli
func TestFindDueForSuspension_ReturnsExpiredVenue(t *testing.T) {
	truncate(t)
	userID := insertTestUser(t)
	insertTestVenue(t, userID, venueOpts{
		verificationDueAt: time.Now().Add(-5 * 24 * time.Hour),
	})

	repo := repository.NewVenueRepo(testPool)
	venues, err := repo.FindDueForSuspension(context.Background(), 90)

	if err != nil {
		t.Fatalf("FindDueForSuspension hatası: %v", err)
	}
	if len(venues) != 1 {
		t.Fatalf("TC-05: süresi dolmuş mekan dönmeli, %d geldi", len(venues))
	}
}

// TC-06: FindDueForSuspension sadece approved mekanları döndürmeli
func TestFindDueForSuspension_IgnoresNonApprovedVenues(t *testing.T) {
	truncate(t)
	userID := insertTestUser(t)
	insertTestVenue(t, userID, venueOpts{
		status:            "pending",
		verificationDueAt: time.Now().Add(-1 * 24 * time.Hour),
	})
	insertTestVenue(t, userID, venueOpts{
		status:            "suspended",
		verificationDueAt: time.Now().Add(-1 * 24 * time.Hour),
	})

	repo := repository.NewVenueRepo(testPool)
	venues, err := repo.FindDueForSuspension(context.Background(), 90)

	if err != nil {
		t.Fatalf("FindDueForSuspension hatası: %v", err)
	}
	if len(venues) != 0 {
		t.Fatalf("TC-06: approved olmayan mekanlar dönmemeli, %d geldi", len(venues))
	}
}

// TC-07: UpdateLastNotified last_notified_at'ı şimdiki zamana günceller
func TestUpdateLastNotified_SetsTimestamp(t *testing.T) {
	truncate(t)
	userID := insertTestUser(t)
	venueID := insertTestVenue(t, userID, venueOpts{
		verificationDueAt: time.Now().Add(5 * 24 * time.Hour),
	})

	repo := repository.NewVenueRepo(testPool)
	if err := repo.UpdateLastNotified(context.Background(), venueID); err != nil {
		t.Fatalf("TC-07: UpdateLastNotified hatası: %v", err)
	}

	var lastNotifiedAt *time.Time
	if err := testPool.QueryRow(context.Background(),
		`SELECT last_notified_at FROM venues WHERE id = $1`, venueID,
	).Scan(&lastNotifiedAt); err != nil {
		t.Fatalf("TC-07: son bildirim zamanı okunamadı: %v", err)
	}

	if lastNotifiedAt == nil {
		t.Fatal("TC-07: last_notified_at nil, güncellenmemiş")
	}
	if time.Since(*lastNotifiedAt) > 5*time.Second {
		t.Fatalf("TC-07: last_notified_at çok eski: %v", lastNotifiedAt)
	}
}

// venueStatusRow — SetStatus testlerinde yan-etki sütunlarını okumak için.
func readVenueStatusRow(t *testing.T, venueID string) (status string, approvedBy, rejectionNote *string, verifiedAt, dueAt *time.Time) {
	t.Helper()
	err := testPool.QueryRow(context.Background(),
		`SELECT status, approved_by, rejection_note, verified_at, verification_due_at
		 FROM venues WHERE id = $1`, venueID,
	).Scan(&status, &approvedBy, &rejectionNote, &verifiedAt, &dueAt)
	if err != nil {
		t.Fatalf("mekan durumu okunamadı: %v", err)
	}
	return
}

// TC-08: SetStatus approved → rejected geçişine izin vermeli (admin modalı senaryosu).
// Eski Reject() yalnızca pending kabul ettiği için bu geçiş ErrNotFound veriyordu.
func TestSetStatus_ApprovedToRejected(t *testing.T) {
	truncate(t)
	userID := insertTestUser(t)
	venueID := insertTestVenue(t, userID, venueOpts{
		status:            "approved",
		verificationDueAt: time.Now().Add(30 * 24 * time.Hour),
	})

	repo := repository.NewVenueRepo(testPool)
	note := "Helal kriterlerini karşılamıyor"
	if err := repo.SetStatus(context.Background(), venueID, "rejected", userID, &note, 30); err != nil {
		t.Fatalf("TC-08: approved→rejected başarısız: %v", err)
	}

	status, approvedBy, rejectionNote, verifiedAt, dueAt := readVenueStatusRow(t, venueID)
	if status != "rejected" {
		t.Fatalf("TC-08: status 'rejected' olmalı, %q geldi", status)
	}
	if rejectionNote == nil || *rejectionNote != note {
		t.Fatalf("TC-08: rejection_note %q olmalı, %v geldi", note, rejectionNote)
	}
	if approvedBy == nil || *approvedBy != userID {
		t.Fatalf("TC-08: approved_by işlemi yapan admin olmalı, %v geldi", approvedBy)
	}
	if verifiedAt != nil {
		t.Fatalf("TC-08: rejected'ta verified_at temizlenmeli, %v geldi", verifiedAt)
	}
	if dueAt != nil {
		t.Fatalf("TC-08: rejected'ta verification_due_at temizlenmeli, %v geldi", dueAt)
	}
}

// TC-09: SetStatus rejected → approved geçişinde doğrulama süresi başlamalı ve
// rejection_note temizlenmeli.
func TestSetStatus_RejectedToApproved(t *testing.T) {
	truncate(t)
	userID := insertTestUser(t)
	venueID := insertTestVenue(t, userID, venueOpts{status: "rejected"})
	if _, err := testPool.Exec(context.Background(),
		`UPDATE venues SET rejection_note = 'eski not' WHERE id = $1`, venueID); err != nil {
		t.Fatalf("TC-09: hazırlık güncellemesi başarısız: %v", err)
	}

	repo := repository.NewVenueRepo(testPool)
	if err := repo.SetStatus(context.Background(), venueID, "approved", userID, nil, 30); err != nil {
		t.Fatalf("TC-09: rejected→approved başarısız: %v", err)
	}

	status, _, rejectionNote, verifiedAt, dueAt := readVenueStatusRow(t, venueID)
	if status != "approved" {
		t.Fatalf("TC-09: status 'approved' olmalı, %q geldi", status)
	}
	if rejectionNote != nil {
		t.Fatalf("TC-09: approved'da rejection_note temizlenmeli, %v geldi", rejectionNote)
	}
	if verifiedAt == nil || dueAt == nil {
		t.Fatalf("TC-09: approved'da verified_at ve verification_due_at dolu olmalı")
	}
}

// TC-10: SetStatus geçersiz durum değeri için hata döndürmeli, kaydı değiştirmemeli.
func TestSetStatus_InvalidStatus(t *testing.T) {
	truncate(t)
	userID := insertTestUser(t)
	venueID := insertTestVenue(t, userID, venueOpts{status: "approved"})

	repo := repository.NewVenueRepo(testPool)
	if err := repo.SetStatus(context.Background(), venueID, "garbage", userID, nil, 30); err == nil {
		t.Fatal("TC-10: geçersiz durum için hata beklendi, nil geldi")
	}

	if status, _, _, _, _ := readVenueStatusRow(t, venueID); status != "approved" {
		t.Fatalf("TC-10: geçersiz geçişte status değişmemeli, %q geldi", status)
	}
}

// TC-11: SetStatus var olmayan mekan için ErrNotFound döndürmeli.
func TestSetStatus_NotFound(t *testing.T) {
	truncate(t)
	repo := repository.NewVenueRepo(testPool)
	err := repo.SetStatus(context.Background(), "00000000-0000-0000-0000-000000000000", "approved", "00000000-0000-0000-0000-000000000000", nil, 30)
	if !errors.Is(err, repository.ErrNotFound) {
		t.Fatalf("TC-11: ErrNotFound beklendi, %v geldi", err)
	}
}

// TestVerifyByGuide_ConfirmerCanReverify — mekanı ekleyen değil ama daha önce
// doğrulamış bir rehber de re-verify yapabilmeli (ownerless model).
func TestVerifyByGuide_ConfirmerCanReverify(t *testing.T) {
	truncate(t)
	ctx := context.Background()
	repo := repository.NewVenueRepo(testPool)

	adder := insertTestUser(t)
	confirmer := insertTestUser(t)
	venueID := insertTestVenue(t, adder, venueOpts{
		status:            "approved",
		verificationDueAt: time.Now().Add(90 * 24 * time.Hour),
	})

	// confirmer mekanı doğrular
	if err := repo.ConfirmVenue(ctx, venueID, confirmer, "", 90); err != nil {
		t.Fatalf("confirm: %v", err)
	}

	// confirmer (ekleyen DEĞİL) re-verify yapabilmeli
	if err := repo.VerifyByGuide(ctx, venueID, confirmer, 90); err != nil {
		t.Fatalf("confirmer re-verify yapamadı: %v", err)
	}

	// confirmation kaydı SİLİNMEMELİ
	n, err := repo.FreshConfirmationCount(ctx, venueID, 90)
	if err != nil {
		t.Fatalf("count: %v", err)
	}
	if n != 1 {
		t.Errorf("re-verify sonrası taze sayı = %d, want 1 (silme olmamalı)", n)
	}
}

// TestVerifyByGuide_UnrelatedGuideRejected — ne eklemiş ne doğrulamış bir
// rehber repo katmanında re-verify yapamamalı (şehir politikası handler'da).
func TestVerifyByGuide_UnrelatedGuideRejected(t *testing.T) {
	truncate(t)
	ctx := context.Background()
	repo := repository.NewVenueRepo(testPool)

	adder := insertTestUser(t)
	stranger := insertTestUser(t)
	venueID := insertTestVenue(t, adder, venueOpts{
		status:            "approved",
		verificationDueAt: time.Now().Add(90 * 24 * time.Hour),
	})

	// Doğrulamamış, eklememiş rehber re-verify YAPAMAMALI (repo katmanı)
	err := repo.VerifyByGuide(ctx, venueID, stranger, 90)
	if !errors.Is(err, repository.ErrNotFound) {
		t.Errorf("stranger re-verify hatası = %v, want ErrNotFound", err)
	}
}

// TestFindDueForWarning_MultipleRecipients — uyarı listesindeki mekanın
// Recipients'ı ekleyen ∪ son periyottaki doğrulayanlar olmalı (ownerless model).
func TestFindDueForWarning_MultipleRecipients(t *testing.T) {
	truncate(t)
	ctx := context.Background()
	repo := repository.NewVenueRepo(testPool)

	adder := insertTestUser(t)
	confirmer := insertTestUser(t)
	venueID := insertTestVenue(t, adder, venueOpts{
		status:            "approved",
		verificationDueAt: time.Now().Add(2 * 24 * time.Hour),
	})
	if err := repo.ConfirmVenue(ctx, venueID, confirmer, "", 90); err != nil {
		t.Fatalf("confirm: %v", err)
	}

	venues, err := repo.FindDueForWarning(ctx, 7, 90)
	if err != nil {
		t.Fatalf("warning: %v", err)
	}

	var v *models.VenueForScheduler
	for _, cand := range venues {
		if cand.ID == venueID {
			v = cand
			break
		}
	}
	if v == nil {
		t.Fatalf("venue %s uyarı listesinde bulunamadı", venueID)
	}
	if len(v.Recipients) != 2 {
		t.Errorf("recipients = %d, want 2 (ekleyen + doğrulayan)", len(v.Recipients))
	}
}

// TC-12: FreshConfirmationCount son periyot içindeki farklı guide sayısını döner.
func TestFreshConfirmationCount(t *testing.T) {
	truncate(t)
	ctx := context.Background()
	repo := repository.NewVenueRepo(testPool)

	guideA := insertTestUser(t)
	guideB := insertTestUser(t)
	adder := insertTestUser(t)
	venueID := insertTestVenue(t, adder, venueOpts{})

	// İki taze doğrulama — ConfirmVenue imzası Task 2'de değişeceği için
	// bu test doğrudan venue_confirmations'a INSERT yapar (imzadan bağımsız).
	for _, gid := range []string{guideA, guideB} {
		if _, err := testPool.Exec(ctx,
			`INSERT INTO venue_confirmations (venue_id, guide_id, period_start, created_at)
			 VALUES ($1, $2, NOW(), NOW())`,
			venueID, gid); err != nil {
			t.Fatalf("insert confirmation %s: %v", gid, err)
		}
	}

	got, err := repo.FreshConfirmationCount(ctx, venueID, 90)
	if err != nil {
		t.Fatalf("count: %v", err)
	}
	if got != 2 {
		t.Errorf("FreshConfirmationCount = %d, want 2", got)
	}

	// Periyot 0 gün → hiçbiri taze sayılmaz
	gotZero, err := repo.FreshConfirmationCount(ctx, venueID, 0)
	if err != nil {
		t.Fatalf("count zero: %v", err)
	}
	if gotZero != 0 {
		t.Errorf("FreshConfirmationCount(period=0) = %d, want 0", gotZero)
	}
}

// readConfirmationCount — venues.confirmation_count sütununu doğrudan okur.
func readConfirmationCount(t *testing.T, venueID string) int {
	t.Helper()
	var n int
	if err := testPool.QueryRow(context.Background(),
		`SELECT confirmation_count FROM venues WHERE id = $1`, venueID,
	).Scan(&n); err != nil {
		t.Fatalf("confirmation_count okunamadı: %v", err)
	}
	return n
}

// TestRecomputeConfirmationCounts_DropsStaleCount — asıl amaç: eski
// doğrulamalar pencere dışına çıktığında saklanan confirmation_count'un
// DÜŞMESİ gerektiğini kanıtlamak (bayat rozet bug'ı).
func TestRecomputeConfirmationCounts_DropsStaleCount(t *testing.T) {
	truncate(t)
	ctx := context.Background()
	repo := repository.NewVenueRepo(testPool)

	adder := insertTestUser(t)
	guideA := insertTestUser(t)
	guideB := insertTestUser(t)
	venueID := insertTestVenue(t, adder, venueOpts{
		status:            "approved",
		verificationDueAt: time.Now().Add(90 * 24 * time.Hour),
	})

	// İki ESKİ doğrulama (200 gün önce) — pencere (180 gün) dışında kalacak.
	for _, gid := range []string{guideA, guideB} {
		if _, err := testPool.Exec(ctx,
			`INSERT INTO venue_confirmations (venue_id, guide_id, period_start, created_at)
			 VALUES ($1, $2, NOW(), NOW() - INTERVAL '200 days')`,
			venueID, gid); err != nil {
			t.Fatalf("insert eski confirmation %s: %v", gid, err)
		}
	}

	// Bayat anlık görüntüyü simüle et: sütun hâlâ 2 diyor.
	if _, err := testPool.Exec(ctx,
		`UPDATE venues SET confirmation_count = 2 WHERE id = $1`, venueID); err != nil {
		t.Fatalf("hazırlık güncellemesi başarısız: %v", err)
	}

	affected, err := repo.RecomputeConfirmationCounts(ctx, 180)
	if err != nil {
		t.Fatalf("RecomputeConfirmationCounts hatası: %v", err)
	}
	if affected < 1 {
		t.Errorf("affected = %d, want >= 1", affected)
	}

	if got := readConfirmationCount(t, venueID); got != 0 {
		t.Errorf("recompute sonrası confirmation_count = %d, want 0 (ikisi de eskimiş)", got)
	}
}

// TestRecomputeConfirmationCounts_CountsFreshConfirmation — sıfırlamakla
// kalmayıp taze doğrulamaları doğru saydığını da kanıtlar.
func TestRecomputeConfirmationCounts_CountsFreshConfirmation(t *testing.T) {
	truncate(t)
	ctx := context.Background()
	repo := repository.NewVenueRepo(testPool)

	adder := insertTestUser(t)
	guideA := insertTestUser(t)
	venueID := insertTestVenue(t, adder, venueOpts{
		status:            "approved",
		verificationDueAt: time.Now().Add(90 * 24 * time.Hour),
	})

	// TEK taze doğrulama (şimdi) — pencere içinde.
	if _, err := testPool.Exec(ctx,
		`INSERT INTO venue_confirmations (venue_id, guide_id, period_start, created_at)
		 VALUES ($1, $2, NOW(), NOW())`,
		venueID, guideA); err != nil {
		t.Fatalf("insert taze confirmation: %v", err)
	}

	// Sütun başlangıçta 0 (hiç recompute edilmemiş gibi).
	if _, err := testPool.Exec(ctx,
		`UPDATE venues SET confirmation_count = 0 WHERE id = $1`, venueID); err != nil {
		t.Fatalf("hazırlık güncellemesi başarısız: %v", err)
	}

	if _, err := repo.RecomputeConfirmationCounts(ctx, 180); err != nil {
		t.Fatalf("RecomputeConfirmationCounts hatası: %v", err)
	}

	if got := readConfirmationCount(t, venueID); got != 1 {
		t.Errorf("recompute sonrası confirmation_count = %d, want 1 (taze doğrulama sayılmalı)", got)
	}
}
