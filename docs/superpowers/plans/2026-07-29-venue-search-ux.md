# Mekan Arama UX İyileştirmesi — Uygulama Planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Arama; ad + şehir + ilçe + kategori üzerinde Türkçe-duyarsız çalışsın, tam kart verisiyle yakınlık öncelikli dönsün ve mobilde öneri listesi → "X için sonuçlar" sayfası akışıyla sunulsun.

**Architecture:** Backend'de tek endpoint (`GET /venues?q=`) zenginleştirilir — `unaccent` extension'ı ile normalize eşleşme, kategori adı üzerinde `EXISTS` alt sorgusu, `FindByCity` ile birebir aynı SELECT sütun sırası (mevcut `scanVenueCityRows` yeniden kullanılır). Mobilde öneriler istemcide üretilir: kategoriler ve şehirler mevcut endpoint'lerden bir kez çekilip `normalizeTr` ile lokal eşlenir, mekan önerileri mevcut debounce'lı arama çağrısının ilk 5 sonucundan gelir. Yeni `SearchResultsScreen` sonuçları `VenueCard` ile listeler.

**Tech Stack:** Go 1.x + Fiber v2 + pgx v5 + PostGIS/unaccent (backend); Flutter + Riverpod 3 + go_router 17 + Dio + freezed + flutter_secure_storage (mobil); testify yok — standart `testing`, testcontainers-go (integration), mocktail (mobil).

## Global Constraints

- Tüm kullanıcıya görünen metinler ve kod yorumları **Türkçe**.
- Backend hata yanıtları mevcut kalıpta: `c.Status(...).JSON(fiber.Map{"error": "<türkçe mesaj>"})`.
- `GET /api/v1/venues?q=` yanıt şekli değişmez: `{"data": [...], "count": n}`.
- Arama yalnızca `status = 'approved' AND deleted_at IS NULL` mekanları döndürür.
- Arama sonucu `LIMIT 50`.
- Öneri limitleri: en fazla 3 kategori → 3 şehir → 5 mekan (bu sırayla).
- Son aramalar: en fazla 10 kayıt, tekrarsız, en yeni üstte.
- Yeni Flutter paketi eklenmez — depolama için mevcut `flutter_secure_storage` kullanılır.
- Migration numarası `048` (repodaki son migration `047`).
- Integration testleri `//go:build integration` tag'i ile işaretlenir.

---

### Task 1: unaccent extension migration

**Files:**
- Create: `backend/internal/database/migrations/048_add_unaccent.up.sql`
- Create: `backend/internal/database/migrations/048_add_unaccent.down.sql`

**Interfaces:**
- Consumes: yok (ilk task)
- Produces: veritabanında `unaccent(text)` fonksiyonu — Task 2 bunu kullanır.

- [ ] **Step 1: up migration dosyasını yaz**

`backend/internal/database/migrations/048_add_unaccent.up.sql`:

```sql
-- Arama sorgularında Türkçe karakter duyarsız eşleşme için (ör. "kofte" → "Köfte").
-- venue_search_repo.SearchByText tarafından kullanılır.
CREATE EXTENSION IF NOT EXISTS unaccent;
```

- [ ] **Step 2: down migration dosyasını yaz**

`backend/internal/database/migrations/048_add_unaccent.down.sql`:

```sql
-- Extension bilinçli olarak DROP edilmiyor: aynı veritabanındaki başka
-- şemalar/sorgular da unaccent kullanıyor olabilir, geri alma yıkıcı olur.
SELECT 1;
```

- [ ] **Step 3: Migration'ın geçerli olduğunu doğrula**

