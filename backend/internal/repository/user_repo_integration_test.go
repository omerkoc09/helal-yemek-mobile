//go:build integration

package repository_test

import (
	"context"
	"testing"

	"github.com/omerkoc/caiz-mi/internal/repository"
)

func TestGetGuideCity(t *testing.T) {
	truncate(t)
	ctx := context.Background()
	repo := repository.NewUserRepo(testPool)

	// guide_city dolu kullanıcı
	uid := insertTestUser(t) // role='guide'
	if err := repo.SetGuideCity(ctx, uid, "Ankara"); err != nil {
		t.Fatalf("SetGuideCity: %v", err)
	}
	got, err := repo.GetGuideCity(ctx, uid)
	if err != nil {
		t.Fatalf("GetGuideCity: %v", err)
	}
	if got == nil || *got != "Ankara" {
		t.Fatalf("guide_city = %v; want Ankara", got)
	}

	// guide_city NULL kullanıcı
	uid2 := insertTraveler(t)
	got2, err := repo.GetGuideCity(ctx, uid2)
	if err != nil {
		t.Fatalf("GetGuideCity(null): %v", err)
	}
	if got2 != nil {
		t.Fatalf("guide_city = %v; want nil", got2)
	}
}
