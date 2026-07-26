//go:build integration

package repository_test

import (
	"context"
	"errors"
	"testing"

	"github.com/omerkoc/caiz-mi/internal/repository"
)

// TestCreateTrustCriteriaAppearsInList — admin panelinden eklenen bir kriterin
// GetAllCriteria listesinde göründüğünü ve id sequence'ının (migration 045)
// mevcut manuel id'lerle (1..7) çakışmadan devam ettiğini doğrular.
func TestCreateTrustCriteriaAppearsInList(t *testing.T) {
	ctx := context.Background()
	repo := repository.NewVenueRepo(testPool)

	desc := "Test açıklaması"
	created, err := repo.CreateTrustCriteria(ctx, "test_criteria_seq", "Test Kriteri Seq", &desc)
	if err != nil {
		t.Fatalf("CreateTrustCriteria hata: %v", err)
	}
	t.Cleanup(func() {
		_ = repo.DeleteTrustCriteria(ctx, created.ID)
	})

	if created.ID <= 7 {
		t.Errorf("created.ID = %d, want > 7 (sequence 044'teki max id'nin üzerinden devam etmeli)", created.ID)
	}
	if created.Key != "test_criteria_seq" {
		t.Errorf("created.Key = %q, want %q", created.Key, "test_criteria_seq")
	}

	list, err := repo.GetAllCriteria(ctx)
	if err != nil {
		t.Fatalf("GetAllCriteria hata: %v", err)
	}
	found := false
	for _, c := range list {
		if c.ID == created.ID {
			found = true
			break
		}
	}
	if !found {
		t.Errorf("yeni oluşturulan kriter (id=%d) GetAllCriteria listesinde bulunamadı", created.ID)
	}
}

// TestCreateTrustCriteriaDuplicateKey — aynı key ile ikinci kez oluşturma
// ErrAlreadyExists döndürmeli (key UNIQUE kısıtı).
func TestCreateTrustCriteriaDuplicateKey(t *testing.T) {
	ctx := context.Background()
	repo := repository.NewVenueRepo(testPool)

	first, err := repo.CreateTrustCriteria(ctx, "test_dup_key", "Test Dup", nil)
	if err != nil {
		t.Fatalf("CreateTrustCriteria (ilk) hata: %v", err)
	}
	t.Cleanup(func() {
		_ = repo.DeleteTrustCriteria(ctx, first.ID)
	})

	_, err = repo.CreateTrustCriteria(ctx, "test_dup_key", "Test Dup 2", nil)
	if !errors.Is(err, repository.ErrAlreadyExists) {
		t.Errorf("err = %v, want ErrAlreadyExists", err)
	}
}

// TestUpdateTrustCriteriaNotFound — olmayan bir id için ErrNotFound döner.
func TestUpdateTrustCriteriaNotFound(t *testing.T) {
	ctx := context.Background()
	repo := repository.NewVenueRepo(testPool)

	err := repo.UpdateTrustCriteria(ctx, 32000, "Yok", nil)
	if !errors.Is(err, repository.ErrNotFound) {
		t.Errorf("err = %v, want ErrNotFound", err)
	}
}

// TestDeleteTrustCriteriaRemovesVenueLinks — kriter silindiğinde venue_criteria
// üzerindeki bağlantıların da (FK ihlali olmadan) temizlendiğini doğrular.
func TestDeleteTrustCriteriaRemovesVenueLinks(t *testing.T) {
	truncate(t)
	ctx := context.Background()
	repo := repository.NewVenueRepo(testPool)

	created, err := repo.CreateTrustCriteria(ctx, "test_del_link", "Test Del Link", nil)
	if err != nil {
		t.Fatalf("CreateTrustCriteria hata: %v", err)
	}

	adder := insertTestUser(t)
	venueID := insertVenueInCity(t, adder, "İstanbul", nil)
	if err := repo.SetCriteria(ctx, venueID, []int{created.ID}); err != nil {
		t.Fatalf("SetCriteria hata: %v", err)
	}

	if err := repo.DeleteTrustCriteria(ctx, created.ID); err != nil {
		t.Fatalf("DeleteTrustCriteria hata: %v", err)
	}

	linked, err := repo.GetCriteriaByVenueID(ctx, venueID)
	if err != nil {
		t.Fatalf("GetCriteriaByVenueID hata: %v", err)
	}
	if len(linked) != 0 {
		t.Errorf("silinen kriterin venue_criteria bağlantısı hâlâ mevcut: %v", linked)
	}

	if err := repo.DeleteTrustCriteria(ctx, created.ID); !errors.Is(err, repository.ErrNotFound) {
		t.Errorf("tekrar silme err = %v, want ErrNotFound", err)
	}
}
