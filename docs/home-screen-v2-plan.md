# Ana Sayfa v2 — Düzeltme Planı

**Tarih:** 2026-04-02  
**Durum:** Onaylandı, uygulanmayı bekliyor

---

## Kapsam

1. "Yakınımdaki" → "Şehrimdeki" restoranlar (Places API ile standart şehir/semt)
2. Header konumu: koordinat → semt adı (`geocoding` paketi)
3. Venue kartları: puan + kategori bilgisi ekleme
4. Arama kutucuğu: odaklandığında kategori grid overlay'i

---

## Soru-Cevap Özeti

**S: Google Maps linkinden şehir/semt alınabilir mi?**  
Evet. `google_place_id (ChIJ...)` elimizde olduğunda Place Details API ile `locality` (İstanbul) ve `sublocality_level_1` (Kadıköy) standart olarak geliyor. `PlacesService` zaten mevcut ve API key'i var — sadece yeni bir metot ekleniyor.

**Kararlar:**
- Başlık dinamik şehir adıyla → "İstanbul'daki Restoranlar"
- Kategori fotoğrafları kare
- Kartta max 2 kategori gösterilir → "Döner · Tavuk"

---

## Adım 1 — Backend: `district` Alanı + Migration

**Dosya:** `backend/internal/database/migrations/`

```sql
ALTER TABLE venues ADD COLUMN IF NOT EXISTS district VARCHAR(100);
```

**Dosya:** `backend/internal/models/venue.go`

```go
District    *string `json:"district,omitempty"`
CategoriesStr *string `json:"categories_str,omitempty"`
```

---

## Adım 2 — Backend: PlacesService Genişletme

**Dosya:** `backend/internal/services/places_service.go`

Yeni metot eklenir:

```go
type AddressComponents struct {
    City     string // locality
    District string // sublocality_level_1
}

func (s *PlacesService) GetAddressComponents(placeID string) (*AddressComponents, error)
```

Çağrı:
```
GET https://maps.googleapis.com/maps/api/place/details/json
  ?place_id=ChIJ...
  &fields=address_components
  &key=<API_KEY>
```

`address_components` içinden:
- `types` = `["locality"]` → `City`
- `types` = `["sublocality_level_1"]` → `District`

---

## Adım 3 — Backend: Venue Create/Update'te Auto-fill

**Dosya:** `backend/internal/handlers/venue_handler.go`

`google_place_id` resolve edildikten sonra:

```go
if placeID != "" && h.placesService != nil {
    if components, err := h.placesService.GetAddressComponents(placeID); err == nil {
        venue.City = components.City
        venue.District = &components.District
    }
}
```

- `google_place_id` yoksa → elle girilen `city` fallback olarak kalır
- Create ve Update handler'larının ikisine de eklenir

---

## Adım 4 — Backend: `FindByCity` Güncelleme

**Dosya:** `backend/internal/repository/venue_search_repo.go`

Mevcut `FindByCity` metodu güncellenir — `distance`, `avg_rating`, `review_count` ve `categories_str` eklenir:

```sql
SELECT
    v.id, v.name, v.address, v.city, v.district,
    ST_Y(v.location::geometry) AS latitude,
    ST_X(v.location::geometry) AS longitude,
    v.google_place_id, v.notes, v.status,
    v.added_by, v.verified_at, v.created_at, v.updated_at,
    ST_Distance(v.location, ST_MakePoint($3, $2)::geography) AS distance,
    COALESCE(AVG(rv.rating), 0)::float8 AS avg_rating,
    COUNT(rv.id)::int AS review_count,
    (
        SELECT STRING_AGG(fc.label_tr, ' · ')
        FROM (
            SELECT DISTINCT fc2.label_tr
            FROM venue_food_items vfi2
            JOIN food_items fi2 ON fi2.id = vfi2.food_item_id
            JOIN food_categories fc2 ON fc2.id = fi2.category_id
            WHERE vfi2.venue_id = v.id
            LIMIT 2
        ) fc
    ) AS categories_str
FROM venues v
LEFT JOIN reviews rv ON rv.venue_id = v.id
WHERE v.city ILIKE $1
  AND v.status = 'approved'
  AND v.deleted_at IS NULL
GROUP BY v.id
ORDER BY distance ASC
LIMIT $4   -- 0 = tümü, 10 = slider
```

**Not:** `LOWER()` yerine `ILIKE` kullanılıyor — Türkçe İ/i harfi için locale bağımsız çalışır.

**Yeni imza:**
```go
func (r *VenueRepo) FindByCity(ctx context.Context, city string, lat, lng float64, limit int) ([]models.Venue, error)
```

Scan: `scanVenueRowsWithRatingAndPhotos` genişletilir → `categories_str` ve `district` de scan edilir.