Run: `cd backend && go build ./...`
Expected: Hata yok (migration'lar embed ediliyorsa derleme dosyaları toplar).

- [ ] **Step 4: Commit**

```bash
git add backend/internal/database/migrations/048_add_unaccent.up.sql backend/internal/database/migrations/048_add_unaccent.down.sql
git commit -m "feat(db): arama için unaccent extension migration'ı ekle"
```

---

### Task 2: SearchByText'i yeniden yaz (repo katmanı)

**Files:**
- Modify: `backend/internal/repository/venue_search_repo.go:53-84` (`SearchByText`)
- Test: `backend/internal/repository/venue_search_repo_integration_test.go` (Create)

**Interfaces:**
- Consumes: Task 1'in `unaccent` fonksiyonu; mevcut `escapeILIKE(s string) string`; mevcut `(*VenueRepo).scanVenueCityRows(ctx, rows) ([]models.Venue, error)`.
- Produces: `func (r *VenueRepo) SearchByText(ctx context.Context, query string, lat, lng float64) ([]models.Venue, error)` — Task 3 (handler) bu imzayı çağırır.

**Not:** Bu test dosyası kendi `TestMain`'ini **tanımlamaz** — `repository_test` paketinde
`venue_status_repo_integration_test.go` içinde zaten bir `TestMain` ve `testPool` var; aynı
paketteki tüm integration testleri onu paylaşır. Yardımcılar (`truncate`, `insertTestUser`)
da oradan gelir.

- [ ] **Step 1: Failing integration testini yaz**

`backend/internal/repository/venue_search_repo_integration_test.go`:

```go
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
```

- [ ] **Step 2: Testleri çalıştır, derleme hatasıyla başarısız olduklarını gör**

Run: `cd backend && go test -tags=integration ./internal/repository/ -run TestSearchByText -v`
Expected: FAIL — `too many arguments in call to repo.SearchByText` (mevcut imza 2 parametre alıyor).

- [ ] **Step 3: SearchByText'i yeniden yaz**

`backend/internal/repository/venue_search_repo.go` içindeki mevcut `SearchByText` fonksiyonunu (53-84. satırlar, yorum bloğu dahil) tamamen bununla değiştir:

```go
// SearchByText — mekan adı, şehir, ilçe veya yemek kategorisi içinde serbest
// metin araması yapar. Eşleşme Türkçe karakter duyarsızdır (unaccent).
// Yalnızca onaylı mekanlar döner: yeni eklenen mekanlar `pending` doğduğu için
// admin onaylayana kadar aramada görünmez.
//
// lat/lng kullanıcı konumudur; 0,0 gönderilirse mesafe NULL döner ve sıralama
// puana düşer. Sütun sırası FindByCity ile birebir aynıdır; bu yüzden ortak
// scanVenueCityRows tarayıcısı kullanılır.
//
// Not: unaccent() immutable olmadığı için bu sütunlara fonksiyonel index
// kurulamaz; mevcut veri ölçeğinde seq scan kabul edilebilir.
func (r *VenueRepo) SearchByText(ctx context.Context, query string, lat, lng float64) ([]models.Venue, error) {
	query = escapeILIKE(query)
	q := `
		SELECT
			v.id, v.name, v.city, v.district,
			ST_Y(v.location::geometry) AS latitude,
			ST_X(v.location::geometry) AS longitude,
			v.google_place_id,
			v.notes, v.status,
			v.added_by, v.verified_at,
			v.created_at, v.updated_at,
			CASE WHEN $2 != 0.0 AND $3 != 0.0
			     THEN ST_Distance(v.location, ST_MakePoint($3, $2)::geography)
			     ELSE NULL END AS distance,
			COALESCE(AVG(rv.rating), 0)::float8 AS avg_rating,
			COUNT(rv.id)::int AS review_count,
			(
				SELECT STRING_AGG(fc.name, ' · ')
				FROM (
					SELECT DISTINCT fc2.name
					FROM venue_categories vc2
					JOIN food_categories fc2 ON fc2.id = vc2.category_id
					WHERE vc2.venue_id = v.id
					LIMIT 2
				) fc
			) AS categories_str,
			v.confirmation_count
		FROM venues v
		LEFT JOIN reviews rv ON rv.venue_id = v.id
		WHERE v.status = 'approved'
		  AND v.deleted_at IS NULL
		  AND (
		    unaccent(v.name) ILIKE '%' || unaccent($1) || '%'
		    OR unaccent(v.city) ILIKE '%' || unaccent($1) || '%'
		    OR unaccent(COALESCE(v.district, '')) ILIKE '%' || unaccent($1) || '%'
		    OR EXISTS (
		      SELECT 1
		      FROM venue_categories vcs
		      JOIN food_categories fcs ON fcs.id = vcs.category_id
		      WHERE vcs.venue_id = v.id
		        AND unaccent(fcs.name) ILIKE '%' || unaccent($1) || '%'
		    )
		  )
		GROUP BY v.id
		ORDER BY distance ASC NULLS LAST, avg_rating DESC, v.name ASC
		LIMIT 50`

	rows, err := r.db.Query(ctx, q, query, lat, lng)
	if err != nil {
		return nil, fmt.Errorf("metin arama sorgusu başarısız: %w", err)
	}
	defer rows.Close()

	return r.scanVenueCityRows(ctx, rows)
}
```

- [ ] **Step 4: Testleri çalıştır, geçtiklerini doğrula**

Run: `cd backend && go test -tags=integration ./internal/repository/ -run TestSearchByText -v`
Expected: 7 testin hepsi PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/internal/repository/venue_search_repo.go backend/internal/repository/venue_search_repo_integration_test.go
git commit -m "feat(search): aramayı ilçe+kategoriye genişlet, Türkçe duyarsız ve zengin sonuç döndür"
```

---

### Task 3: Handler'da lat/lng geçişi

**Files:**
- Modify: `backend/internal/handlers/venue_query_handler.go:26-35` (`List` fonksiyonunun `q` dalı)

**Interfaces:**
- Consumes: Task 2'nin `SearchByText(ctx, query string, lat, lng float64)` imzası.
- Produces: `GET /api/v1/venues?q=<sorgu>&lat=<lat>&lng=<lng>` — Task 6 (mobil arama provider'ı) ve Task 8 (sonuç sayfası) bu sözleşmeyi çağırır.

- [ ] **Step 1: Handler'ın `q` dalını güncelle**

`backend/internal/handlers/venue_query_handler.go` içinde bu bloğu:

```go
	if q != "" {
		venues, err := h.venueRepo.SearchByText(c.Context(), q)
		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "arama başarısız"})
		}
		return c.JSON(fiber.Map{"data": venues, "count": len(venues)})
	}
```

bununla değiştir:

```go
	if q != "" {
		// Konum opsiyoneldir: gönderilmezse 0,0 gider, mesafe hesaplanmaz ve
		// sıralama puana düşer.
		searchLat := c.QueryFloat("lat", 0)
		searchLng := c.QueryFloat("lng", 0)
		venues, err := h.venueRepo.SearchByText(c.Context(), q, searchLat, searchLng)
		if err != nil {
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "arama başarısız"})
		}
		return c.JSON(fiber.Map{"data": venues, "count": len(venues)})
	}
