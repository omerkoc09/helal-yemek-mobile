# Mekan Arama UX İyileştirmesi — Tasarım Dokümanı

**Tarih:** 2026-07-29
**Durum:** Onaylandı (kullanıcı ile bölüm bölüm doğrulandı)
**Kapsam:** Backend arama sorgusu + mobil arama deneyimi (öneri listesi, sonuç sayfası, son aramalar)

## 1. Problem

Mevcut arama üç noktada zayıf:

1. **Bulamama:** Arama yalnızca mekan adı + şehir alanlarında, Türkçe karaktere duyarlı
   (`kofte` → `Köfte` bulunmaz). Kategori aranmıyor: "kebap" yazan kullanıcı kategorisi
   kebap olan mekanları göremiyor, yalnızca adında "kebap" geçenleri görüyor.
2. **Sonuç kalitesi:** `SearchByText` sonuçları mesafe, puan, yorum sayısı, rozet ve
   kategori olmadan dönüyor; sıralama alfabetik. Kartlar diğer listelere göre fakir.
3. **Boş ekran:** Arama ekranı yazmadan önce bomboş; sonuç yokken kuru "Sonuç bulunamadı".

## 2. Hedef Deneyim

- Kullanıcı yazarken **öneri listesi** düşer: kategori / şehir / mekan eşleşmeleri,
  tip ikonlu ve etiketli (Google/Yemeksepeti modeli).
- Öneriye tıklama veya enter → **adanmış sonuç sayfası**: `"döner" için sonuçlar`
  başlığı altında **tek birleşik liste** (kategorisi döner olan + adında döner geçen
  mekanlar karışık). `"istanbul"` → İstanbul'daki mekanlar. Kartlar tam veriyle
  (puan, mesafe, rozet, kategori, fotoğraf).
- **Sıralama yakınlık öncelikli**; konum izni yoksa puan öncelikli.
- Arama ekranı boşken **son aramalar** gösterilir.

## 3. Backend Tasarımı

### 3.1 Endpoint sözleşmesi

`GET /api/v1/venues?q=<sorgu>&lat=<lat>&lng=<lng>`

- `lat`/`lng` **opsiyonel**; gönderilmezse `0` kabul edilir ve mesafe hesaplanmaz.
- Yanıt şekli değişmez: `{"data": [...], "count": n}`. Venue nesneleri artık
  `FindByCity` ile aynı zenginlikte döner (distance, avg_rating, review_count,
  categories_str, confirmation_count/badge, photos, categories).
- Geriye uyumluluk: `q` parametresinin önceliği ve mevcut çağrı şekli korunur.

### 3.2 Migration

`internal/database/migrations/048_add_unaccent.up.sql`:

```sql
CREATE EXTENSION IF NOT EXISTS unaccent;
```

Down migration'da extension DROP edilmez (paylaşımlı kullanım riski); no-op yorum bırakılır.

### 3.3 SearchByText yeniden yazımı

İmza: `SearchByText(ctx, query string, lat, lng float64) ([]models.Venue, error)`

- **Aranan alanlar** (hepsi `unaccent(alan) ILIKE '%' || unaccent($1) || '%'`):
  - `v.name`
  - `v.city`
  - `v.district`
  - kategori adı: `EXISTS (SELECT 1 FROM venue_categories vc JOIN food_categories fc
    ON fc.id = vc.category_id WHERE vc.venue_id = v.id AND unaccent(fc.name) ILIKE ...)`
- **Filtre:** `v.status = 'approved' AND v.deleted_at IS NULL` (mevcut davranış korunur).
- **`escapeILIKE`** mevcut haliyle kullanılmaya devam eder.
- **SELECT sütunları:** `FindByCity` ile birebir aynı sıra — böylece mevcut
  `scanVenueCityRows` scanner'ı aynen yeniden kullanılır; yeni scanner yazılmaz.
  Mesafe `CASE WHEN $lat != 0 AND $lng != 0 THEN ST_Distance(...) ELSE NULL END`.