---

## Adım 5 — Backend: Handler Güncelleme

**Dosya:** `backend/internal/handlers/venue_handler.go` → `List` metodu

`city` parametresi geldiğinde `lat`, `lng` ve `limit` de alınır:

```go
if city != "" {
    lat := c.QueryFloat("lat", 0)
    lng := c.QueryFloat("lng", 0)
    limit := c.QueryInt("limit", 10)
    venues, err := h.venueRepo.FindByCity(c.Context(), city, lat, lng, limit)
    ...
}
```

---

## Adım 6 — Flutter: Venue Modeli Güncelleme

**Dosya:** `mobile/lib/core/models/venue.dart`

```dart
@JsonKey(name: 'categories_str') String? categoriesStr,
String? district,
```

Codegen yeniden çalıştırılır:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

---

## Adım 7 — Flutter: `geocoding` Paketi

**Dosya:** `mobile/pubspec.yaml`

```yaml
geocoding: ^3.0.0
```

`AppHeader` güncellenir:

```dart
final placemarks = await placemarkFromCoordinates(lat, lng);
final sub  = placemarks.first.subLocality;   // Kadıköy
final city = placemarks.first.locality;       // İstanbul
return sub?.isNotEmpty == true ? sub! : (city ?? 'Konumunuzu Seçin');
```

`HomeProvider.fetchFeed()`:

```dart
final placemarks = await placemarkFromCoordinates(lat, lng);
final city = placemarks.first.locality ?? '';
// GET /venues?city=İstanbul&lat=...&lng=...&limit=10
```

---

## Adım 8 — Flutter: Venue Kartları Güncelleme

**Dosya:** `mobile/lib/features/venue/widgets/venue_horizontal_card.dart`  
**Dosya:** `mobile/lib/features/venue/widgets/venue_card.dart`

Her iki karta şu satır eklenir:

```
⭐ 4.6  (1200+)   · 2.7 km
Döner · Tavuk          ← categoriesStr ?? gizle
```

`VenueHorizontalCard` için hedef görünüm:
```
┌────────────────┐
│   [Fotoğraf]   │
│                │
│ Akıncı Zurna   │
│ ⭐ 4.6 · 2.7km │
│ Döner · Tavuk  │
└────────────────┘
```

`VenueCard` için (dikey liste):
```
[Foto] Akıncı Zurna Dürüm  ✓
       ⭐ 4.6 (1200+) · 2.7 km
       Döner · Tavuk
```

---

## Adım 9 — Flutter: Arama Overlay → Kategori Grid

**Dosya:** `mobile/lib/features/home/screens/home_screen.dart`  
**Yeni dosya:** `mobile/lib/features/home/widgets/category_grid.dart`

### Durum makinesi

```
_focusNode.hasFocus = false → Feed (slider'lar)
_focusNode.hasFocus = true  AND query boş → CategoryGrid
_focusNode.hasFocus = true  AND query dolu → SearchResults
```

### CategoryGrid

Referans görsele göre 3 sütun, kare fotoğraf + isim altında:

```dart
GridView.builder(
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 3,
    childAspectRatio: 0.85,
    crossAxisSpacing: 10,
    mainAxisSpacing: 10,
  ),
  ...
)
```

Her kart:
```
┌──────────┐
│  [kare   │
│  fotoğ.] │
│  Döner   │
└──────────┘
```

Tıklandığında:
1. `foodDiscoveryProvider.selectCategory(id, label)` çağrılır
2. `context.go('/food-discovery')` ile sayfaya gidilir

---

## Etkilenen Dosyalar

| Dosya | Değişiklik Tipi |
|---|---|
| `backend/internal/database/migrations/` | YENİ — district kolonu |
| `backend/internal/models/venue.go` | Güncelleme — District, CategoriesStr |
| `backend/internal/services/places_service.go` | Güncelleme — GetAddressComponents() |
| `backend/internal/handlers/venue_handler.go` | Güncelleme — auto-fill + city handler |
| `backend/internal/repository/venue_search_repo.go` | Güncelleme — FindByCity yeni imza |
| `mobile/pubspec.yaml` | Güncelleme — geocoding paketi |
| `mobile/lib/core/models/venue.dart` | Güncelleme — categoriesStr, district |
| `mobile/lib/features/home/providers/home_provider.dart` | Güncelleme — şehir bazlı fetch |
| `mobile/lib/shared/widgets/app_header.dart` | Güncelleme — semt adı |
| `mobile/lib/features/venue/widgets/venue_card.dart` | Güncelleme — puan + kategori |
| `mobile/lib/features/venue/widgets/venue_horizontal_card.dart` | Güncelleme — puan + kategori |
| `mobile/lib/features/home/screens/home_screen.dart` | Güncelleme — overlay logic |
| `mobile/lib/features/home/widgets/category_grid.dart` | YENİ |