```

Ayrıca fonksiyonun üstündeki godoc yorumuna arama satırını güncelle:

```go
// List godoc
// GET /api/v1/venues?q=keyword&lat=41.0&lng=29.0
// GET /api/v1/venues?lat=41.0&lng=29.0&radius=5000
// GET /api/v1/venues?city=Istanbul
```

- [ ] **Step 2: Derlemeyi ve mevcut testleri doğrula**

Run: `cd backend && go build ./... && go test ./internal/handlers/`
Expected: Derleme başarılı, mevcut handler testleri PASS.

- [ ] **Step 3: Commit**

```bash
git add backend/internal/handlers/venue_query_handler.go
git commit -m "feat(search): arama endpoint'ine konum parametrelerini geçir"
```

---

### Task 4: Son aramalar deposu (mobil)

**Files:**
- Create: `mobile/lib/features/search/data/recent_searches_store.dart`
- Test: `mobile/test/features/search/recent_searches_store_test.dart` (Create)

**Interfaces:**
- Consumes: `flutter_secure_storage` (mevcut bağımlılık).
- Produces:
  - `class RecentSearchesStore` — ctor `RecentSearchesStore({FlutterSecureStorage? storage})`
  - `Future<List<String>> load()`
  - `Future<List<String>> add(String term)` (güncel listeyi döndürür)
  - `Future<void> clear()`
  - `final recentSearchesStoreProvider = Provider<RecentSearchesStore>(...)`
  - Task 7 (öneri/arama provider'ı) ve Task 9 (boş ekran) bunları kullanır.

- [ ] **Step 1: Failing testi yaz**

`mobile/test/features/search/recent_searches_store_test.dart`:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:itimat/features/search/data/recent_searches_store.dart';

class MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockSecureStorage storage;
  late RecentSearchesStore store;
  // Depodaki güncel değeri taklit eden bellek içi durum.
  String? current;

  setUp(() {
    storage = MockSecureStorage();
    current = null;

    when(() => storage.read(key: any(named: 'key')))
        .thenAnswer((_) async => current);
    when(() => storage.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenAnswer((invocation) async {
      current = invocation.namedArguments[const Symbol('value')] as String?;
    });
    when(() => storage.delete(key: any(named: 'key'))).thenAnswer((_) async {
      current = null;
    });

    store = RecentSearchesStore(storage: storage);
  });

  test('kayıt yokken boş liste döner', () async {
    expect(await store.load(), isEmpty);
  });

  test('eklenen terim listeye girer ve kalıcı olur', () async {
    await store.add('döner');
    expect(await store.load(), ['döner']);
  });

  test('en yeni terim en üstte olur', () async {
    await store.add('döner');
    await store.add('kebap');
    expect(await store.load(), ['kebap', 'döner']);
  });

  test('tekrar aranan terim başa taşınır, çift kayıt oluşmaz', () async {
    await store.add('döner');
    await store.add('kebap');
    await store.add('döner');
    expect(await store.load(), ['döner', 'kebap']);
  });

  test('en fazla 10 kayıt tutulur', () async {
    for (var i = 1; i <= 12; i++) {
      await store.add('terim$i');
    }
    final list = await store.load();
    expect(list.length, 10);
    expect(list.first, 'terim12');
    expect(list.contains('terim1'), isFalse);
    expect(list.contains('terim2'), isFalse);
  });

  test('boş/whitespace terim kaydedilmez', () async {
    await store.add('   ');
    expect(await store.load(), isEmpty);
  });

  test('terim kırpılarak kaydedilir', () async {
    await store.add('  döner  ');
    expect(await store.load(), ['döner']);
  });

  test('clear tüm kayıtları siler', () async {
    await store.add('döner');
    await store.clear();
    expect(await store.load(), isEmpty);
  });

  test('bozuk veri sessizce boş listeye düşer', () async {
    current = 'bu-json-degil{{{';
    expect(await store.load(), isEmpty);
  });
}
```

- [ ] **Step 2: Testi çalıştır, başarısız olduğunu gör**

Run: `cd mobile && flutter test test/features/search/recent_searches_store_test.dart`
Expected: FAIL — `recent_searches_store.dart` bulunamıyor (import hatası).

- [ ] **Step 3: Depoyu yaz**

`mobile/lib/features/search/data/recent_searches_store.dart`:

```dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Son arama terimlerini cihazda saklar.
///
/// Hassas veri değil; projede zaten bulunan flutter_secure_storage kullanılıyor
/// (token_storage.dart deseni) — yalnızca yeni bağımlılık eklememek için.
class RecentSearchesStore {
  static const String _key = 'recent_searches';
  static const int maxItems = 10;

  final FlutterSecureStorage _storage;

  RecentSearchesStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Kayıtlı terimleri en yeniden eskiye döndürür.
  /// Bozuk veri sessizce boş listeye düşer.
  Future<List<String>> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.whereType<String>().toList();
    } catch (_) {
      return [];
    }
  }

  /// Terimi listenin başına ekler; tekrar edenler yukarı taşınır, liste
  /// [maxItems] ile sınırlanır. Güncel listeyi döndürür.
  Future<List<String>> add(String term) async {
    final trimmed = term.trim();
    if (trimmed.isEmpty) return load();

    final list = await load();
    list.removeWhere((e) => e == trimmed);
    list.insert(0, trimmed);

    final capped = list.take(maxItems).toList();
    await _storage.write(key: _key, value: jsonEncode(capped));
    return capped;
  }

  /// Tüm kayıtları siler.
  Future<void> clear() => _storage.delete(key: _key);
}

final recentSearchesStoreProvider = Provider<RecentSearchesStore>(
  (ref) => RecentSearchesStore(),
);
```

- [ ] **Step 4: Testi çalıştır, geçtiğini doğrula**

Run: `cd mobile && flutter test test/features/search/recent_searches_store_test.dart`
Expected: 9 testin hepsi PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/search/data/recent_searches_store.dart mobile/test/features/search/recent_searches_store_test.dart
git commit -m "feat(search): son aramalar deposunu ekle"
```

---

### Task 5: Öneri modeli ve eşleme mantığı (mobil)

**Files:**
- Create: `mobile/lib/features/search/models/search_suggestion.dart`
- Test: `mobile/test/features/search/search_suggestion_test.dart` (Create)

**Interfaces:**
- Consumes: `normalizeTr(String)` — `mobile/lib/features/guide/data/turkish_cities.dart`; `FoodCategory` ve `Venue` — `mobile/lib/core/models/venue.dart`.
- Produces:
  - `enum SuggestionType { category, city, venue }`
  - `class SearchSuggestion` — alanlar: `type`, `label`, `venueId` (nullable), `subtitle` (nullable); `const` ctor `SearchSuggestion({required this.type, required this.label, this.venueId, this.subtitle})`; `==`/`hashCode` override.
  - `List<SearchSuggestion> buildSuggestions({required String query, required List<FoodCategory> categories, required List<String> cities, required List<Venue> venues})`
  - Task 7 (provider) ve Task 9 (ekran) bunları kullanır.

- [ ] **Step 1: Failing testi yaz**

`mobile/test/features/search/search_suggestion_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:itimat/core/models/venue.dart';
import 'package:itimat/features/search/models/search_suggestion.dart';

FoodCategory cat(int id, String name) =>
    FoodCategory(id: id, key: 'k$id', name: name);