- **Sıralama:** `ORDER BY distance ASC NULLS LAST, avg_rating DESC, v.name ASC`
  — konum varsa yakınlık, yoksa (tüm distance'lar NULL) puan öncelikli.
- **LIMIT 50.**
- **Index yok:** `unaccent()` immutable olmadığından fonksiyonel index doğrudan
  kurulamaz; mevcut veri ölçeğinde seq scan kabul edilebilir. Veri büyürse
  `pg_trgm` + normalize edilmiş sütun ayrı bir iş olarak ele alınır.

### 3.4 Handler değişikliği

`VenueHandler.List` içindeki `q` dalı `lat`/`lng` query paramlarını da okuyup
`SearchByText`'e geçirir. Hata mesajları mevcut kalıpta (Türkçe, `fiber.Map{"error": ...}`).

## 4. Mobil Tasarım

### 4.1 Öneri akışı (SearchScreen yeniden düzenleme)

- **Veri kaynakları:**
  - Kategoriler: `/food-categories` — ekran açılışında bir kez çekilir, cache'lenir.
  - Şehirler: `/venues/cities` — ekran açılışında bir kez çekilir, cache'lenir.
  - Mekan önerileri: mevcut 500ms debounce'lı `GET /venues?q=` çağrısının ilk 5 sonucu.
- **Eşleme:** kategori ve şehir önerileri **lokal** üretilir; `normalizeTr`
  (city_picker_sheet'teki mevcut yardımcı) ile Türkçe-duyarsız `contains` eşleşmesi.
- **Öneri listesi sırası ve limitleri:** en fazla 3 kategori → 3 şehir → 5 mekan.
  Her satır: tip ikonu + ad + alt etiket ("Kategori" / "Şehir" / "Mekan · <şehir>").
- **Davranış:**
  - Kategori veya şehir önerisine tıklama → o terimle sonuç sayfası.
  - Mekan önerisine tıklama → **doğrudan mekan detay sayfası**.
  - Klavyeden enter/submit → yazılan metinle sonuç sayfası.
  - Sonuç sayfası açan her eylem terimi son aramalara kaydeder.

### 4.2 Sonuç sayfası (yeni: SearchResultsScreen)

- `app_router`'a yeni route; parametre: arama terimi.
- **Başlık:** `"<terim>" için sonuçlar`, altında `<n> mekan bulundu`.
- **Gövde:** mevcut `VenueCard` ile liste — backend artık tam kart verisi döndürdüğü
  için puan/mesafe/rozet/kategori dolu gelir.
- **Konum:** `locationService.getCurrentPosition()` best-effort (home_provider deseni);
  izin yok/hata → `lat/lng` gönderilmez, backend puana göre sıralar. Konum beklerken
  ekran bloklanmaz.
- **Durumlar:**
  - Yükleniyor: spinner.
  - Hata: mesaj + "Tekrar dene" butonu.
  - Boş: `"<terim>" için sonuç bulunamadı` + `Farklı bir kelime veya şehir deneyin` alt metni.

### 4.3 Son aramalar

- `flutter_secure_storage`'ta JSON listesi (projede mevcut bağımlılık — `token_storage.dart`
  deseni; yeni paket eklenmez); en fazla 10 kayıt, tekrarsız
  (aynı terim tekrar aranırsa en üste taşınır), en yeni üstte.
- Arama kutusu boşken listelenir; "temizle" eylemi tümünü siler.
- Kayda tıklama → o terimle sonuç sayfası.
- Hiç kayıt yokken kısa ipucu metni ("Mekan, şehir veya kategori ara").
- Bozuk/parse edilemeyen veri sessizce sıfırlanır.

### 4.4 Tutarlılık düzeltmesi (liste-içi arama)

`filterAndSortVenues` içindeki `nameQuery` eşleşmesi `toLowerCase().contains` yerine
`normalizeTr` kullanır — böylece all_venues_screen'deki lokal arama da Türkçe-duyarsız olur.

## 5. Hata Yönetimi

- **Öneri kaynakları:** kategori/şehir listesi çekilemezse o tip öneriler sessizce
  atlanır; arama akışı çalışmaya devam eder. Mekan önerisi isteği hata verirse
  öneri listesi bozulmaz (yalnızca mekan satırları görünmez).
- **Sonuç sayfası:** API hatasında kullanıcıya mesaj + yeniden deneme.
- **Backend:** mevcut hata kalıbı (500 + Türkçe mesaj) korunur.

## 6. Test Kapsamı

- **Backend repo testi:** Türkçe normalizasyon (`kofte` → "Köfte"), kategori adıyla
  eşleşme, konum var/yok sıralama davranışı, `escapeILIKE` etkileşimi.
- **Backend handler testi:** `q` + `lat`/`lng` parametre geçişi (mevcut test desenleri).
- **Mobil unit testleri:** öneri eşleme mantığı (kategori/şehir lokal eşleme,
  limitler, sıra) ve son-aramalar deposu (ekleme, tekrarsızlık, 10 kayıt sınırı, temizleme).

## 7. Kapsam Dışı

- Öneriler için ayrı `/search/suggest` endpoint'i (sunucu tarafı öneri) — YAGNI.
- Arama index'leri (`pg_trgm`, normalize sütun) — veri büyüyünce ayrı iş.
- Bölümlü sonuç sayfası (kategori/ad grupları) — tek birleşik liste seçildi.
- Boş ekranda kategori ızgarası / popüler şehirler — yalnızca son aramalar seçildi.
- Admin panel araması.
