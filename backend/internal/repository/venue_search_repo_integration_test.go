//go:build integration

package repository_test

import (
	"context"
	"testing"

	"github.com/omerkoc/itimat-mobile/internal/repository"
)

// insertSearchVenue — arama testleri için ad/şehir/ilçe/konum kontrollü mekan ekler.
func insertSearchVenue(t *testing.T, userID, name, city, district string, lat, lng float64) string {
	t.Helper()
	var id string
	err := testPool.QueryRow(context.Background(),
		`INSERT INTO venues (name, city, district, location, status, added_by)
		 VALUES ($1, $2, $3, ST_SetSRID(ST_MakePoint($4, $5), 4326)::geography, 'approved', $6)
		 RETURNING id`,
		name, city, district, lng, lat, userID,
	).Scan(&id)
	if err != nil {
		t.Fatalf("arama test mekanı eklenemedi: %v", err)
	}
	return id
}

// attachCategory — mekana isme göre bir yemek kategorisi bağlar.
func attachCategory(t *testing.T, venueID, categoryName string) {
	t.Helper()
	_, err := testPool.Exec(context.Background(),
		`INSERT INTO venue_categories (venue_id, category_id)
		 SELECT $1, id FROM food_categories WHERE name = $2`,
		venueID, categoryName,
	)
	if err != nil {
		t.Fatalf("kategori bağlanamadı: %v", err)
	}
}

func TestSearchByText_TurkceKarakterDuyarsiz(t *testing.T) {
	truncate(t)
	userID := insertTestUser(t)
	insertSearchVenue(t, userID, "Köfteci Yusuf", "İstanbul", "Kadıköy", 41.0, 29.0)

	repo := repository.NewVenueRepo(testPool)
	venues, err := repo.SearchByText(context.Background(), "kofte", 0, 0)
	if err != nil {
		t.Fatalf("SearchByText hatası: %v", err)
	}
	if len(venues) != 1 {
		t.Fatalf("1 mekan beklendi, %d geldi", len(venues))
	}
	if venues[0].Name != "Köfteci Yusuf" {
		t.Fatalf("beklenen 'Köfteci Yusuf', gelen %q", venues[0].Name)
	}
}

func TestSearchByText_KategoriAdiyleEslesir(t *testing.T) {
	truncate(t)
	userID := insertTestUser(t)
	// Adında "döner" geçmiyor; yalnızca kategorisi Döner.
	id := insertSearchVenue(t, userID, "Meşhur Usta", "Bursa", "Osmangazi", 40.2, 29.0)
	attachCategory(t, id, "Döner")

	repo := repository.NewVenueRepo(testPool)
	venues, err := repo.SearchByText(context.Background(), "doner", 0, 0)
	if err != nil {
		t.Fatalf("SearchByText hatası: %v", err)
	}
	if len(venues) != 1 {
		t.Fatalf("kategori eşleşmesiyle 1 mekan beklendi, %d geldi", len(venues))
	}
	if venues[0].Name != "Meşhur Usta" {
		t.Fatalf("beklenen 'Meşhur Usta', gelen %q", venues[0].Name)
	}
}

func TestSearchByText_IlceAdiylaEslesir(t *testing.T) {
	truncate(t)
	userID := insertTestUser(t)
	insertSearchVenue(t, userID, "Test Mekan", "İstanbul", "Kadıköy", 41.0, 29.0)

	repo := repository.NewVenueRepo(testPool)
	venues, err := repo.SearchByText(context.Background(), "kadikoy", 0, 0)
	if err != nil {
		t.Fatalf("SearchByText hatası: %v", err)
	}
	if len(venues) != 1 {
		t.Fatalf("ilçe eşleşmesiyle 1 mekan beklendi, %d geldi", len(venues))
	}
}

func TestSearchByText_KonumVarsaMesafeyeGoreSiralar(t *testing.T) {
	truncate(t)
	userID := insertTestUser(t)
	// Uzak olan önce eklenir; sıralama mesafeye göre olmalı.
	insertSearchVenue(t, userID, "Döner Uzak", "İstanbul", "Şile", 41.18, 29.61)
	insertSearchVenue(t, userID, "Döner Yakın", "İstanbul", "Kadıköy", 41.0, 29.0)

	repo := repository.NewVenueRepo(testPool)
	venues, err := repo.SearchByText(context.Background(), "döner", 41.0, 29.0)
	if err != nil {
		t.Fatalf("SearchByText hatası: %v", err)
	}
	if len(venues) != 2 {
		t.Fatalf("2 mekan beklendi, %d geldi", len(venues))
	}
	if venues[0].Name != "Döner Yakın" {
		t.Fatalf("ilk sırada 'Döner Yakın' beklendi, gelen %q", venues[0].Name)
	}
	if venues[0].Distance == nil {
		t.Fatal("konum verilince distance dolu olmalı")
	}
}

func TestSearchByText_KonumYoksaMesafeNil(t *testing.T) {
	truncate(t)
	userID := insertTestUser(t)
	insertSearchVenue(t, userID, "Döner Yeri", "İstanbul", "Kadıköy", 41.0, 29.0)

	repo := repository.NewVenueRepo(testPool)
	venues, err := repo.SearchByText(context.Background(), "döner", 0, 0)
	if err != nil {
		t.Fatalf("SearchByText hatası: %v", err)
	}
	if len(venues) != 1 {
		t.Fatalf("1 mekan beklendi, %d geldi", len(venues))
	}
	if venues[0].Distance != nil {
		t.Fatalf("konum yokken distance nil olmalı, gelen %v", *venues[0].Distance)
	}
}

func TestSearchByText_OnaysizMekanDonmez(t *testing.T) {
	truncate(t)
	userID := insertTestUser(t)
	_, err := testPool.Exec(context.Background(),
		`INSERT INTO venues (name, city, district, location, status, added_by)
		 VALUES ('Döner Bekleyen', 'İstanbul', 'Kadıköy',
		         ST_SetSRID(ST_MakePoint(29.0, 41.0), 4326)::geography, 'pending', $1)`,
		userID,
	)
	if err != nil {
		t.Fatalf("pending mekan eklenemedi: %v", err)
	}

	repo := repository.NewVenueRepo(testPool)
	venues, err := repo.SearchByText(context.Background(), "döner", 0, 0)
	if err != nil {
		t.Fatalf("SearchByText hatası: %v", err)
	}
	if len(venues) != 0 {
		t.Fatalf("pending mekan dönmemeliydi, %d geldi", len(venues))
	}
}

func TestSearchByText_JokerKarakterKacirilir(t *testing.T) {
	truncate(t)
	userID := insertTestUser(t)
	insertSearchVenue(t, userID, "Döner Yeri", "İstanbul", "Kadıköy", 41.0, 29.0)

	repo := repository.NewVenueRepo(testPool)
	// "%" escape edilmezse tüm mekanlar dönerdi.
	venues, err := repo.SearchByText(context.Background(), "%", 0, 0)
	if err != nil {
		t.Fatalf("SearchByText hatası: %v", err)
	}
	if len(venues) != 0 {
		t.Fatalf("joker karakter kaçırılmalıydı, %d mekan geldi", len(venues))
	}
}