Venue venue(String id, String name, String city) => Venue(
      id: id,
      name: name,
      city: city,
      latitude: 41.0,
      longitude: 29.0,
      addedBy: 'test-user',
      status: 'approved',
    );

void main() {
  final categories = [cat(1, 'Döner'), cat(2, 'Kebap'), cat(3, 'Köfte')];
  final cities = ['İstanbul', 'Isparta', 'Bursa'];

  test('boş sorgu için öneri üretilmez', () {
    final result = buildSuggestions(
      query: '   ',
      categories: categories,
      cities: cities,
      venues: [venue('1', 'Dönerci Ali', 'Bursa')],
    );
    expect(result, isEmpty);
  });

  test('kategori Türkçe duyarsız eşleşir', () {
    final result = buildSuggestions(
      query: 'doner',
      categories: categories,
      cities: cities,
      venues: const [],
    );
    expect(result.length, 1);
    expect(result.first.type, SuggestionType.category);
    expect(result.first.label, 'Döner');
  });

  test('şehir Türkçe duyarsız eşleşir', () {
    final result = buildSuggestions(
      query: 'istanbul',
      categories: categories,
      cities: cities,
      venues: const [],
    );
    expect(result.any((s) => s.type == SuggestionType.city && s.label == 'İstanbul'), isTrue);
  });

  test('mekan önerisi id ve şehir alt başlığı taşır', () {
    final result = buildSuggestions(
      query: 'ali',
      categories: categories,
      cities: cities,
      venues: [venue('v1', 'Dönerci Ali', 'Bursa')],
    );
    expect(result.length, 1);
    expect(result.first.type, SuggestionType.venue);
    expect(result.first.venueId, 'v1');
    expect(result.first.subtitle, 'Bursa');
  });

  test('sıra kategori → şehir → mekan olur', () {
    final result = buildSuggestions(
      query: 'k',
      categories: [cat(1, 'Kebap')],
      cities: ['Kayseri'],
      venues: [venue('v1', 'Kral Kebap', 'Bursa')],
    );
    expect(result.map((s) => s.type).toList(), [
      SuggestionType.category,
      SuggestionType.city,
      SuggestionType.venue,
    ]);
  });

  test('limitler uygulanır: 3 kategori, 3 şehir, 5 mekan', () {
    final manyCategories =
        List.generate(6, (i) => cat(i, 'Test Kategori $i'));
    final manyCities = List.generate(6, (i) => 'Test Sehir $i');
    final manyVenues =
        List.generate(9, (i) => venue('v$i', 'Test Mekan $i', 'Bursa'));

    final result = buildSuggestions(
      query: 'test',
      categories: manyCategories,
      cities: manyCities,
      venues: manyVenues,
    );

    expect(result.where((s) => s.type == SuggestionType.category).length, 3);
    expect(result.where((s) => s.type == SuggestionType.city).length, 3);
    expect(result.where((s) => s.type == SuggestionType.venue).length, 5);
  });

  test('eşleşme yoksa boş liste döner', () {
    // Sunucu eşleşme bulamadığında venues boş gelir; kategori/şehir de
    // eşleşmezse öneri listesi boştur.
    final result = buildSuggestions(
      query: 'zzzz',
      categories: categories,
      cities: cities,
      venues: const [],
    );
    expect(result, isEmpty);
  });

  test('sunucudan gelen mekanlar ada göre yeniden filtrelenmez', () {
    // "Meşhur Usta" adında "doner" geçmiyor ama sunucu kategori eşleşmesiyle
    // döndürdü; öneri listesi sonuç sayfasından daha dar olmamalı.
    final result = buildSuggestions(
      query: 'doner',
      categories: categories,
      cities: cities,
      venues: [venue('v1', 'Meşhur Usta', 'Bursa')],
    );
    expect(
      result.any((s) =>
          s.type == SuggestionType.venue && s.label == 'Meşhur Usta'),
      isTrue,
    );
  });
}
```

- [ ] **Step 2: Testi çalıştır, başarısız olduğunu gör**

Run: `cd mobile && flutter test test/features/search/search_suggestion_test.dart`
Expected: FAIL — `search_suggestion.dart` bulunamıyor.

- [ ] **Step 3: Modeli ve eşleme fonksiyonunu yaz**

`mobile/lib/features/search/models/search_suggestion.dart`:

```dart
import '../../../core/models/venue.dart';
import '../../guide/data/turkish_cities.dart';

/// Öneri satırının tipi — ikon, alt başlık ve tıklama davranışını belirler.
enum SuggestionType { category, city, venue }

/// Arama kutusunun altında gösterilen tek bir öneri satırı.
class SearchSuggestion {
  final SuggestionType type;
  final String label;

  /// Yalnızca [SuggestionType.venue] için dolu; tıklanınca detaya gidilir.
  final String? venueId;

  /// Satırın altında gösterilecek ek bilgi (mekan önerilerinde şehir).
  final String? subtitle;

  const SearchSuggestion({
    required this.type,
    required this.label,
    this.venueId,
    this.subtitle,
  });

  @override
  bool operator ==(Object other) =>
      other is SearchSuggestion &&
      other.type == type &&
      other.label == label &&
      other.venueId == venueId &&
      other.subtitle == subtitle;

  @override
  int get hashCode => Object.hash(type, label, venueId, subtitle);
}

const int _maxCategorySuggestions = 3;
const int _maxCitySuggestions = 3;
const int _maxVenueSuggestions = 5;