---

---

## Adım 10 — Backend: `GetAddressComponents` Genişletme (`name` Dahil)

**Dosya:** `backend/internal/services/places_service.go`

`AddressComponents` struct'ına `Name` eklenir:

```go
type AddressComponents struct {
    Name     string // display_name
    City     string // locality
    District string // sublocality_level_1
}
```

`GetAddressComponents` çağrısındaki `fields` parametresi güncellenir:

```
&fields=name,address_components
```

**Önemli:** Bu metot yalnızca `ChIJ` prefix'li place_id'lerle çağrılmalıdır. `0x` hex formatı geçerli bir Places API place_id değildir; backend zaten bu durumu `venue_handler.go:205-212`'de handle ediyor (hex → `ResolvePlaceID` ile yeniden çözüm, başarısızsa nil).

---

## Adım 11 — Backend: Yeni Endpoint `GET /venues/place-preview`

**Dosya:** `backend/internal/handlers/venue_handler.go`

```go
// PlacePreview godoc
// GET /api/v1/venues/place-preview?place_id=ChIJ...
// Yalnızca Guide rolü erişebilir.
func (h *VenueHandler) PlacePreview(c *fiber.Ctx) error {
    placeID := c.Query("place_id")
    if placeID == "" || !strings.HasPrefix(placeID, "ChIJ") {
        return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
            "error": "geçerli bir place_id gereklidir (ChIJ... formatı)",
        })
    }

    components, err := h.placesService.GetAddressComponents(placeID)
    if err != nil || components == nil {
        return c.Status(fiber.StatusUnprocessableEntity).JSON(fiber.Map{
            "error": "mekan bilgileri alınamadı",
        })
    }

    return c.JSON(fiber.Map{
        "name":     components.Name,
        "city":     components.City,
        "district": components.District,
    })
}
```

**Dosya:** `backend/cmd/api/main.go` (route kaydı)

```go
guideRoutes.Get("/venues/place-preview", venueHandler.PlacePreview)
```

---

## Adım 12 — Flutter: Adım Sırası Yeniden Düzenleme

**Dosya:** `mobile/lib/features/guide/screens/add_venue_screen.dart`

**Mevcut sıra:** `0=İsim → 1=Konum → 2=Kriter → 3=Not/Foto → 4=Yemek`

**Yeni sıra:** `0=Konum → 1=İsim (pre-filled) → 2=Kriter → 3=Not/Foto → 4=Yemek`

`_buildStepContent` güncellenir:
```dart
return switch (state.currentStep) {
  0 => const AddVenueLocationStep(), // önce konum + link
  1 => _buildNameStep(),             // pre-filled, düzenlenebilir
  2 => _buildCriteriaStep(),
  3 => _buildNotesPhotoStep(state),
  4 => const AddVenueFoodStep(),
  _ => const SizedBox.shrink(),
};
```

`canProceedStep0` → konum validasyonu (mevcut `canProceedStep1` mantığı):
```dart
bool get canProceedStep0 =>
    latitude != null && longitude != null && city.isNotEmpty && district.isNotEmpty;

bool get canProceedStep1 => name.trim().isNotEmpty;
```

---

## Adım 13 — Flutter: `AddVenueState` Genişletme

**Dosya:** `mobile/lib/features/guide/providers/guide_provider.dart`

Yeni alanlar:
```dart
final bool isLoadingPlaceDetails; // Place Details API çağrısı devam ediyor
```

`AddVenueNotifier`'a yeni metot:

```dart
/// place_id ChIJ formatındaysa Place Details API'yi çağırır.
/// Dönen name/city/district değerlerini state'e yazar.
/// Başarısız olursa state bozulmaz — kullanıcı elle doldurur.
Future<void> fetchPlaceDetails(String placeId) async {
  if (!placeId.startsWith('ChIJ')) return; // hex format → atla

  state = state.copyWith(isLoadingPlaceDetails: true);
  try {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.get(
      ApiEndpoints.placePreview,
      queryParameters: {'place_id': placeId},
    );
    final data = response.data as Map<String, dynamic>;
    state = state.copyWith(
      name: (data['name'] as String? ?? '').isNotEmpty
          ? data['name'] as String
          : state.name,
      city: data['city'] as String? ?? state.city,
      district: data['district'] as String? ?? state.district,
      isLoadingPlaceDetails: false,
    );
  } catch (_) {
    state = state.copyWith(isLoadingPlaceDetails: false);
    // Sessiz fail — kullanıcı bilgileri elle girer
  }
}
```

