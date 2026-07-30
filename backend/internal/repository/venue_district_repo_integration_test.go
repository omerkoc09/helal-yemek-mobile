//go:build integration

package repository_test

import (
	"context"
	"testing"

	"github.com/omerkoc/itimat-mobile/internal/repository"
)

// insertDistrictVenue — ilçe testleri için şehir/ilçe/durum kontrollü mekan ekler.
func insertDistrictVenue(t *testing.T, userID, city, district, status string) {
	t.Helper()
	_, err := testPool.Exec(context.Background(),
		`INSERT INTO venues (name, city, district, location, status, added_by)
		 VALUES ('Test Mekan', $1, $2,
		         ST_SetSRID(ST_MakePoint(29.0, 41.0), 4326)::geography, $3, $4)`,
		city, district, status, userID,
	)
	if err != nil {
		t.Fatalf("ilçe test mekanı eklenemedi: %v", err)
	}
}

func TestFindDistinctDistricts_TekrarsizVeSirali(t *testing.T) {
	truncate(t)
	userID := insertTestUser(t)
	insertDistrictVenue(t, userID, "İstanbul", "Kadıköy", "approved")
	insertDistrictVenue(t, userID, "İstanbul", "Kadıköy", "approved") // tekrar
	insertDistrictVenue(t, userID, "İstanbul", "Fatih", "approved")
	insertDistrictVenue(t, userID, "Bursa", "Osmangazi", "approved")

	repo := repository.NewVenueRepo(testPool)
	list, err := repo.FindDistinctDistricts(context.Background())
	if err != nil {
		t.Fatalf("FindDistinctDistricts hatası: %v", err)
	}

	if len(list) != 3 {
		t.Fatalf("3 benzersiz çift beklendi, %d geldi: %+v", len(list), list)
	}
	// city, district ASC sıralaması: Bursa/Osmangazi, İstanbul/Fatih, İstanbul/Kadıköy
	if list[0].City != "Bursa" || list[0].District != "Osmangazi" {
		t.Fatalf("ilk sırada Bursa/Osmangazi beklendi, gelen %+v", list[0])
	}
}

func TestFindDistinctDistricts_OnaysizVeBosIlceHaric(t *testing.T) {
	truncate(t)
	userID := insertTestUser(t)
	insertDistrictVenue(t, userID, "İstanbul", "Kadıköy", "approved")
	insertDistrictVenue(t, userID, "İstanbul", "Beşiktaş", "pending") // onaysız
	insertDistrictVenue(t, userID, "İzmir", "", "approved")           // boş ilçe

	repo := repository.NewVenueRepo(testPool)
	list, err := repo.FindDistinctDistricts(context.Background())
	if err != nil {
		t.Fatalf("FindDistinctDistricts hatası: %v", err)
	}

	if len(list) != 1 {
		t.Fatalf("yalnızca 1 çift beklendi, %d geldi: %+v", len(list), list)
	}
	if list[0].District != "Kadıköy" {
		t.Fatalf("beklenen Kadıköy, gelen %q", list[0].District)
	}
}

func TestFindDistinctDistricts_KayitYokkaBosDilim(t *testing.T) {
	truncate(t)

	repo := repository.NewVenueRepo(testPool)
	list, err := repo.FindDistinctDistricts(context.Background())
	if err != nil {
		t.Fatalf("FindDistinctDistricts hatası: %v", err)
	}
	if list == nil {
		t.Fatal("nil değil boş dilim dönmeliydi (JSON'da [] olması için)")
	}
	if len(list) != 0 {
		t.Fatalf("boş dilim beklendi, %d geldi", len(list))
	}
}