/// Sorguya göre öneri listesini üretir: önce kategoriler, sonra şehirler,
/// sonra mekanlar. Eşleşme Türkçe karakter duyarsızdır ([normalizeTr]).
///
/// [categories] ve [cities] istemcide cache'lenen tam listelerdir; [venues]
/// ise arama isteğinden dönen mekanlardır. Sunucu ad, şehir, ilçe VEYA kategori
/// üzerinden eşleştirdiği için burada ada göre yeniden filtreleme YAPILMAZ —
/// aksi halde kategorisi eşleşen mekanlar (ör. "doner" için "Meşhur Usta")
/// öneri listesinden düşer ve öneriler sonuç sayfasından dar kalır.
/// Yalnızca sayı sınırlanır.
List<SearchSuggestion> buildSuggestions({
  required String query,
  required List<FoodCategory> categories,
  required List<String> cities,
  required List<Venue> venues,
}) {
  final normalized = normalizeTr(query);
  if (normalized.isEmpty) return [];

  final suggestions = <SearchSuggestion>[];

  for (final category in categories) {
    if (suggestions.length >= _maxCategorySuggestions) break;
    if (normalizeTr(category.name).contains(normalized)) {
      suggestions.add(SearchSuggestion(
        type: SuggestionType.category,
        label: category.name,
      ));
    }
  }

  var cityCount = 0;
  for (final city in cities) {
    if (cityCount >= _maxCitySuggestions) break;
    if (normalizeTr(city).contains(normalized)) {
      suggestions.add(SearchSuggestion(
        type: SuggestionType.city,
        label: city,
      ));
      cityCount++;
    }
  }

  for (final venue in venues.take(_maxVenueSuggestions)) {
    suggestions.add(SearchSuggestion(
      type: SuggestionType.venue,
      label: venue.name,
      venueId: venue.id,
      subtitle: venue.city,
    ));
  }

  return suggestions;
}
```

- [ ] **Step 4: Testi çalıştır, geçtiğini doğrula**

Run: `cd mobile && flutter test test/features/search/search_suggestion_test.dart`
Expected: 7 testin hepsi PASS.

Not: `Venue` modelinin zorunlu alanları testteki `venue()` yardımcısından farklıysa,
yardımcıyı `mobile/lib/core/models/venue.dart` içindeki gerçek zorunlu alanlara göre
düzelt — üretim kodunu değil.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/search/models/search_suggestion.dart mobile/test/features/search/search_suggestion_test.dart
git commit -m "feat(search): öneri modeli ve Türkçe duyarsız eşleme mantığı"
```

---

### Task 6: Şehir listesi provider'ı (mobil)

**Files:**
- Create: `mobile/lib/features/search/providers/search_sources_provider.dart`

**Interfaces:**
- Consumes: `apiClientProvider` — `mobile/lib/core/auth/auth_provider.dart`; `ApiEndpoints.venuesCities`.
- Produces: `final searchCitiesProvider = FutureProvider<List<String>>(...)` — Task 7 kullanır.
- Not: kategoriler için mevcut `foodCategoriesProvider` (`mobile/lib/features/guide/providers/guide_provider.dart:737`) yeniden kullanılır, yenisi yazılmaz.

- [ ] **Step 1: Provider'ı yaz**

`mobile/lib/features/search/providers/search_sources_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_provider.dart';

/// Onaylı mekanı bulunan şehirler — öneri listesinde şehir eşleşmeleri için.
/// Ekran ömrü boyunca bir kez çekilir; öneriler istemcide lokal eşlenir.
final searchCitiesProvider = FutureProvider<List<String>>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get(ApiEndpoints.venuesCities);

  final data = response.data;
  final List<dynamic> list = data is List
      ? data
      : (data is Map<String, dynamic> ? (data['data'] as List? ?? []) : []);

  return list.whereType<String>().toList();
});
```

- [ ] **Step 2: Analiz ile doğrula**

Run: `cd mobile && flutter analyze lib/features/search/providers/search_sources_provider.dart`
Expected: "No issues found!"

- [ ] **Step 3: Commit**

```bash
git add mobile/lib/features/search/providers/search_sources_provider.dart
git commit -m "feat(search): öneri kaynağı olarak şehir listesi provider'ı"
```

---

### Task 7: Arama sonuçları provider'ı (mobil)

**Files:**
- Create: `mobile/lib/features/search/providers/search_results_provider.dart`

**Interfaces:**
- Consumes: `apiClientProvider`; `ApiEndpoints.venues`; `locationServiceProvider` ve `LocationService.getCurrentPosition()` — `mobile/lib/core/utils/location_service.dart`; `Venue.fromJson`.
- Produces:
  - `class SearchResultsNotifier` — `Future<void> retry()` metodu ile hata sonrası yeniden deneme.
  - `final searchResultsProvider = AsyncNotifierProvider.family<SearchResultsNotifier, List<Venue>, String>(...)` — parametre arama terimi. Yükleme/hata/veri durumları `AsyncValue` ile taşınır; ayrı bir state sınıfı yoktur.
  - Task 8 (sonuç ekranı) bunu kullanır.

- [ ] **Step 1: Provider'ı yaz**

`mobile/lib/features/search/providers/search_results_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/venue.dart';
import '../../../core/utils/location_service.dart';

/// Belirli bir arama terimi için sonuçları çeker.
///
/// Konum best-effort alınır: izin yoksa veya hata olursa lat/lng gönderilmez,
/// backend sıralamayı puana düşürür. Konum hatası arama akışını bozmaz.
class SearchResultsNotifier extends FamilyAsyncNotifier<List<Venue>, String> {
  @override
  Future<List<Venue>> build(String term) => _fetch(term);

  Future<List<Venue>> _fetch(String term) async {
    final queryParameters = <String, dynamic>{'q': term};

    try {
      final position =
          await ref.read(locationServiceProvider).getCurrentPosition();
      queryParameters['lat'] = position.latitude;
      queryParameters['lng'] = position.longitude;
    } catch (_) {
      // Konum alınamadı — mesafesiz aramaya devam edilir.
    }

    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.get(
      ApiEndpoints.venues,
      queryParameters: queryParameters,
    );

    final data = response.data;
    final List<dynamic> venueList = data is Map<String, dynamic>
        ? (data['data'] as List? ?? [])
        : (data as List? ?? []);

    return venueList
        .map((json) => Venue.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Hata sonrası "Tekrar dene" için.
  Future<void> retry() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetch(arg));
  }
}

final searchResultsProvider =
    AsyncNotifierProvider.family<SearchResultsNotifier, List<Venue>, String>(
  SearchResultsNotifier.new,
);
```

- [ ] **Step 2: Analizle doğrula**

Run: `cd mobile && flutter analyze lib/features/search/providers/search_results_provider.dart`
Expected: "No issues found!"