`parseMapsLink` başarılı olduğunda `fetchPlaceDetails` tetiklenir:

```dart
final coords = await GoogleMapsParser.parseLink(link);
if (coords != null) {
  state = state.copyWith(
    latitude: coords.latitude,
    longitude: coords.longitude,
    googlePlaceId: coords.placeId,
    isParsingLink: false,
  );
  // place_id varsa ve ChIJ formatındaysa detayları çek
  if (coords.placeId != null) {
    fetchPlaceDetails(coords.placeId!); // await yok, arka planda
  }
  return true;
}
```

**API endpoint sabiti eklenir:**

```dart
// lib/core/api/api_endpoints.dart
static const String placePreview = '/venues/place-preview';
```

---

## Adım 14 — Flutter: Location Step'te Preview Card

**Dosya:** `mobile/lib/features/guide/widgets/add_venue_location_step.dart`

Link başarıyla parse edildikten sonra (koordinat ve place_id alındı) konum mini haritasının üstüne preview card eklenir:

```
┌─────────────────────────────────────┐
│ 📍 Bulunan Mekan Bilgileri          │
│                                     │
│  Mekan:  Akıncı Zurna Dürüm        │
│  Şehir:  İstanbul                  │
│  Semt:   Kadıköy                   │
│                                     │
│  [Bilgiler yanlışsa düzenleyebilirsiniz →]  │
└─────────────────────────────────────┘
```

- `isLoadingPlaceDetails = true` iken: küçük `CircularProgressIndicator` gösterilir
- Bilgiler geldikten sonra: tablo benzeri önizleme kutusu
- `ChIJ` prefix yoksa (hex veya link'ten place_id çıkarılamadıysa): preview card gösterilmez, kullanıcı sonraki adımda adı elle girer

**Senaryo B (link yok) değişmez:** `_noGoogleMapsLink = true` durumunda il/ilçe dropdown'ları `required` validation'a tabi tutulur — `canProceedStep0` zaten `city.isNotEmpty && district.isNotEmpty` kontrolü yapıyor.

---

## Güncellenen Etkilenen Dosyalar

| Dosya | Değişiklik Tipi |
|---|---|
| `backend/internal/database/migrations/` | YENİ — district kolonu |
| `backend/internal/models/venue.go` | Güncelleme — District, CategoriesStr |
| `backend/internal/services/places_service.go` | Güncelleme — GetAddressComponents() + Name alanı |
| `backend/internal/handlers/venue_handler.go` | Güncelleme — PlacePreview endpoint + auto-fill + city handler |
| `backend/cmd/api/main.go` | Güncelleme — /venues/place-preview route |
| `backend/internal/repository/venue_search_repo.go` | Güncelleme — FindByCity yeni imza |
| `mobile/pubspec.yaml` | Güncelleme — geocoding paketi |
| `mobile/lib/core/models/venue.dart` | Güncelleme — categoriesStr, district |
| `mobile/lib/core/api/api_endpoints.dart` | Güncelleme — placePreview sabiti |
| `mobile/lib/features/home/providers/home_provider.dart` | Güncelleme — şehir bazlı fetch |
| `mobile/lib/shared/widgets/app_header.dart` | Güncelleme — semt adı |
| `mobile/lib/features/venue/widgets/venue_card.dart` | Güncelleme — puan + kategori |
| `mobile/lib/features/venue/widgets/venue_horizontal_card.dart` | Güncelleme — puan + kategori |
| `mobile/lib/features/home/screens/home_screen.dart` | Güncelleme — overlay logic |
| `mobile/lib/features/home/widgets/category_grid.dart` | YENİ |
| `mobile/lib/features/guide/providers/guide_provider.dart` | Güncelleme — fetchPlaceDetails(), isLoadingPlaceDetails |
| `mobile/lib/features/guide/screens/add_venue_screen.dart` | Güncelleme — adım sırası yeniden düzenleme |
| `mobile/lib/features/guide/widgets/add_venue_location_step.dart` | Güncelleme — preview card |

---

## Uygulama Sırası

```
Adım 1-2 (Backend district + GetAddressComponents + name)
    → Adım 10-11 (Backend PlacePreview endpoint)
        → Adım 3 (Backend venue create/update auto-fill)
            → Adım 4-5 (Backend repo + handler FindByCity)
                → Adım 6 (Flutter model + codegen)
                    → Adım 12-14 (Flutter add venue akışı)
                        → Adım 7 (geocoding paketi)
                            → Adım 8 (Kartlar)
                                → Adım 9 (Arama overlay)
```

Backend ve Flutter bağımsız başlanabilir; ancak Adım 12-14 (Flutter add venue) Adım 11 (backend endpoint) olmadan mock ile test edilebilir.