Not: Riverpod 3'te family AsyncNotifier taban sınıfı adı farklıysa (`FamilyAsyncNotifier`
yerine `AsyncNotifier` + `arg`), projedeki mevcut bir family provider kullanımını
(`mobile/lib/features/home/providers/venue_list_filter_provider.dart`) örnek alarak uyarla.

- [ ] **Step 3: Commit**

```bash
git add mobile/lib/features/search/providers/search_results_provider.dart
git commit -m "feat(search): arama sonuçları provider'ı (konum best-effort)"
```

---

### Task 8: Sonuç sayfası ve route (mobil)

**Files:**
- Create: `mobile/lib/features/search/screens/search_results_screen.dart`
- Modify: `mobile/lib/core/router/app_router.dart` (AppRoutes sabiti + GoRoute + import)

**Interfaces:**
- Consumes: Task 7'nin `searchResultsProvider`; mevcut `VenueCard` — `mobile/lib/features/venue/widgets/venue_card.dart`; `AppTheme`.
- Produces:
  - `class SearchResultsScreen extends ConsumerWidget` — ctor `SearchResultsScreen({super.key, required this.term})`
  - `AppRoutes.searchResults` = `'/search/results'` (terim `?q=` query parametresiyle)
  - Task 9 (arama ekranı) bu route'a gider.

- [ ] **Step 1: Sonuç ekranını yaz**

`mobile/lib/features/search/screens/search_results_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../venue/widgets/venue_card.dart';
import '../providers/search_results_provider.dart';

/// "<terim> için sonuçlar" sayfası — kategori, şehir, ilçe veya ad eşleşen
/// mekanların tek birleşik listesi.
class SearchResultsScreen extends ConsumerWidget {
  final String term;

  const SearchResultsScreen({super.key, required this.term});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(searchResultsProvider(term));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"$term" için sonuçlar',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            resultsAsync.maybeWhen(
              data: (venues) => Text(
                '${venues.length} mekan bulundu',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
      body: resultsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _ErrorView(
          onRetry: () => ref.read(searchResultsProvider(term).notifier).retry(),
        ),
        data: (venues) {
          if (venues.isEmpty) return _EmptyView(term: term);
          return ListView.builder(
            padding: const EdgeInsets.only(
              top: 8,
              bottom: 8 + AppTheme.bottomNavClearance,
            ),
            itemCount: venues.length,
            itemBuilder: (context, index) => VenueCard(venue: venues[index]),
          );
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Arama başarısız oldu.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Tekrar dene')),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final String term;

  const _EmptyView({required this.term});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '"$term" için sonuç bulunamadı',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Farklı bir kelime veya şehir deneyin',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Route'u ekle**

`mobile/lib/core/router/app_router.dart` içinde:

1. Import bloğuna ekle (mevcut search import'unun yanına):

```dart
import '../../features/search/screens/search_results_screen.dart';
```

2. `AppRoutes` sınıfında `search` sabitinin hemen altına ekle:

```dart
  static const String searchResults = '/search/results';
```

3. Shell route içindeki `AppRoutes.search` GoRoute'unun hemen ardına, aynı seviyede ekle:

```dart
          GoRoute(
            path: AppRoutes.searchResults,
            builder: (context, state) => SearchResultsScreen(
              term: state.uri.queryParameters['q'] ?? '',
            ),
          ),
```

- [ ] **Step 3: Analiz ve derleme doğrulaması**

Run: `cd mobile && flutter analyze lib/features/search/ lib/core/router/app_router.dart`
Expected: "No issues found!"

- [ ] **Step 4: Commit**

```bash
git add mobile/lib/features/search/screens/search_results_screen.dart mobile/lib/core/router/app_router.dart
git commit -m "feat(search): 'X için sonuçlar' sayfası ve route'u"
```

---

### Task 9: Arama ekranını öneri akışına çevir (mobil)

**Files:**
- Modify: `mobile/lib/features/search/screens/search_screen.dart` (tamamen yeniden yazılır)
- Modify: `mobile/lib/features/search/providers/search_provider.dart` (öneri kaynağı olarak sadeleşir)

**Interfaces:**
- Consumes: Task 4'ün `recentSearchesStoreProvider`; Task 5'in `buildSuggestions` / `SearchSuggestion` / `SuggestionType`; Task 6'nın `searchCitiesProvider`; mevcut `foodCategoriesProvider`; Task 8'in `AppRoutes.searchResults`; mevcut `AppRoutes.venueDetail` ve `VenueDetailPreview`.
- Produces: Kullanıcıya görünen arama akışı — sonraki task yok.

- [ ] **Step 1: search_provider.dart'ı öneri kaynağına indirge**

`mobile/lib/features/search/providers/search_provider.dart` dosyasının tamamını bununla değiştir:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/models/venue.dart';

/// Arama kutusunun anlık durumu — yalnızca ÖNERİ listesini besler.
/// Tam sonuçlar ayrı sayfada searchResultsProvider ile çekilir.
class SearchState {
  final List<Venue> venues;
  final bool isLoading;
  final String query;

  const SearchState({
    this.venues = const [],
    this.isLoading = false,
    this.query = '',
  });

  SearchState copyWith({
    List<Venue>? venues,
    bool? isLoading,
    String? query,
  }) {
    return SearchState(
      venues: venues ?? this.venues,
      isLoading: isLoading ?? this.isLoading,
      query: query ?? this.query,
    );
  }
}

class SearchNotifier extends Notifier<SearchState> {
  @override
  SearchState build() => const SearchState();

  Timer? _debounce;

  void search(String query) {
    state = state.copyWith(query: query);

    _debounce?.cancel();
    if (query.trim().isEmpty) {
      state = state.copyWith(venues: [], isLoading: false);
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchVenueSuggestions(query.trim());
    });
  }

  /// Mekan adı önerileri — hata durumunda öneri listesi bozulmaz,
  /// yalnızca mekan satırları görünmez.
  Future<void> _fetchVenueSuggestions(String query) async {
    state = state.copyWith(isLoading: true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get(
        ApiEndpoints.venues,
        queryParameters: {'q': query},
      );

      final data = response.data;
      final List<dynamic> venueList = data is Map<String, dynamic>
          ? (data['data'] as List? ?? [])
          : (data as List? ?? []);

      final venues = venueList
          .map((json) => Venue.fromJson(json as Map<String, dynamic>))
          .toList();

      state = state.copyWith(venues: venues, isLoading: false);
    } catch (_) {
      state = state.copyWith(venues: [], isLoading: false);
    }
  }
}

final searchProvider = NotifierProvider<SearchNotifier, SearchState>(
  SearchNotifier.new,
);
```

- [ ] **Step 2: search_screen.dart'ı yeniden yaz**

`mobile/lib/features/search/screens/search_screen.dart` dosyasının tamamını bununla değiştir:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/venue.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../guide/providers/guide_provider.dart';
import '../../venue/models/venue_detail_preview.dart';
import '../data/recent_searches_store.dart';
import '../models/search_suggestion.dart';
import '../providers/search_provider.dart';
import '../providers/search_sources_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  List<String> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    final list = await ref.read(recentSearchesStoreProvider).load();
    if (!mounted) return;
    setState(() => _recentSearches = list);
  }

  /// Terimi son aramalara kaydeder ve sonuç sayfasına gider.
  Future<void> _openResults(String term) async {
    final trimmed = term.trim();
    if (trimmed.isEmpty) return;

    final updated = await ref.read(recentSearchesStoreProvider).add(trimmed);
    if (!mounted) return;
    setState(() => _recentSearches = updated);

    context.push('${AppRoutes.searchResults}?q=${Uri.encodeComponent(trimmed)}');
  }

  void _openVenue(Venue venue) {
    context.push(
      '/venue/${venue.id}',
      extra: VenueDetailPreview(name: venue.name, city: venue.locationLabel),
    );
  }

  Future<void> _clearRecentSearches() async {
    await ref.read(recentSearchesStoreProvider).clear();
    if (!mounted) return;
    setState(() => _recentSearches = []);
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);

    // Öneri kaynakları — çekilemezse o tip öneriler sessizce atlanır.
    final categories =
        ref.watch(foodCategoriesProvider).valueOrNull ?? const [];
    final cities = ref.watch(searchCitiesProvider).valueOrNull ?? const [];

    final suggestions = buildSuggestions(
      query: searchState.query,
      categories: categories,
      cities: cities,
      venues: searchState.venues,
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Mekan, şehir veya kategori ara...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(searchProvider.notifier).search('');
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  ref.read(searchProvider.notifier).search(value);
                  setState(() {}); // suffixIcon güncellemesi için
                },
                onSubmitted: _openResults,
              ),
            ),
            Expanded(
              child: searchState.query.trim().isEmpty
                  ? _RecentSearchesView(
                      terms: _recentSearches,
                      onTap: _openResults,
                      onClear: _clearRecentSearches,
                    )
                  : _SuggestionsView(
                      suggestions: suggestions,
                      isLoading: searchState.isLoading,
                      onSelect: (suggestion) {
                        if (suggestion.type == SuggestionType.venue) {
                          final venue = searchState.venues.firstWhere(
                            (v) => v.id == suggestion.venueId,
                          );
                          _openVenue(venue);
                        } else {
                          _openResults(suggestion.label);
                        }
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Arama kutusu boşken gösterilen son aramalar listesi.
class _RecentSearchesView extends StatelessWidget {
  final List<String> terms;
  final ValueChanged<String> onTap;
  final VoidCallback onClear;

  const _RecentSearchesView({
    required this.terms,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (terms.isEmpty) {
      return const Center(
        child: Text(
          'Mekan, şehir veya kategori ara',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Son aramalar',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              TextButton(onPressed: onClear, child: const Text('Temizle')),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: terms.length,
            itemBuilder: (context, index) => ListTile(
              leading: const Icon(Icons.history, color: AppTheme.textSecondary),
              title: Text(terms[index]),
              onTap: () => onTap(terms[index]),
            ),
          ),
        ),
      ],
    );
  }
}

/// Yazarken düşen öneri listesi.
class _SuggestionsView extends StatelessWidget {
  final List<SearchSuggestion> suggestions;
  final bool isLoading;
  final ValueChanged<SearchSuggestion> onSelect;

  const _SuggestionsView({
    required this.suggestions,
    required this.isLoading,
    required this.onSelect,
  });

  IconData _iconFor(SuggestionType type) => switch (type) {
        SuggestionType.category => Icons.restaurant_menu,
        SuggestionType.city => Icons.place_outlined,
        SuggestionType.venue => Icons.storefront_outlined,
      };

  String _labelFor(SearchSuggestion suggestion) => switch (suggestion.type) {
        SuggestionType.category => 'Kategori',
        SuggestionType.city => 'Şehir',
        SuggestionType.venue => suggestion.subtitle == null
            ? 'Mekan'
            : 'Mekan · ${suggestion.subtitle}',
      };

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      if (isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return const Center(
        child: Text(
          'Öneri bulunamadı. Aramak için Enter\'a basın.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = suggestions[index];
        return ListTile(
          leading: Icon(_iconFor(suggestion.type), color: AppTheme.textSecondary),
          title: Text(suggestion.label),
          subtitle: Text(
            _labelFor(suggestion),
            style: const TextStyle(fontSize: 12),
          ),
          onTap: () => onSelect(suggestion),
        );
      },
    );
  }
}
```

- [ ] **Step 3: Analiz ve mevcut testlerle doğrula**

Run: `cd mobile && flutter analyze lib/features/search/ && flutter test`
Expected: "No issues found!" ve tüm testler PASS.

Not: `venue.locationLabel` alanı `VenueCard` içinde kullanılıyor; yoksa `venue.city` kullan.

- [ ] **Step 4: Commit**

```bash
git add mobile/lib/features/search/screens/search_screen.dart mobile/lib/features/search/providers/search_provider.dart
git commit -m "feat(search): öneri listeli arama ekranı ve son aramalar"
```

---

### Task 10: Liste-içi lokal aramayı Türkçe duyarsız yap

**Files:**
- Modify: `mobile/lib/features/home/providers/venue_filter_provider.dart:130-133`
- Test: `mobile/test/features/home/venue_filter_provider_test.dart` (Create veya varsa Modify)

**Interfaces:**
- Consumes: `normalizeTr` — `mobile/lib/features/guide/data/turkish_cities.dart`.
- Produces: davranış değişikliği; sonraki task yok.

- [ ] **Step 1: Failing testi yaz**

Dosya varsa `main()` içine ekle, yoksa `mobile/test/features/home/venue_filter_provider_test.dart` olarak oluştur:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:itimat/core/models/venue.dart';
import 'package:itimat/features/home/providers/venue_filter_provider.dart';

Venue _venue(String name) => Venue(
      id: name,
      name: name,
      city: 'Bursa',
      latitude: 41.0,
      longitude: 29.0,
      addedBy: 'test-user',
      status: 'approved',
    );

void main() {
  test('lokal isim araması Türkçe karakter duyarsızdır', () {
    final venues = [_venue('Köfteci Yusuf'), _venue('Pizza Roma')];

    final result = filterAndSortVenues(
      venues,
      sort: VenueSortOption.none,
      nameQuery: 'kofte',
    );

    expect(result.length, 1);
    expect(result.first.name, 'Köfteci Yusuf');
  });

  test('büyük/küçük harf farkı sonucu etkilemez', () {
    final venues = [_venue('Dönerci Ali')];

    final result = filterAndSortVenues(
      venues,
      sort: VenueSortOption.none,
      nameQuery: 'DONERCI',
    );

    expect(result.length, 1);
  });
}
```

- [ ] **Step 2: Testi çalıştır, başarısız olduğunu gör**

Run: `cd mobile && flutter test test/features/home/venue_filter_provider_test.dart`
Expected: FAIL — ilk test "Expected: <1> Actual: <0>" (mevcut `toLowerCase` eşleşmesi "kofte"yi bulmaz).

- [ ] **Step 3: normalizeTr'ye geçir**

`mobile/lib/features/home/providers/venue_filter_provider.dart` dosyasında:

1. Import bloğuna ekle:

```dart
import '../../guide/data/turkish_cities.dart';
```

2. Bu bloğu:

```dart
  final query = nameQuery.trim().toLowerCase();
  if (query.isNotEmpty) {
    list = list.where((v) => v.name.toLowerCase().contains(query));
  }
```

bununla değiştir:

```dart
  // Türkçe karakter duyarsız eşleşme — arama ekranıyla aynı davranış.
  final query = normalizeTr(nameQuery);
  if (query.isNotEmpty) {
    list = list.where((v) => normalizeTr(v.name).contains(query));
  }
```

- [ ] **Step 4: Testleri çalıştır, geçtiklerini doğrula**

Run: `cd mobile && flutter test test/features/home/venue_filter_provider_test.dart && flutter test`
Expected: Yeni testler PASS ve tüm mevcut testler PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/home/providers/venue_filter_provider.dart mobile/test/features/home/venue_filter_provider_test.dart
git commit -m "fix(search): liste içi lokal aramayı Türkçe duyarsız yap"
```

---

### Task 11: Dokümantasyon güncellemesi

**Files:**
- Modify: `docs/techContext.md` (endpoint listesi)
- Modify: `docs/progress.md` (tamamlanan iş kaydı)

**Interfaces:**
- Consumes: Task 1-10'un tamamlanmış hali.
- Produces: güncel dokümantasyon; sonraki task yok.

**Not:** CLAUDE.md kuralı — "En son yapılan işi ilgili /docs da bulunan ilgili raporları
güncelleyerek kayıt altına al."

- [ ] **Step 1: techContext.md'deki endpoint kaydını güncelle**

`docs/techContext.md` içinde `GET /api/v1/venues` satırını bul ve arama parametrelerini
yansıtacak şekilde güncelle. Satır formatı dosyadaki mevcut kalıba uymalı; içerik:

- `GET /api/v1/venues?q=<terim>&lat=&lng=` — serbest metin araması; ad, şehir, ilçe ve
  yemek kategorisi üzerinde Türkçe karakter duyarsız (unaccent) eşleşme. `lat`/`lng`
  opsiyonel; verilirse mesafe hesaplanır ve yakınlığa göre sıralanır, verilmezse puana
  göre sıralanır. Yalnızca onaylı mekanlar, `LIMIT 50`.

- [ ] **Step 2: progress.md'ye kayıt ekle**

`docs/progress.md` dosyasının kayıt kalıbına uygun olarak, en üste (veya dosyanın
kronolojik yönüne göre uygun yere) şu içerikle bir giriş ekle:

- Başlık: Mekan Arama UX İyileştirmesi (2026-07-29)
- Backend: `unaccent` extension (migration 048); `SearchByText` ad + şehir + ilçe +
  kategori üzerinde Türkçe duyarsız arıyor, `FindByCity` ile aynı zengin sütun setini
  döndürüyor (mesafe, puan, yorum sayısı, kategoriler, rozet), yakınlık öncelikli sıralıyor.
- Mobil: Arama ekranı öneri listesine dönüştü (kategori/şehir/mekan, istemcide lokal
  eşleme); yeni `SearchResultsScreen` ("X için sonuçlar") tek birleşik liste gösteriyor;
  son aramalar cihazda saklanıyor; liste-içi lokal arama da Türkçe duyarsız oldu.
- İlgili spec: `docs/superpowers/specs/2026-07-29-venue-search-ux-design.md`

- [ ] **Step 3: Commit**

```bash
git add docs/techContext.md docs/progress.md
git commit -m "docs: arama iyileştirmesini techContext ve progress'e işle"
```

---

## Uygulama Sırası ve Bağımlılıklar

- Task 1 → Task 2 → Task 3 (backend zinciri, sırayla)
- Task 4, 5, 6 birbirinden bağımsız (paralel yapılabilir)
- Task 7 → Task 8 (sonuç akışı)
- Task 9, Task 4/5/6/8'in tamamlanmasını bekler
- Task 10 bağımsız (istenirse en başta da yapılabilir)
- Task 11 en son
