# İtimat — Proje İlerleme Durumu

> Son güncelleme: 2026-07-27
Mevcut Durum Notu: Proje genel hatlarıyla Faz 5'e (Test & Yayın) geçmiş gibi görünse de, Faz 1-4 arasındaki bazı özelliklerde (MVP çekirdeği) mimari değişiklikler, UX revizyonları ve bug fix'ler yapılmaktadır. Bir modülü düzenlerken, eski kodun kusursuz olduğunu varsayma; refactoring (kod iyileştirme) ve mantık değişiklikleri yapmak serbesttir ve gereklidir.
---

## Düzgün Çalışmayan Kısımlar
kullanıcı harita üzerinde kendi işaretlediği bir konumun linkini mekan olarak eklediğinde en azından koordinatları parse edebilmeliyiz.


search kısmında places api kullanılmalı mı?

search de dondurma kategorisinde olmasına rağmen gelmeyen mekan var
bunun sebebi aynı şehirdekileri gösteriyor sadece yani gizli bir şehir filter var olmalı mı filter da da aynı durum geçerli.?

## Revize Edilecek Özellikler:
Design of the app:
deteermine the app color palette and stick to it. Keep it simple and consistent app should feels clean and professional

add cta button in the bottom navigation (for guides it can be adding new venue for travelers it can be map) so that it can be easily reachable.


## Öncelikli Olarak Yapılması Gerekenler

admin panel üzerinden manuel notification atma

smtp env yi doldur.

mekan puanlamasını çeşitlendirme?

kullanıcının şehrine veya yakınına yeni mekan eklenirse bildirim? uygulama arka planda konum çekmeye devam edecek mi?

**
birden fazla rehberin onaylamasıyla yeni rozet takdimi ✅

popüler restoran metriği zengileştirilmesi yani sadece puan değil. tıklama sayısı veya yol tarifi alma sayısı gibi istatistikler.
**

mobil:
-~~profili düzenle zenginleştirilecek.~~ ✅ (2026-06-19)
-~~yorumların anonimliği kaldırılacak.~~ ✅ (2026-06-19)
-seyyahın rehberliği onaylanınca uygulamadan çıkıp  geri girmesi gerekiyor? (bildirim atılabilir)
-~~status rehber->seyyah yapınca rehber başvurunuz inceleniyor sayfası geliyor ama tekrar bir guide başvurusu yapılmıyor otomatik olarak.~~ ✅ (2026-06-19)

rehberlere yeni bir özellik ekleyelim: ✅
hangi şehir için rehberlik yapacağını belirleyelim.
hali hazırda ikamet ettiği şehirde rehberlik yapabilsin. (semt seçmeli mi)
bunu rehberlik başvurusunda şart koşalım. Referans kodu ile rehber ekleme mantığını kaldırsak mı? o tarafı kontrol etmek zor. Hem aynı kontrolleri iki defa yapmış olacağız. Herkes bizim kontrolümüzden geçse daha iyi gibi. 
hem panelden hangi şehirlerde kaç tane rehber olduğunu görürüz (harita mantıklı)



## Tamamlanan İşler

### Auth Hardening — Arka Plan Login Kaydı Güvenli Hale Getirildi — YENİ

> 2026-06-28'de yapıldı. Üretim davranışı odaklı küçük bir sağlamlaştırma (hardening). Yeni özellik değil; mevcut "fire-and-forget" login kaydı pattern'indeki iki gizli üretim riski kapatıldı.

| Değişiklik | Durum | Detay |
|-----------|-------|-------|
| `recordLogin` helper | ✅ | `AuthService` içindeki 5 ayrı `go func() { _ = s.loginRepo.Record(context.Background(), user.ID) }()` çağrısı tek bir `recordLogin(userID)` helper'ında toplandı (DRY). Çağrı yerleri `go s.recordLogin(user.ID)` oldu. |
| Goroutine leak koruması | ✅ | `context.Background()` timeout'suzdu → DB takılırsa goroutine sonsuza asılı kalabilirdi. Artık `context.WithTimeout(..., 5*time.Second)` + `defer cancel()`. |
| Yutulan hata loglanıyor | ✅ | `_ =` ile DB hatası sessizce kayboluyordu; artık `log.Printf("login kaydı yazılamadı (user=%s): %v", ...)`. Mevcut `log` paketi idiomu korundu, yeni bağımlılık yok. |
| Doğrulama | ✅ | `go build ./...` ve `go vet ./internal/services/` temiz (vet `lostcancel` analizi `defer cancel()`'i doğruladı). |

---

### Mekan Dönemsel Onay Reset — VerifyByGuide Reset + Düşen Rehber Bildirimi — YENİ

> 2026-06-27'de tamamlandı. Mekan ekleyen rehber yeniden doğruladığında (re-verify), diğer rehberlerin dönemsel onayları sıfırlanıyor; etkilenen rehberlere `confirmation_reset` bildirimi gönderiliyor.

| Değişiklik | Durum | Detay |
|-----------|-------|-------|
| VerifyByGuide reset mantığı | ✅ | Mekan adder re-verify → tek transaction'da diğer rehberlerin `venue_confirmations` satırları silinir, `confirmation_count=0`, `is_double_verified=false`. verification_due_at / suspend davranışı değişmez. |
| Düşen rehber bildirimi | ✅ | Reset yapılan rehberlere `confirmation_reset` in-app notification gönderilir. |

---

### Venue Rozet & Dönemsel Doğrulama — Backend Çekirdek — YENİ

> 2026-06-27'de tamamlandı. Mekan güven rozeti altyapısının tüm backend çekirdeği tamamlandı.

| Değişiklik | Durum | Detay |
|-----------|-------|-------|
| Migration 036 | ✅ | `venues.confirmation_count` ve `is_double_verified` dönemsel anlamla yeniden eklendi; `venue_confirmations.period_start` kolonu eklendi. |
| Badge modeli | ✅ | `models.Badge` (level/count) + `BadgeFromCount` (0=Temel, 1=Bronz, 2-5=Gümüş, 6-10=Altın, 11+=Platin). |
| ConfirmVenue genişletme | ✅ | `ConfirmVenueRepo`: şehir doğrulaması, `confirmation_count++`, periyot kontrolü (`period_start`). |
| FindByGooglePlaceID + check-duplicate endpoint | ✅ | Duplicate önleme için Google Place ID sorgulama ve `/venues/check-duplicate` endpoint'i. |
| FindByID + liste sorgularında badge | ✅ | `FindByID`, `FindByCity`, `FindNearby`, `FindNearbyApproved`, `FindPopular` — tümünde `confirmation_count`/`is_double_verified` SELECT edilir, `BadgeFromCount` ile `Badge` alanı doldurulur. Admin listeleri (FindAll, FindPending, FindByAddedBy, FindByUserID, FindByFoodCategory) badge gerektirmediğinden değiştirilmedi (YAGNI). |
| Testler | ✅ | `TestConfirmVenueIncrementsCount`, `TestConfirmVenueRejectsWrongCity`, `TestFindByIDIncludesBadge`, `TestFindByGooglePlaceID` — tümü PASS (testcontainers). |

---

### Yol Tarifi Tıklama Takibi — YENİ

> 2026-06-26'da yapıldı. Mobil "Yol Tarifi" butonuna her basılış artık kaydediliyor ve admin panelin aktivite raporunda günlük trend + "en çok yol tarifi alınan mekanlar" olarak görünüyor. Mevcut `user_logins`/`GetActivityStats` aktivite altyapısının birebir uzantısı. Tasarım: `docs/superpowers/specs/2026-06-25-venue-direction-click-tracking-design.md`, Plan: `docs/superpowers/plans/2026-06-25-venue-direction-click-tracking.md`.

| Değişiklik | Durum | Detay |
|-----------|-------|-------|
| `venue_direction_clicks` tablosu | ✅ | Migration 035. Her tıklama ayrı satır: `venue_id` (FK, CASCADE), opsiyonel `user_id` (FK, SET NULL → anonim tıklamalar NULL, kullanıcı silinse de sayım korunur), `created_at`. venue_id + created_at index'leri. |
| `DirectionClickRepo` | ✅ | `Create` / `CountByDay` / `TopVenues`. `login_repo` desenini takip eder. Integration test testcontainers'da PASS. |
| `POST /venues/:id/direction-click` | ✅ | Opsiyonel auth (`OptionalAuth`): token varsa user_id, yoksa anonim. Fire-and-forget, her zaman 204 döner. Handler testi (anonim + auth'lu) PASS. |
| Admin `GET /admin/stats/activity` genişletme | ✅ | Yanıta `trend.direction_clicks` (günlük dizi, `logins` ile aynı format) ve `top_direction_venues` (top 10) eklendi. Mevcut alanlar korundu. |
| Mobil tracking | ✅ | `trackDirectionClick(ref, venueId)` — beklemeden çağrı, hata yutulur, Google Maps her durumda açılır. İki çağrı noktası: venue detay + harita bottom sheet (StatelessWidget → ConsumerWidget). |
| Admin panel raporu | ✅ | `activity.vue`'ya "Günlük Yol Tarifi" bar grafiği + "En Çok Yol Tarifi Alınan Mekanlar" listesi (ad, şehir, sayı). Mevcut gün aralığı toggle'ıyla çalışır. |

### Admin Panel: Türkiye Rehber Yoğunluk Haritası — YENİ

> 2026-06-22'de yapıldı. Admin panelindeki "Şehir Bazlı Rehberler" sayfasına etkileşimli Türkiye choropleth haritası eklendi. Her il rehber sayısına göre renkleniyor: 0 → gri, sayı arttıkça primary tonu koyulaşıyor (sabit 5 kademe opaklık). İl üstünde rehber sayısı yazıyor (0 ise yazılmıyor), hover'da `İl: N rehber` tooltip çıkıyor; altta lejant. Mevcut tablo korundu (harita üstte, tablo altta). Backend değişmedi (mevcut `GET /admin/guides/by-city`). Sadece frontend: gömülü Türkiye SVG (`vite-svg-loader` + `?component`), plaka→kanonik il + centroid statik haritaları, `TurkeyGuideMap.vue`. Plaka→il eşlemesi `backend/internal/models/cities.go` (81 il) ile birebir doğrulandı; centroid'ler SVG geometrisinden hesaplandı. Tasarım: `docs/superpowers/specs/2026-06-22-admin-turkey-guide-map-design.md`, Plan: `docs/superpowers/plans/2026-06-22-admin-turkey-guide-map.md`.

| Değişiklik | Durum | Detay |
|-----------|-------|-------|
| Türkiye SVG | ✅ | `admin-panel/src/assets/turkey-map.svg` (81 il, `data-plate` 01–81) |
| Plaka/il/centroid/opaklık | ✅ | `admin-panel/src/utils/turkeyPlates.ts` (81 il backend cities.go ile birebir) |
| Choropleth bileşeni | ✅ | `admin-panel/src/components/TurkeyGuideMap.vue` (renk + sayı + tooltip + lejant) |
| Sayfa entegrasyonu | ✅ | `guides-by-city.vue`: harita üstte, mevcut tablo altta |
| `*.svg?component` tipi | ✅ | `shims.d.ts`'e ambient modül bildirimi eklendi |
| Doğrulama | ✅ | `pnpm build` hatasız; headless Chrome render testi (10 örnek il doğru renk/sayı/konum) |

### Profil: Dinamik Rehber Rozeti + Harita "Mekan Ekle" Butonu Kaldırma — YENİ

> 2026-06-22'de yapıldı. İki küçük iş:
>
> 1. **Harita "Mekan Ekle" butonu kaldırıldı:** `map_screen.dart` içindeki `FloatingActionButton.extended` ("Mekan Ekle") + ilgili `authState`/`showAddButton` ve artık kullanılmayan `go_router`/`auth_provider` importları temizlendi. `/add-venue` route'u duruyor; sadece haritadaki giriş noktası kaldırıldı.
> 2. **Dinamik rehber rozeti:** Rozet artık rehberin şehrini gösteriyor → `<Şehir> Rehberi` (ör. "İstanbul Rehberi"). `guide_city` NULL ise sade "Rehber".
>    - **Backend:** `models.User`'a `guide_city` (`json:"guide_city,omitempty"`) eklendi; `UserRepo.FindByID` SELECT/Scan'ine `guide_city` kolonu eklendi → `/me` yanıtı artık şehri döner. Migration gerekmedi (kolon `032` ile mevcut).
>    - **Mobil:** `User` modeline `guideCity` (`@JsonKey(name: 'guide_city')`) eklendi (build_runner ile yeniden üretildi); `_RoleBadge` `guideCity` alıp `guide` rolünde dinamik etiket gösteriyor.

### Mobil Refactor 3 Madde (Profil + Yorum İsmi + Demote Başvuru) — YENİ

> 2026-06-19'da yapıldı. Tasarım: `docs/superpowers/specs/2026-06-19-mobil-refactor-3-madde-design.md`. Plan: `docs/superpowers/plans/2026-06-19-mobil-refactor-3-madde.md`.

| Değişiklik | Durum | Detay |
|-----------|-------|-------|
| Profil zenginleştirme | ✅ | Edit ekranına soyad + telefon (opsiyonel) eklendi; email salt-okunur; header ad+soyad gösterir |
| Yorum ismi | ✅ | Review sorgusu users join'i + "Ad S." görünen ad; mobil 'Anonim' kaldırıldı |
| Demote başvuru | ✅ | `cancelled` durumu + demote'ta açık başvuru kapatma → kullanıcı yeniden başvurabilir |

### Mobil Admin Panelinin Kaldırılması — YENİ

> 2026-06-19'da yapıldı. Admin paneli web'e taşındığı için mobildeki çift/ölü admin kodu kaldırıldı. Yukarıdaki "status -> admin yapılırsa uygulama nasıl tepki verir" sorusunun cevabı: **admin rehber (guide) gibi davranır** — login sonrası home'a gider, profilde guide menüleri görünür, admin'e özel ekran yoktur. `isAdmin` rol bilgisi backend ile tutarlılık için korundu. Tasarım: `docs/superpowers/specs/2026-06-19-mobil-admin-panel-kaldirma-design.md`.

| Değişiklik | Durum | Detay |
|-----------|-------|-------|
| Admin feature | ✅ | `mobile/lib/features/admin/` tamamen silindi (8 provider, 9 screen, 1 widget, 1 util) |
| audit_log modeli | ✅ | `core/models/audit_log.dart` (+ `.g`/`.freezed`) silindi (sadece admin kullanıyordu) |
| Router | ✅ | 9 admin import/route/GoRoute silindi; login redirect home'a sabitlendi; `/admin` guard kaldırıldı |
| Profil | ✅ | "Admin Paneli" menü öğesi silindi (guide menüleri `isGuide \|\| isAdmin` korundu) |
| API endpoints | ✅ | ~16 admin endpoint sabiti silindi |
| Doğrulama | ✅ | `flutter analyze` admin'e dair sıfır hata (kalan 20 uyarı kapsam dışı, önceden vardı) |

### Kodsuz Guide Başvurusu (Manuel Onay) — YENİ

> 2026-06-17'de eklendi. Referans kodu olmayan traveler, "okudum-onaylıyorum" onayıyla admin'e başvuru gönderebiliyor; admin onaylayınca guide oluyor. Kodlu/otomatik onay yolu birincil, bu ikincil. Tasarım: `docs/superpowers/specs/2026-06-17-codeless-guide-application-design.md`.

| Değişiklik | Durum | Detay |
|-----------|-------|-------|
| Migration 031 | ✅ | `guide_applications.terms_accepted_at` kolonu |
| Apply iki yol | ✅ | `referral_code` boşsa `terms_accepted` zorunlu → pending başvuru (`GuideHandler.Apply`) |
| Manuel onay | ✅ | `ApproveApplication`/`RejectApplication` yeniden aktif (rol guide + kod üretir) |
| admin-panel | ✅ | Guide Başvuruları listesinde "BAŞVURU TARİHİ" kolonu |
| Mobil | ✅ | "Referans kodum yok" formu (placeholder şartlar + onay kutusu); pending'de "inceleniyor" kartı |
| Test | ✅ | Kodsuz başvuru kaydı integration testi |
| Durum kalıcılığı | ✅ | `GET /guide/my-application` ile açılışta pending/rejected durumu çekiliyor; rejected'da ret notu gösteriliyor |

### Referans Kodu v2: Çok Kullanımlı Kod + Otomatik Onay — YENİ

> 2026-06-17'de eklendi. Referans kodu sistemi tek kullanımlık + otomatik yenilenen modelden, kalıcı + çok kullanımlı modele geçirildi ve admin onayı kaldırılıp otomatik onaya dönüştürüldü. Tasarım: `docs/superpowers/specs/2026-06-17-referral-auto-approve-design.md`.

| Değişiklik | Durum | Detay |
|-----------|-------|-------|
| Migration 029 | ✅ | `referral_codes` tablosundan `used_by`/`used_at` kaldırıldı; kodlar kalıcı/çok kullanımlı |
| Otomatik onay | ✅ | Geçerli kod giren traveler admin onayı olmadan anında guide oluyor (`GuideHandler.Apply` → `ReferralRepo.ApproveGuideTx`, tek transaction) |
| Self-referral guard | ✅ | Kullanıcı kendi kodunu kullanamaz (400) |
| Demote'ta iptal | ✅ | Admin bir guide'ı başka role düşürürse aktif kodu `revoked` oluyor (`UpdateUser` → `RevokeByGuideID`) |
| Admin takip | ✅ | Kullanıcılar sayfasına "GETİREN" + "GETİRDİĞİ" kolonları (`UserRepo.List` join'leri) |
| Eski onay akışı | ✅ | Manuel approve/reject endpoint'leri geri dönüş için duruyor ama devre dışı işaretlendi |
| Mobil | ✅ | Apply başarısında `/auth/me` ile rol tazeleniyor, "inceleniyor" kartı kaldırıldı |
| Testler | ✅ | `ApproveGuideTx`, `RevokeByGuideID`, kullanıcı listesi kolonları için integration testleri (testcontainers) |

### Rehber-Şehir Bağlama & Referans Kodu Kaldırma — YENİ

> 2026-06-20'de eklendi. Rehberlik başvurusu artık tek yol: şehir beyanı + kullanım şartları → admin onayı. Referans kodu sistemi tamamıyla kaldırıldı (migration ile `referral_codes` tablo temizlendi). 81 il sabit listesi backend doğrulamada ve mobil seçicide kullanılıyor. Admin panelde şehir bazlı rehber sayımı ve başvuru onay ekranında şehir kolonu eklendi. Dev-only temizlik script'i (`backend/scripts/cleanup_referral_guides.sql`) demote işlemi için hazırlandı (şehirsiz eski rehberleri traveler'a indirir, veri korunur).

> 2026-06-22'de eklendi (mekan ekleme şehir kısıtı — enforcement). Rehber artık yalnızca kendi `guide_city`'sindeki mekanı ekleyebilir. Çekirdek mantık tek yerde: `services.CheckCityAllowed` (saf, `NormalizeCity` ile Türkçe-duyarsız karşılaştırma). Preview yanıtına `city_allowed` + `guide_city` eklendi → mobil, farklı şehirde uyarı bandı gösterip detay adımını kilitliyor. `Create` endpoint'inde guide farklı ilde mekan eklerse 403 döner (güvenlik hattı). Admin muaf. Belirsizlikte (guide_city NULL / mekan şehri 81 ilden birine çözülemez) izin verilir → admin onayına kalır. Düzenleme (Edit) kapsam dışı.

| Değişiklik | Durum | Detay |
|-----------|-------|-------|
| Migration 032 | ✅ | guide_applications.city NOT NULL kolonu eklendi + users.guide_city kolonu eklendi |
| Referral kodu tamamen kaldırıldı | ✅ | referral_codes tablosu migration ile silindi; guide_applications.referred_by kolonu kaldırıldı |
| POST /guide/apply tekleştirildi | ✅ | City + terms → admin onay (tek yol); kodsuz başvuru varsayılan akış |
| 81 il validator | ✅ | models.NormalizeCity() + backend kontrolü; mobil aramalı dropdown |
| Admin panelde şehir bilgisi | ✅ | GET /admin/guides/by-city; başvuru listesinde şehir kolonu |
| Demote güvenliği | ✅ | Rehber demote'ta guide_city NULL (tutarsızlık yok) |
| Dev-only cleanup | ✅ | backend/scripts/cleanup_referral_guides.sql (migrations'a gömülmez) |

### Web Admin Paneli (Vue 3 + Vuetify) — YENİ

> 2026-06-12'de eklendi. Mobil uygulamadaki admin ekranları yerine, ayrı bir web tabanlı yönetim paneli. `admin-panel/` klasöründe, caiz_mi Fiber backend'ine (`/api/v1`) bağlanır, mobil ile aynı veritabanını kullanır. Sadece `admin` rolüne açıktır.

| Modül | Durum | Detay |
|-------|-------|-------|
| Template taşıma | ✅ | go-template2 Vue/Vuetify frontend'i admin-panel/ olarak taşındı, Go backend'i atıldı |
| Ortam | ✅ | Node 22 LTS (.nvmrc), pnpm; build:icons/msw prebuild hook'ları kaldırıldı (ESM uyumsuz) |
| Auth & ApiService | ✅ | caiz_mi düz-JSON formatına uyarlandı, `[error, data]` deseni, token refresh |
| Admin guard | ✅ | Login'de `role !== 'admin'` reddedilir; router meta `role: ['admin']` |
| extable (client-side) | ✅ | Liste/CRUD bileşeni client-side pagination/filtre/sıralama yapacak şekilde uyarlandı |
| Dashboard | ✅ | Mekan/bekleyen/kullanıcı/başvuru özet kartları |
| Mekanlar ekranı | ✅ | Liste + onay/red/reaktive/sil/düzenle |
| Bekleyen Mekanlar | ✅ | Hızlı onay kuyruğu |
| Kullanıcılar ekranı | ✅ | Liste + rol/aktiflik düzenle, sil |
| Guide Başvuruları | ✅ | Liste + onay/red |
| Düzeltmeler | ✅ | Liste + onay/red (`{action}` body) |
| Mekan Raporları | ✅ | Liste + çözümle |
| Audit Log | ✅ | Salt-okunur işlem geçmişi |
| Doğrulama Logları | ✅ | Tab'lı görünüm (verified/suspended/upcoming/warnings) + manuel scheduler |

**Çalıştırma:** `cd admin-panel && nvm use 22 && pnpm dev` (→ :5173). Backend `:8080` ayakta olmalı.
**NOT:** Proje kök dizini `caiz_mi?` → `caiz_mi` olarak yeniden adlandırıldı (`?` Vite/esbuild'i bozuyordu).

### Backend (Go + Fiber)

| Modül | Durum | Detay |
|-------|-------|-------|
| Proje yapısı (cmd/internal/pkg) | ✅ | Clean architecture: handler → service → repository |
| PostgreSQL + PostGIS bağlantısı | ✅ | Connection pool, docker-compose ile dev ortamı |
| Veritabanı migration sistemi | ✅ | 19 migration dosyası, golang-migrate |
| Kullanıcı modeli & repo | ✅ | Traveler/Guide/Admin rolleri |
| JWT Authentication | ✅ | Access + Refresh token, token yenileme |
| Email/Şifre kayıt & giriş | ✅ | bcrypt hash, validation |
| Google OAuth | ✅ | google sign-in entegrasyonu |
| Apple Sign-In | ✅ | apple_service.go ile doğrulama |
| RBAC Middleware | ✅ | Rol bazlı erişim kontrolü |
| Rate Limiting | ✅ | Guide mekan ekleme limiti |
| Venue CRUD | ✅ | Ekleme, güncelleme, silme (soft delete) |
| PostGIS konum sorguları | ✅ | ST_DWithin ile yakın mekan arama, GIST index |
| Şehir bazlı arama | ✅ | City indexli sorgular |
| Venue fotoğraf yükleme | ✅ | Multipart upload, local storage |
| Helal kriterleri | ✅ | Kişisel Deneyim, Helal Sertifikası |
| Yemek kategorileri | ✅ | 14 kategori + 50+ yemek öğesi, seed data |
| Review sistemi (CRUD) | ✅ | 1-5 yıldız, yorum, ortalama hesaplama |
| Favoriler | ✅ | Ekleme/çıkarma, listeleme |
| Guide başvuru sistemi | ✅ | Başvuru → Admin onay akışı |
| Düzeltme önerileri | ✅ | Alan bazlı düzeltme, admin review |
| Admin endpointleri | ✅ | Onay/red, kullanıcı yönetimi |
| Audit log | ✅ | Tüm admin işlemleri kayıt altında |
| Çift doğrulama (double-verified) | ✅ | venue_confirmations tablosu |
| Google Place ID entegrasyonu | ✅ | PlacesService, venue modeline google_place_id eklendi, harita launcher'larına iletildi |
| Kategori bazlı mekan arama | ✅ | FindByFoodCategory sorgusu + /venues/by-category/:id endpoint'i |
| Referral code sistemi | ✅ | ReferralRepo, 5-karakter benzersiz kod üretimi, guide başvurusu referred_by alanı |

### Mobil Uygulama (Flutter)

| Modül | Durum | Detay |
|-------|-------|-------|
| Proje yapısı (feature-based) | ✅ | core/ + features/ + shared/ |
| Riverpod state management | ✅ | v3.2.1 + code generation |
| GoRouter navigasyon | ✅ | Rol bazlı korumalı rotalar |
| Dio HTTP client | ✅ | Auth interceptor, token refresh |
| Freezed data modelleri | ✅ | User, Venue, Review, vb. |
| Login ekranı | ✅ | Email/şifre + Google + Apple butonları |
| Kayıt ekranı | ✅ | Email/şifre kayıt formu |
| Harita ekranı | ✅ | Google Maps, renkli pinler (yeşil/sarı) |
| Venue bottom sheet | ✅ | Haritada mekan seçince hızlı bilgi |
| Venue detay ekranı | ✅ | Fotoğraf galerisi, yorumlar, çalışma saatleri |
| Şehir bazlı arama | ✅ | Arama ekranı + şehir listesi |
| Şehir mekan listesi | ✅ | city_venues_screen |
| Yorum ekleme/düzenleme | ✅ | Bottom sheet form |
| Favoriler ekranı | ✅ | Liste görünümü |
| Guide: Mekan ekleme | ✅ | Multi-step form (konum, bilgi, yemek, fotoğraf) |
| Guide: Mekanlarım | ✅ | Guide'ın eklediği mekanlar listesi |
| Guide: Düzeltme önerme | ✅ | correction_screen |
| Admin dashboard | ✅ | İstatistik kartları |
| Admin: Bekleyen mekanlar | ✅ | Onay/red ekranı |
| Admin: Guide başvuruları | ✅ | Başvuru listesi + işlem |
| Admin: Düzeltmeler | ✅ | Düzeltme önerileri listesi |
| Admin: Audit log | ✅ | İşlem geçmişi |
| Admin: Kullanıcılar | ✅ | Kullanıcı yönetim ekranı |
| Admin: Tüm mekanlar | ✅ | Mekan listesi (tüm durumlar) |
| Profil ekranı | ✅ | Kullanıcı bilgileri |
| Profil düzenleme | ✅ | edit_profile_screen |
| Konum servisleri | ✅ | GPS, geolocator, 5dk cache |
| Harita yönlendirme | ✅ | map_launcher (Google/Apple Maps), googlePlaceId ile resmi profil açılımı |
| Güvenli token depolama | ✅ | flutter_secure_storage |
| Food Discovery ekranı | ✅ | Yemek kategorisine göre yakın mekan keşfi, alt nav "Ne Yesem?" sekmesi |
| Yemek seçimi (tüm modlar) | ✅ | Yemek kategorileri artık sadece 'selected' değil tüm helal modlarda gösterilir |
| Mekan ekleme konum UX | ✅ | Harita seçici artık Google Maps linki yoksa son çare olarak sunuluyor |

### Veritabanı

| Tablo | Durum |
|-------|-------|
| users | ✅ |
| venues (+ PostGIS) | ✅ |
| venue_photos | ✅ |
| venue_criteria | ✅ |
| venue_food_items | ✅ |
| halal_criteria | ✅ |
| food_categories | ✅ |
| food_items | ✅ |
| reviews | ✅ |
| favorites | ✅ |
| guide_applications | ✅ |
| correction_suggestions | ✅ |
| audit_logs | ✅ |
| venue_confirmations | ✅ |
| referral_codes | ✅ |
| venues.google_place_id | ✅ |
| guide_applications.referred_by | ✅ |

---

## Prod'a Hazırlık Yol Haritası

> **Denetim notu (2026-07-21):** Bu bölüm kod tabanı baştan taranarak yeniden yazıldı. Önceki
> liste bayatlamıştı — "sadece auth_handler_test.go var" diyordu ama 18 backend test dosyası
> mevcuttu; venue confirmation ve email bildirimleri de tamamlanmış olduğu hâlde açık duruyordu.
> Aşağıdaki her madde **kod okunarak doğrulandı**, tahmine dayalı madde yok.
>
> Ölçüm anı: `main` @ 9a66869 — backend 10.097 satır / 73 dosya, mobil 18.860 satır / 92 dosya.

### 🔵 Üretim Dayanıklılığı Denetimi — 8 Konu (2026-07-25)

Soru: "yazdığımız testler yeterli mi — 422 / 409 / race / duplicate / retry / partial
failure / eventual consistency / cache invalidation?" **Ayrım:** yazdığımız testler birim/
regresyon testi; bu 8 konu ise önce **kodda** doğru ele alınması gereken davranışlar.
Aşağıdaki her satır kod okunarak doğrulandı.

| Konu | Kod durumu | Test | Risk |
|------|-----------|:----:|:----:|
| **422/400 validation** | 400 ağırlıklı (`review_handler.go:56` puan 1-5 vb.); mobilde `api_error.dart:15` 422 handler'ı | ✅ handler | Düşük |
| **409 Conflict** | **Atomik** — DB `UNIQUE` + violation yakalama, check-then-insert değil (`review_handler.go:66`, `migrations/006 UNIQUE(venue_id,user_id)`). 6 uçta | ✅ handler | Düşük |
| **Race condition** | 409'lar DB constraint'le race-safe; admin/onay transaction'lı (`venue_status_repo.go:152 Begin/defer Rollback/Commit`); mobil `_isRefreshing` flag'i eşzamanlı refresh'i engeller | ⚠️ **eşzamanlılık testi yok** | Orta-düşük |
| **Duplicate request** | `ON CONFLICT DO NOTHING` (`favorite_repo.go:45`, `login_repo.go:26`, `venue_criteria/food`); review `UNIQUE`. DB seviyesi idempotent | Kısmi | Düşük |
| **Retry** | 🔴 Backend'de **yok**; mobilde yalnız 401→token-refresh tek tekrar (`api_client.go:102`), genel transient (503/timeout) retry yok | Yok | **Orta** |
| **Partial failure** | Transaction'lar (`guide_repo.go:123`, `venue_status_repo.go`) `defer Rollback` ile atomik; "rehber onayını atomik yap" commit'i düzeltti | ⚠️ rollback testi yok (gerçek DB gerekir) | Düşük |
| **Eventual consistency** | Tek Postgres, senkron — dağıtık veri yok → **uygulanamaz** (S3 yalnız medya) | — | Yok |
| **Cache invalidation** | Mobil `VenuesNotifier` 5dk+500m cache (test edildi); backend HTTP cache header yok; `foodCategoriesProvider` invalidate | ✅ client-side | Düşük |

**Sonuç:** 8 konudan **5'i kodda zaten korunuyor** (409/race/duplicate/partial-failure/cache)
— doğru araçla: DB constraint + transaction + `ON CONFLICT`. Bunlar "test eksik" değil,
"zaten doğru" kategorisi. **Gerçek boşluklar 2 — ikisi de DEPLOY SONRASINA ertelendi
(2026-07-25 kararı):** kritik veri bütünlüğü yolları (409/transaction) zaten sağlam olduğu
için MVP'yi bloke etmiyorlar; gerçek trafikle önceliklendirmek daha isabetli.
- [ ] 🔴 **Retry mekanizması** *(deploy sonrası)* — geçici hata (503/timeout) yeniden
      denenmiyor (backend + mobil genel retry). Deploy sonrası hissedilir, MVP'de kabul edilebilir.
- [ ] ⚠️ **Eşzamanlılık kanıtı** *(deploy sonrası)* — 409/duplicate yolları race-safe
      *görünüyor* ama paralel istekle davranışı gösteren entegrasyon testi yok.
- [ ] Backend HTTP cache header'ları (perf, ayrı madde — aşağıda mevcut).

### ✅ Denetimde Sağlam Çıkanlar (yeniden yapılmasına gerek YOK)

| Alan | Bulgu |
|------|-------|
| SQL injection | 133 sorgunun tamamı parametreli; `fmt.Sprintf` ile kurulan SQL **yok** |
| Secret sızıntısı | `backend/.env` gitignore'lı, git geçmişinde de yok |
| Yetkilendirme | Admin/guide uçlarında `RequireRole` istisnasız uygulanmış |
| Dosya yükleme | Uzantı whitelist + UUID isim + 10 MB `BodyLimit` (main.go:79) |
| Path traversal | `StorageService.Delete` → `filepath.Base` ile korumalı |
| Şifre | bcrypt `DefaultCost` |
| Migration | golang-migrate, `embed` ile gömülü |
| Hata formatı | %99 tutarlı (121 `error` anahtarı, 1 sapma) |
| Mevcut middleware | `recover` + CORS + rate limiter kurulu |

**Test envanteri (gerçek durum):** backend 18 test dosyası, mobil 9 test dosyası — hepsi PASS.

---

### 🟣 Faz A — Android Platform Paritesi (~yarım gün) `[ ]`

> **Neden en başta:** Uygulama bugüne kadar **Android'de hiç çalıştırılmamış.** Kanıt:
> `flutter doctor` → Xcode ✓ / Android toolchain ✗ (cmdline-tools yok), ve AndroidManifest'te
> **0 adet `uses-permission`** varken Info.plist'te konum izinleri tanımlı. Yani iOS yapılandırılmış,
> Android'e hiç dokunulmamış. Bu sapma her geçen ay büyür — şimdi 4 madde, sonra çok daha fazla.
>
> **Not:** Bunların hepsi *yapılandırma dosyası düzenlemesi*, Android programlama değil.
> Android Studio IDE olarak öğrenilmek zorunda değil — sadece SDK Manager + Device Manager
> (emülatör) için kurulur, kod yazımı mevcut editörde sürer.

**Durum (2026-07-21): SDK kuruldu, kod maddeleri GERÇEK BUILD ile doğrulandı.**
Kalan tek engel: `google-services.json` (Firebase Console erişimi gerekiyor).

Doğrulama kanıtları:
- `flutter doctor` → **tüm satırlar ✓, "No issues found!"**
- `flutter analyze` 26 issue = stash'li baseline ile **birebir aynı** (sıfır yeni)
- `flutter test` **61/61 PASS**
- `./gradlew :app:processDebugMainManifest` **BAŞARILI** → birleşmiş debug manifest'te
  `INTERNET`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `usesCleartextTraffic="true"`,
  `scheme="https"` **hepsi doğrulandı**
- `./gradlew :app:processReleaseMainManifest` **BAŞARILI** → release manifest'te
  `usesCleartextTraffic` **YOK** (amaçlanan: prod HTTPS'e mecbur), `INTERNET` **VAR**
- `build.gradle.kts` configuration fazı geçti → signing config sözdizimi geçerli

**EMÜLATÖRDE ÇALIŞTIRILDI ve doğrulandı (2026-07-21):**
AVD `caizmi_test` (Pixel 7, Android 15, `google_apis_playstore/arm64-v8a`, Play Services şart —
`default` image'da Google girişi ve Haritalar çalışmaz). APK kuruldu, uygulama açıldı, çökme yok.
- **Giriş ekranı render oluyor** (logo, e-posta/şifre, Sign In, Google/Apple butonları)
- **Google hesap seçici açıldı** ("Choose an account to continue to İtimat") → Play Services OAuth
  client'ı çözümledi. SHA-1 yanlış/eksik olsaydı `DEVELOPER_ERROR` (kod 10) alınırdı.
- **Ağ erişimi kanıtlandı** (emülatör içinden `toybox nc` ile):
  | Adres | Sonuç |
  |---|---|
  | `10.0.2.2:3000` | ✅ `{"status":"ok"}` — API çalışıyor |
  | `localhost:3000` | ❌ **Connection refused** — düzeltme şarttı, kanıtlandı |
  | `192.168.1.5:3000` | ✅ fotoğraf HTTP 200, `image/jpeg`, 56 KB |

Not (Android'e özel değil): uygulama içi metinler İngilizce ("Email Address", "Sign In",
"Forgot Password?") ama splash Türkçe ("Güvenilir & Helal Restoran Rehberi"). iOS'ta da aynı —
lokalizasyon tutarsızlığı, ayrı ele alınmalı.

SDK kurulum notları (bu oturumda yapıldı):
- Android Studio sihirbazı `cmdline-tools`'u kurmuyor → Google deposundan 22.0/arm64 indirilip
  `~/Library/Android/sdk/cmdline-tools/latest` altına yerleştirildi
- SDK lisansları kabul edildi (kullanıcı onayıyla)
- Sihirbazın indirdiği `platforms;android-36` **bozuktu** (zip 17 MB'da kesilmiş, klasörde
  yalnızca `.installer` metadata'sı) → Gradle "Archive is not a ZIP archive" ile düşüyordu.
  Kalıntılar temizlenip `sdkmanager` ile yeniden kuruldu (14.198 dosya). Build sırasında
  `platforms;android-34` de otomatik kuruldu.

- [x] **Android SDK kurulumu** — Android Studio (3.2 GB) + SDK 36.0.0 + cmdline-tools 22.0 +
      lisanslar. `flutter doctor` **tamamen yeşil**. Detaylar yukarıdaki kurulum notlarında.

      Debug keystore SHA-1 (Firebase Console'a girilecek — gizli değil, sertifika parmak izi):
      `11:87:C1:D4:9C:BF:37:B8:37:50:CD:80:20:2C:F4:81:01:8E:03:F9`

- [x] **API base URL emülatör uyumu** — `api_endpoints.dart`
      `http://localhost:3000` sabitti. Android emülatöründe `localhost` = **emülatörün kendisi**,
      host makine değil. iOS simülatörü host'u paylaştığı için bu bug bugüne kadar görünmedi.
      → `defaultTargetPlatform` ile platform bazlı seçim (Android `10.0.2.2`), üstüne
      `--dart-define=API_BASE_URL=...` ile ezme imkânı (fiziksel cihaz + Faz 2 prod URL'i için).
      `dart:io` yerine `foundation` kullanıldı; proje `web/` de içerdiği için web build bozulmasın.

- [x] **Cleartext HTTP izni** — `usesCleartextTraffic` **sadece debug manifest'ine** eklendi.
      Android 9+ `http://` isteklerini varsayılan engeller → dev'de tüm API çağrıları düşerdi.
      Bilinçli olarak main manifest'e KONMADI: release build böylece HTTPS'e mecbur kalır.

- [x] **Konum izinleri** — `ACCESS_FINE_LOCATION` + `ACCESS_COARSE_LOCATION` eklendi.
      `geolocator` izinsiz çökmez, sessizce boş döner → teşhisi zor, harita uygulaması için ölümcül.

- [x] **`INTERNET` izni** 🔴 *denetim sırasında çıkan YENİ bulgu*
      İzin yalnızca `src/debug/AndroidManifest.xml` içindeydi (Flutter şablonunun varsayılanı).
      Debug build'ler çalışırdı ama **release APK'nın hiç ağ erişimi olmazdı** — uygulama Play
      Store'da tamamen kırık çıkardı. Ana manifest'e eklendi.

- [x] **`url_launcher` paket görünürlüğü** 🔴 *denetim sırasında çıkan YENİ bulgu*
      `map_launcher.dart:27,51` `canLaunchUrl()` kullanıyor. Android 11+ paket görünürlüğü
      nedeniyle `<queries>` tanımı olmadan bu **false** döner ve fonksiyonun `else` dalı olmadığı
      için **yol tarifi butonu sessizce ölür**. `https` VIEW intent'i `<queries>`'e eklendi.

- [x] **`google-services.json` paket adı uyuşmazlığı** 🔴 *YENİ bulgu — build'i sert durdurdu*
      `google-services.json` → `com.caizmi`, uygulama `applicationId` → `com.caizmi.caiz_mi`.
      `com.google.gms.google-services` eklentisi bu uyuşmazlıkta build'i **hata ile durdurur**
      ("No matching client found for package name"). İlk `flutter build apk` burada düşer.
      Aynı uyuşmazlık iOS'ta da var (`GoogleService-Info.plist` = `com.caizmi`, gerçek bundle =
      `com.caizmi.caizMi`) ama Firebase hiç başlatılmadığı için bugün sorun çıkarmıyor.
      **GERÇEK BUILD İLE DOĞRULANDI (2026-07-21):**
      `Execution failed for task ':app:processDebugGoogleServices'.`
      `> No matching client found for package name 'com.caizmi.caiz_mi'`
      Build'in şu an takıldığı **tek** nokta burası; öncesindeki her aşama geçiyor.
      **Karar:** Firebase ileride **FCM push bildirimi** için kullanılacak → eklenti KALIYOR,
      `google-services.json` doğru paket adıyla yeniden üretilecek. (Eklentiyi kaldırma seçeneği
      değerlendirildi ve elendi: FCM gelince geri eklenmesi gerekirdi.)

- [x] **Google Sign-In SHA-1 kaydı** ✅ *2026-07-21 tamamlandı*
      `google-services.json` içinde **yalnızca web (type 3) OAuth client var, Android (type 1)
      client YOK** → SHA-1 hiç kaydedilmemiş, Android'de Google ile giriş çalışmaz.
      Debug SHA-1 çıkarıldı (aşağıda). **Release keystore farklı SHA-1 üretir — o da eklenecek.**
      Firebase Console'da Android uygulaması eklerken paket adı + SHA-1 aynı ekranda giriliyor →
      yukarıdaki uyuşmazlık ile birlikte tek oturumda çözülür.
      Not: backend `GOOGLE_CLIENT_ID` ile mobil web client **eşleşiyor** ✓ (token audience doğru).
      **SONUÇ (doğrulandı):** `com.caizmi.caiz_mi` altında `client_type: 1` (ANDROID) kaydı oluştu,
      `certificate_hash` = debug SHA-1 ile birebir aynı. Üretilen APK içinde
      `default_web_client_id` = backend'in `GOOGLE_CLIENT_ID`'si → auth zinciri uçtan uca tutarlı.
      `gcm_defaultSenderId` de yerinde (ileride FCM için hazır).
      **Kalan:** release keystore üretilince onun SHA-1'i de Console'a eklenecek.

- [x] **Release signing altyapısı** — `build.gradle.kts`
      `signingConfigs.getByName("debug")` sabitti. Artık `android/key.properties`'ten okuyor;
      dosya yoksa debug'a düşüyor → keystore'u olmayan geliştirici/CI ortamları kırılmıyor.
      `.gitignore`'a `key.properties`, `*.jks`, `*.keystore` eklendi (parola sızıntısı riski vardı).
      **Kalan:** keystore'un kendisi üretilmedi — parolayı sahibi seçmeli ve yedeklemeli;
      *keystore kaybı = uygulama Play Store'da bir daha asla güncellenemez.*

### 🔴 Faz 0 — Sessiz Katiller — ✅ KOD MADDELERİ TAMAMLANDI (2026-07-21)

**Doğrulama:** `go build` + `go vet` temiz, 6 birim paketi PASS, 23 repository integration
testi (testcontainers, gerçek Postgres) PASS, graceful shutdown ayrı portta gerçek SIGTERM
ile sınandı. Kalan tek madde Maps anahtarı (hesap erişimi gerekiyor, aşağıda).

Dördü de küçük, bağımsız ve **prod öncesi zorunlu**. Ortak özellikleri: hata vermeden çalışıp
sessizce zarar vermeleri.

- [x] **JWT_SECRET fail-fast** — `config.go:39`
  `os.Getenv("JWT_SECRET")` doğrudan atanıyor, validation yok. Env unutulursa secret **boş string**
  olur; HS256 boş anahtarla sorunsuz imzalar ve doğrular. Uygulama normal açılır, hata vermez, ama
  **herkes istediği kullanıcı adına token üretebilir.** Sessizliği en tehlikeli yanı.
  → Boş/kısa secret'ta startup'ta `log.Fatal`.

- [x] **SSRF host allowlist** — `venue_handler.go:495` → `storage_service.go:59`
  Kullanıcıdan gelen `GooglePhotoURL`, host doğrulaması olmadan fetch ediliyor. Saldırgan
  `http://169.254.169.254/latest/meta-data/` verirse sunucu cloud metadata servisine gider →
  credential sızıntısı. Local'de zararsız, **cloud'a çıkar çıkmaz aktif.**
  → Şema (`https`) + host allowlist (`*.googleusercontent.com`), redirect takibini sınırla.

- [x] **Graceful shutdown** — `main.go` (son satır)
  `log.Fatal(app.Listen(...))`. Deploy/restart'ta uçuşan istekler ortadan kesilir, yarım DB
  transaction'ları kalır. Her deploy'da veri tutarsızlığı kumarı.
  → SIGTERM/SIGINT yakala, `app.ShutdownWithTimeout`, scheduler ctx'ini iptal et.

- [x] **DB pool limitleri** — `db.go:10`
  `pgxpool.New` tamamen varsayılan; `MaxConns`, connection/idle timeout, health check yok.
  Yük altında bağlantı tükenmesi ve zincirleme timeout.

- [ ] **Google Maps API key — anahtar bölme (deploy öncesi son adım)** 🔴 ⚠️ *hesap erişimi*

  **GÜNCELLEME (2026-07-25 denetimi):** İlk madde (2026-07-21) kısmen eskidi. Faz 3
  fotoğraf proxy'si tamamlandığından **fotoğraf sızıntısı çözüldü** — `BuildPhotoURL` artık
  `PhotoProxyPath` (`/api/v1/places/photo`) döndürüyor, Places anahtarı fotoğraf yoluyla
  istemciye gitmiyor. Backend anahtarı da env'den geliyor (`config.go:70 GOOGLE_MAPS_API_KEY`),
  kaynakta hardcoded değil.

  **Kalan gerçek durum — tek anahtar iki katmanda:**
  - Mobil binary'de gömülü (Maps SDK / harita render): `AndroidManifest.xml:42`,
    `AppDelegate.swift:12` — **ikisi de aynı anahtar** (`...mE3yQk`), muhtemelen backend'in
    Places anahtarıyla da aynı.
  - `build/` git-ignore'lu, `google-services.json` git'te değil → **repoda sızıntı yok**,
    yalnız dağıtılan binary'de (ki SDK anahtarı doğası gereği binary'de olur).

  **Neden ertelendi (hâlâ geçerli):** SDK anahtarını paket adı + SHA-1 (Android) / bundle ID
  (iOS) ile kısıtlamak ancak **gerçek release imza anahtarı ve bundle ID belli olunca** doğru
  yapılır. Şimdi debug SHA-1'e kısıtlanırsa release build'de harita kırılır. Fotoğraf/Places
  sızıntısı zaten kapalı olduğundan acil değil.

  **Checklist (çoğu Google Cloud Console'da, kod değil):**
  - [x] **Fatura koruma (2026-07-25):** Cloud Console'da aylık bütçe uyarısı kuruldu
        (₺10, "Alerts only", tüm projeler). Beklenmedik kullanımda mail gelir. *Not: bu
        uyarıdır, otomatik kesme değil.*
  - [ ] **Deploy'da:** Mobil için **ayrı** Maps SDK anahtarı üret; Android'i release paket+SHA-1,
        iOS'u bundle ID ile kısıtla. Binary'deki anahtarı bununla değiştir.
  - [ ] **Deploy'da:** Backend Places için **ayrı** sunucu anahtarı; artık fotoğraf proxy'de
        olduğu için bu anahtar istemciye hiç gitmiyor → IP kısıtlaması uygulanabilir.
  - [ ] Firebase anahtarı (`google-services.json`, `project_id: caizmi-e078b`) ayrı bir
        anahtar; Maps SDK anahtarıyla karıştırma — Firebase Console'dan yönetilir.

### 🟠 Faz 1 — Güvenlik Ağı: Test Kapsamı — ✅ KRİTİK YOLLAR TAMAMLANDI (2026-07-22)

| Paket | Başlangıç | Şimdi |
|-------|:---------:|:-----:|
| `models` | %100 | %100 ✅ |
| `pkg/jwt` | — | **%85.7** ✅ |
| `middleware` | %63.8 | %63.8 ✅ |
| `handlers` | **%6.4** 🔴 | **%39.4** 🔶 |
| `services` | **%14.3** ⚠️ | **%54.3** ✅ |

Tüm testler `-race` altında da temiz.

> **2026-07-23 güncellemesi:** `services` kapsamı sosyal giriş + PlacesService testleriyle
> **%29.7 → %54.3**'e çıktı (%50 hedefi aşıldı). Detay aşağıda "Faz 1.1" bölümünde.

**Yaklaşım kararı:** Handler'lar somut `*repository.X` tiplerine bağlı olduğu için fake
verilemiyordu. Projenin mevcut kalıbı (`guideCityGetter`, `NotificationStore`,
`AuthServiceInterface`) izlenerek tüketici tarafında **dar arayüzler** tanımlandı.
Go'nun yapısal tiplemesi sayesinde somut repo'lar bu arayüzleri otomatik karşılıyor —
`main.go` ve constructor çağrıları hiç değişmedi.

**Kapsam yüzdesi yerine risk önceliklendirildi.** %50 hedefi bu belgede önerilen bir rakamdı,
iş gereksinimi değil; `ListCities`/`ListCriteria` gibi düz geçiş uçları test edilerek yüzde
kolayca yükseltilebilirdi ama regresyon koruması sağlamazlardı. Bunun yerine yetki, moderasyon
ve kimlik doğrulama yolları hedeflendi:

| Uç | Kapsam |
|----|:------:|
| `auth_handler` (login/kayıt/token/profil) | ~%100 |
| `ApproveApplication` (kullanıcıya guide rolü verir) | %100 |
| `ApproveVenue` | %100 |
| `ConfirmVenue`, `Verify` | %100 |
| `DeleteUser` | %92 |
| `UpdateUser` (demote akışı) | %88 |
| `CheckDuplicate` | %89 |
| `review` / `favorite` / `guide` / `correction` / `report` | %75-100 |

Durum kodlarının ötesinde sabitlenen iş kuralları: şifrenin bcrypt ile hash'lendiği (düz metin
sızmadığı ve hash'in şifreyi doğruladığı ayrıca kontrol edilir), admin'in kendi hesabını
silemediği, rolün başvurudaki kullanıcıya verildiği, reddetmenin rol vermediği, mükerrer
inceleme/başvuru/yorum durumlarının 409 döndüğü, rehber şehrinin repo'ya doğru beslendiği
(beslenmezse şehir kısıtı sessizce devre dışı kalırdı).

- [x] Handler testleri: auth akışı
- [x] Handler testleri: venue onaylama/doğrulama + yetki sınırları
- [x] Handler testleri: admin moderasyon ve kullanıcı yönetimi
- [x] `auth_service` çekirdeği (Register %91, Login %94, RefreshTokens %93, GetUser/UpdateProfile %100)
      — şifre hash'leme, email normalizasyonu, email enumeration koruması, devre dışı hesap
      kontrolü, farklı secret'la imzalanmış token reddi
- [ ] Kalan düşük riskli uçlar (yemek kategorileri, istatistikler, listeler) — %50'ye ulaşmak
      için gerekli, ama regresyon koruması açısından değeri düşük
- [x] `LoginWithGoogle` — `idtoken.Validate` `googleValidator` alanına soyutlandı, sahte
      validator ile test edildi (**%89.3**). *(Aşağıda Faz 1.1)*
- [x] `places_service` — Google host'u `baseURL` alanına çıkarıldı, `httptest.Server` ile
      test edildi (**%86-100** fonksiyon bazında). *(Aşağıda Faz 1.1)*
- [ ] `email_service` (%0, 83 sat.) — SMTP/TLS sarmalayıcısı, soyutlama maliyeti yüksek,
      risk düşük; şimdilik atlandı
- [~] Mobil: 9 → **14 test dosyası, 68 → 150 test**. parser + auth + add_venue wizard +
      home search + **edit_venue** testlerle sabitlendi (Faz 1.2). Kalan: konum-bağımlı
      akışlar (fake `LocationService`/geocoding gerekir → hafif refactor).
- [x] ~~`LoginWithApple`~~ — **Apple girişi tümüyle kaldırıldı** (mobil + backend). Bkz. Faz 1.1

### 🟢 Faz 1.1 — Sosyal Giriş Testleri, Apple Kaldırma ve `is_active` Hatası (2026-07-23)

**1. Apple girişi tümüyle kaldırıldı.** Kullanıcının hatırladığının aksine Apple girişi
`main` dalında hâlâ uçtan uca canlıydı: mobil UI butonları (login/register), `sign_in_with_apple`
paketi, `signInWithApple()`, `/auth/apple` endpoint + handler, `LoginWithApple` servisi,
`apple_service.go` (JWKS doğrulama) ve `keyfunc` bağımlılığı. Hepsi silindi; `go mod tidy`
`keyfunc`'u düşürdü, `flutter pub get` `sign_in_with_apple` + 2 geçişli paketi düşürdü.
*Not: iOS `Podfile.lock` bir sonraki `pod install`'da otomatik temizlenecek.*

**2. 🔴 BULUNAN HATA — yeni Google kullanıcısı ilk girişte kilitleniyordu.** Testler yazılırken
bulundu. `LoginWithGoogle` yeni kullanıcı için `&models.User{...}` kuruyor (`IsActive` set
edilmiyor → `false`), `Create()` çağırıyor ama `Create` yalnızca `id, created_at, updated_at`'i
`RETURNING` ile geri okuyor — DB'deki `is_active DEFAULT true` struct'a yansımıyor. Hemen
sonraki `if !user.IsActive` kontrolü yeni kullanıcıyı **"hesabınız devre dışı bırakılmıştır"**
ile reddediyordu. Yani **ilk kez Google ile giriş yapan herkes kilitleniyordu.** (`Register`
etkilenmiyor — o `IsActive` kontrolü yapmıyor.)
*Çözüm:* Yeni kullanıcı kurulurken `IsActive: true` açıkça verildi (repo katmanına dokunmadan,
DB default'unu yansıtır). Regresyon, "yeni Google kullanıcısı aktif oluşturulmalı" testiyle kilitlendi.

**3. Test edilebilirlik için minimal soyutlama girişleri** (constructor ve `main.go`
değişmeden, projenin dar-arayüz kalıbıyla):
- `AuthService.googleValidator` — varsayılan `idtoken.Validate`; testte sahte payload verir.
- `PlacesService.baseURL` — varsayılan `https://maps.googleapis.com`; testte `httptest.Server`.

**Sabitlenen iş kuralları:** geçersiz token reddi (kullanıcı oluşturulmaz), yeni kullanıcının
`google` provider + token'daki `sub` ile açılması, aynı email'li mevcut hesaba bağlanıp
**mükerrer kayıt açılmaması**, devre dışı hesabın reddi; PlacesService'te **500m mesafe
kabul/red** güvenlik mantığı, en yakın adayın seçimi, TR il/ilçe (`admin_area_level_1/2`)
eşlemesi, locality/sublocality'nin yalnızca boşken devreye girmesi, foto referanslarının 5 ile
sınırlanması, proxy URL'sine **API anahtarının sızmaması**.

| Uç | Kapsam |
|----|:------:|
| `LoginWithGoogle` | %89.3 |
| `ResolvePlaceID` | %86.7 |
| `GetAddressComponents` | %90.0 |
| `BuildPhotoURL` / `BuildPhotoURLs` / `calculateDistance` | %100 |
| `FetchPhoto` | %87.5 |

- [x] `auth_service.go` + `places_service.go` soyutlama girişleri
- [x] Google sosyal giriş testleri (`is_active` hatası düzeltildi)
- [x] PlacesService testleri (`httptest` ile)
- [x] Apple kaldırma (mobil + backend), `go vet` + tüm testler `-race` temiz

### 🟢 Faz 1.2 — Mobil Testler: parser + auth + guide/edit wizard + home search (2026-07-23)

Backend test turu bitince mobil tarafa geçildi. Aynı **risk önceliği** yaklaşımı: saf mantık,
ağsız, en yüksek regresyon değeri. İlk hedef `core/utils/google_maps_parser.dart` — mekan
ekleme akışının kalbi, hiç mock gerektirmiyor.

**Sabitlenen kritik iş kuralları** (21 yeni test):
- **Koordinat format önceliği:** `!8m2!3d/!4d` (pin) `>` `!3d/!4d` `>` `/@` (kamera merkezi).
  En önemli kural — yanlış öncelik mekanı kameranın baktığı yere (yanlış konuma) kaydederdi.
- `place_id` çıkarımı: hem hex (`!1s0x...`) hem `ChIJ` formatları.
- `placeName`: `+`→boşluk, URL-encoded Türkçe karakter decode, **koordinat gibi görünen
  "isim"lerin reddi**.
- Koordinat sınırları (`lat∈[-90,90]`, `lng∈[-180,180]`), negatif yarımküre, `isValidMapsLink`
  host varyantları + normalize.

*Kısa link (`goo.gl`) redirect çözümlemesi ağ gerektirdiği için kapsam dışı bırakıldı; tüm
girdiler tam URL, dolayısıyla `parseLink` redirect'e girmeden çalışıyor.*

Mobil test sayısı: **68 → 89** (10 dosya). Hepsi geçiyor.

**İkinci hedef — `core/auth/auth_provider.dart`** (mocktail: `MockApiClient` +
`MockTokenStorage`, `ProviderContainer` override). 13 yeni test. Sabitlenen iş kuralları:
- **login/register:** başarılı yol token'ları doğru argümanlarla saklar (`saveTokens`
  verify), authenticated'a geçer; **hata yolu token SAKLAMAZ**, `error` set eder,
  authenticated olmaz (regresyon açısından en kritik güvenlik davranışı).
- **`_handleAuthResponse` dalları:** yanıtta `user` objesi varsa `/me` çağrılmaz; yoksa
  `/me`'den çekilir; `/me` hata verse bile token saklandığı için oturum authenticated sayılır.
  *(Backend Google login düzeltmesiyle `user` objesi dönüyor — bu yolun mobil işleyişi artık kilitli.)*
- **`checkAuthStatus`:** token yok→unauthenticated (`/me` çağrılmaz); token+`/me` ok→authenticated;
  token+`/me` hata→**token temizlenir** + unauthenticated (onboarding bilgisi korunur).
- **`logout`** token temizler + state sıfırlar; `markOnboardingSeen`/`updateUser`.

Mobil test sayısı: **89 → 102** (11 dosya). Hepsi geçiyor.

**Üçüncü hedef — `guide_provider` (AddVenueNotifier) + `home_provider` search.** Mekan
ekleme sihirbazının saf state/wizard mantığı (konum/API gerektirmez) + arama akışı.
30 + 6 yeni test. Sabitlenen iş kuralları:
- **Wizard ilerleme kapıları `canProceedStep0..3`:** manuel-mod/koordinat kapısı; adım 1'in
  **`cityAllowed` şehir kısıtı** (diğer her şey dolu olsa da uyumsuz şehirde ilerlenemez —
  rehberin kendi şehri dışına mekan eklemesini engelleyen kural); adım 3'ün **`foodHalalMode`
  dallanması** (`except` modunda yemek VAR ama sakıncalı ürün boşsa geçilemez).
- **Seçim mantığı:** `toggleCriteria`, `toggleFoodItem` (kategori bazlı), `selectAllInCategory`/
  `deselectAllInCategory`, `isCategoryFullySelected` (totalItemCount=0 → false),
  `allSelectedFoodItemIds` (kategorileri düz listede toplar).
- **`setFoodHalalMode` geçişi:** `except`'e girişte boş excluded `['']` ile başlar, `except`
  dışına çıkışta temizlenir, mevcut dolu excluded korunur.
- **Adım navigasyonu:** `nextStep`/`previousStep`/`goToStep` sınırları (0..4'te durma).
- **`home` search:** boş sorgu API çağırmaz + temizler; `{data:[]}` ve düz liste yanıtı
  ikisi de parse edilir; API hatasında sonuçlar temizlenir; `clearSearch`.

Mobil test sayısı: **102 → 136** (13 dosya). Hepsi geçiyor.

**Dördüncü hedef — `EditVenueNotifier` + `MyVenuesNotifier`.** AddVenue'nun aksine konum
bağımlılığı yok (yalnız `apiClient` + saf `GoogleMapsParser`), refactorsuz test edildi.
14 yeni test. Sabitlenenler: `loadVenue` mevcut mekanı state'e map'ler (kriter/yemek ID
düz listeleri, halalMode, excluded) + hata yolu; `parseMapsLink` (boş/geçersiz/geçerli);
`submit` **boş sakıncalı ürünleri filtreler** + başarı/hata; toggle/halalMode geçişi;
`MyVenues` fetch.

**🔴 BULUNAN BUG — `setCoordinates` place_id'yi geçersizleştiremiyor.** Test yazarken bulundu.
`setCoordinates` (guide_provider.dart:656), kod yorumu "koordinat manuel değişince place_id
geçersiz olur" derken `copyWith(googlePlaceId: null)` çağırır — ama `copyWith`'te
`googlePlaceId ?? this.googlePlaceId` null'ı **yok sayar**, eski place_id korunur. Kullanıcı
düzenlemede konumu elle taşırsa **yanlış (eski) `google_place_id` submit'e gider**; backend o
place_id'den adres/foto çekip yanlış mekana bağlayabilir. Aynı hata `AddVenueState.copyWith`'te
de var (satır 105).

**✅ DÜZELTİLDİ (2026-07-23).** Her iki `copyWith`'te `googlePlaceId` parametresi
`Object? = _unset` sentinel'ine çevrildi: `identical(googlePlaceId, _unset)` ile "argüman
verilmedi" (eski değeri koru) ve "null verildi" (temizle) ayrıştırılıyor. `setCoordinates`
artık place_id'yi gerçekten null'lıyor. Add + Edit için regresyon testleri null'lama ve
"argüman verilmeyince koru" yönünü sabitliyor. `parseMapsLink`'in `coords.placeId` ataması
etkilenmez (düz string/null atar).

*Yan bulgu: `loadVenue`'daki `{data:...}` açma dalı ölü kod — backend venue detail'i düz obje
döner (`venue_query_handler.go:141 c.JSON(venue)`), liste uçları gibi sarmalı değil.*

Mobil test sayısı: **136 → 151** (14 dosya, place_id düzeltmesiyle +1). Hepsi geçiyor.

- [x] `google_maps_parser` testleri (koordinat/place_id/placeName/sınır/geçerlilik)
- [x] `auth_provider` (mocktail — login/register/token saklama/logout/checkAuthStatus)
- [x] `guide_provider` (AddVenueNotifier wizard/seçim mantığı) + `home_provider` search
- [x] `edit_venue` (EditVenueNotifier + MyVenues)
- [x] **`copyWith` place_id null-geçişi (sentinel) — DÜZELTİLDİ**
- [x] Konum-bağımlı akışlar: **tamamlandı** (2026-07-25, +17 test).
      - `VenuesNotifier` (+9): `_shouldFetch` cache/mesafe mantığı (ilk fetch / 500m içi cache /
        500m ötesi yeniden fetch / `force`), `fetchNearbyVenues` parse + hata, `fetchCityVenues`.
      - **LocationService refactor** (davranış korundu, 156 test hâlâ yeşil): `getCityFromCoordinates`
        eklendi (3 yerdeki tekrarlanan `placemarkFromCoordinates` deseni tek yere toplandı +
        mock'lanabilir oldu); `locationServiceProvider` `location_service.dart`'a taşındı;
        `home_provider` (4×) ve `venue_filter_provider` `LocationService()` new yerine provider
        kullanıyor; `geocoding` importu provider'lardan kalktı.
      - `home.fetchFeed` (+4): şehir başarılı / geocoding-null → nearby atlanır / konum-reddi
        `locationDenied` / genel hata. `venue_filter.fetchAllCityVenues` (+4): selectedCity varsa
        geocoding atlanır / şehir çözülemezse erken çıkış / konum-reddi.
      - *Kapsam dışı:* `app_header.dart` geocoding (UI widget, provider değil). Mobil test: **156 → 164**.

### 🟢 Faz 1.3 — Ürün kararı: Konum düzenleme akışları sadeleştirildi (2026-07-23)

İki ilişkili ürün kararı, testlerle sabitlendi:

**1. AddVenue — "Linksiz Devam Et" (manuel giriş) kaldırıldı.** Mekan eklemede Google Maps
linki zorunlu oldu; `isManualMode`/`setManualMode` silindi, `canProceedStep0` link'ten
koordinat gerektirir. (feat commit: manuel konum kaldır.)

**2. EditVenue — konum düzenlemesi tamamen kaldırıldı.** *Gerekçe: konum = mekanın kimliği.
Konum değişiyorsa o artık başka bir mekandır → update değil create olmalı; rehber farklı bir
yer kastediyorsa yeni mekan ekler.* Kaldırılanlar: `EditVenueState`'ten
`latitude/longitude/googlePlaceId/mapsLink/isParsingLink`; `EditVenueNotifier`'dan
`setCoordinates`/`parseMapsLink`; `loadVenue` artık konum yüklemez; `submit` konum
göndermez; `edit_venue_screen`'den tüm "Konum" bölümü (link input + "Haritada Seç" +
`FullMapPicker`) ve kaydet-butonu koşulundaki konum kontrolü. **Backend uyumu:** venue update
handler'ı konum alanlarını `*float64` (opsiyonel) kabul eder; gönderilmeyince mevcut konumu
korur (`venue_write_handler.go:254-260`). Testler: `submit` gövdesinde
`latitude/longitude/google_place_id` OLMADIĞI, `loadVenue`'nun yalnız düzenlenebilir
alanları yüklediği sabitlendi.

*Not: place_id `copyWith` sentinel düzeltmesi hâlâ AddVenue tarafında geçerli ve testli.*

Mobil test sayısı: **151 → 147** (EditVenue konum testleri kaldırıldı). Hepsi geçiyor.

#### 🔴 Faz 1'de ortaya çıkan üç bulgu

**0. GÜVENLİK: access token, refresh token olarak kullanılabiliyordu — DÜZELTİLDİ**
`auth_service` testleri yazılırken bulundu (kod okurken değil). Access ve refresh token'lar
aynı secret ve algoritmayla imzalanıyor, ikisi de `Subject`'e kullanıcı id'si koyuyor ve
birbirinden ayırt edilebilir hiçbir claim taşımıyordu → `ParseRefreshToken` bir access
token'ı sorunsuz kabul ediyordu.

*Etkisi:* Access token her istekte gönderildiği için (log, proxy, hata raporu, tarayıcı
geçmişi) sızma olasılığı yüksek ve ömrü bilinçli olarak **15 dakika**. Sızan bir access
token `/auth/refresh`'e verilerek **30 günlük** taze refresh token'a çevrilebiliyordu —
kısa pencere kalıcı erişime dönüşüyordu.

*Çözüm:* Her iki token'a `typ` claim'i eklendi, iki parse fonksiyonu da tipi doğruluyor.
Refresh token kasıtlı olarak minimal tutuldu (yalnızca `subject` + `typ`): JWT içeriği
okunabilir ve refresh token uzun ömürlü olduğu için email/rol taşınmıyor.

⚠️ **KIRICI:** `typ` taşımayan mevcut token'lar geçersiz olur, kullanıcılar bir kez yeniden
giriş yapar. Uygulama yayında olmadığı için bedeli düşük. Tipsiz eski token'ın reddedildiği
ayrıca test edildi.

**1. Kısmi başarısızlık: guide rolü var ama şehri yok**
`ApproveApplication` içinde `UpdateRole` başarılı olup `SetGuideCity` hata verirse istek yine
**200** döner ve yalnızca log yazılır. Kullanıcı guide olur ama `guide_city` boş kalır.
Bu, şehir kısıtına dayanan tüm akışları etkiler (`ConfirmVenue`, venue `Create`): kısıt boş
şehirde nasıl davranıyorsa öyle davranır. Mevcut davranış testle sabitlendi
(`TestAdminApproveApplicationCityFailureIsTolerated`) — **düzeltilmedi**, çünkü değiştirilmesi
ürün kararı (rol geri alınsın mı? istek 500 mü dönsün? yoksa şehir sonradan mı sorulsun?).

**2. Arayüz refactor'ü "tipli nil" regresyonu üretti (düzeltildi)**
`VenueHandler.notifService` alanı arayüze çevrilince, constructor somut
`*services.NotificationService` alıp bu alana atadığı için nil bir servis **non-nil görünür**
hale geldi; `Verify` içindeki `h.notifService != nil` kontrolü yanlışlıkla geçip panic
üretebilirdi. Constructor'a açık nil kontrolü eklendi ve
`TestNewVenueHandlerNilNotifierStaysNil` ile sabitlendi (mutasyon denemesiyle doğrulandı).
**Ders:** somut pointer alanı arayüze çevirirken, o alanda `!= nil` kontrolü olup olmadığı
mutlaka taranmalı.

#### 🟡 Faz 1'in açığa çıkardığı tasarım borcu — handler'ları böl

Arayüzlerin genişliği bir semptom:

| Handler | Satır | Endpoint | Arayüz yüzeyi |
|---------|:-----:|:--------:|---------------|
| `venue_handler` | 888 | 20 | `venueStore` **29 metot** |
| `admin_handler` | 1015 | 35 | 4 ayrı arayüz, ~60 metot |

`venue_handler` mekan CRUD + fotoğraf + kriter + yemek kalemi + onaylama + doğrulama işlerini,
`admin_handler` ise moderasyon + rehber başvuruları + kullanıcı yönetimi + istatistikler +
yemek kategorilerini birlikte taşıyor.

- [ ] `venue_handler`'ı mantıksal parçalara böl (CRUD / fotoğraf / kriter+yemek / doğrulama-onay)
- [ ] `admin_handler`'ı böl (moderasyon / kullanıcı yönetimi / istatistik / katalog)

**Sıralama notu:** Bu bölme işi bilinçli olarak Faz 1'den SONRAYA bırakıldı. Refactor'ü testsiz
yapmak ters sıra olurdu; artık güvenlik ağı kurulduğu için bölme güvenle yapılabilir.
Arayüzler bölünmeden sonra doğal olarak küçük parçalara ayrılmalı.

### 🟠 Faz 2 — Prod Altyapısı — 🔶 ÇEKİRDEK TAMAMLANDI (2026-07-22)

- [x] **CI pipeline** (`.github/workflows/ci.yml`) — backend (build, vet, birim testleri
      `-race`, integration testleri) + mobil (analyze, test). `go.mod`/`go.sum` güncelliği
      de kontrol ediliyor; aynı dala arka arkaya push'ta eski koşu iptal ediliyor.

      *Yerelde önden denendi ve iyi olmuş:* `go mod tidy` değişiklik üretiyordu —
      `testcontainers-go` `// indirect` işaretliydi ama integration testleri onu doğrudan
      import ediyor. Düzeltilmiş `go.mod`/`go.sum` commit'lendi, aksi halde CI ilk koşuda
      kırılacaktı.

      ⚠️ `flutter analyze` mevcut 25 deprecation (info) yüzünden çıkış kodu 1 veriyordu.
      `--no-fatal-infos` kullanıldı: **yeni** warning/error build'i kırar, eski info'lar
      kırmaz. Tek gerçek warning (kullanılmayan `_fakeLocationProvider`) silindi.
      **Bu bayrak, deprecation'lar giderilince kaldırılmalı.**

- [x] **Multi-stage Dockerfile** — CGO kapalı statik binary, **71 MB** alpine imaj, root
      olmayan kullanıcı (uid 10001), `ca-certificates` (Google API çağrıları) + `tzdata`
      (scheduler yerel saate bağlı). Migration'lar `go:embed` ile gömülü olduğundan ayrıca
      kopyalanmıyor. `.dockerignore` ile `.env` ve `uploads/` imaja sızmıyor.
      *Doğrulama:* imaj derlendi, gerçek DB'ye karşı çalıştırıldı, istek karşıladı.

- [x] **Readiness probe ayrımı**
      `/health` (liveness) bilerek **DB'ye dokunmaz** — DB kontrolü buraya konsaydı geçici
      bir kesintide orkestratör sağlıklı container'ları yeniden başlatır ve durumu
      kötüleştirirdi. `/ready` (readiness) DB'yi 2 sn timeout'la ping'ler, başarısızsa
      **503** döner → orkestratör yeniden başlatmak yerine yük dengeleyiciden çıkarır.
      *Doğrulama:* gerçek DB durduruldu → `/ready` 503, `/health` 200; DB dönünce `/ready`
      tekrar 200.

- [x] **Yapılandırılmış loglama** (`internal/logging`, %100 kapsam)
      `slog.SetDefault` stdlib `log` paketini de yönlendirdiği için koddaki **43 mevcut
      `log.Printf` çağrısı tek satır değiştirilmeden** JSON'a döndü. `LOG_FORMAT`
      (json|text) ve `LOG_LEVEL` env'den; tanınmayan seviye info'ya düşer ki yanlış
      yazılmış bir değer logları tamamen susturmasın. HTTP erişim logları da aynı JSON
      şemasına alındı (fiberlogger'ın varsayılan metin formatı yapılandırılmış çıktıyı
      bozuyordu).

- [x] **`.env.example` tamamlandı** — config'deki 18 değişkenin tamamı, her birinin ne işe
      yaradığı ve tuzakları (`STORAGE_URL`'in DB'ye gömülmesi, `WARNING_DAYS`'in mobil
      sabitle eşleşme zorunluluğu, SMTP boşsa e-postanın sessizce devre dışı kalması).

**Kalan (dış bağımlılık gerektiriyor — hosting kararı verilmeden yapılamaz):**
- [ ] Prod secret yönetimi (env injection, `.env` dosyası değil)
- [ ] SSL/TLS + HTTPS yapılandırması
- [ ] DB backup stratejisi
- [ ] Monitoring + alerting
- [ ] Uygulama container'ı için `docker-compose` servisi (şu an yalnızca `db` var)

⚠️ **CI henüz GitHub'da koşmadı.** YAML ve adımlar yerelde doğrulandı, ama runner
ortamında (Flutter kurulumu, testcontainers) sürpriz çıkabilir. İlk push'ta izlenmeli.

#### ⚠️ Faz 2'de fark edilen veri sorunu — mevcut mekanlar askıya alınmış

Docker imajı gerçek DB'ye karşı denenirken çıktı: **üç mekanın da durumu `suspended`.**

```
Tarihi Erzurum Kebapçısı | suspended | verification_due_at 2026-07-13
Döneristanbul Fatih      | suspended | verification_due_at 2026-07-13
Esenler döner            | suspended | verification_due_at 2026-07-13
```

Sebep: `VERIFICATION_PERIOD_DAYS` 2 → 180 değişikliği **mevcut satırları geriye dönük
güncellemiyor.** Bu kayıtların `verification_due_at` değeri eski 2 günlük periyoda göre
hesaplanmıştı, 13 Temmuz'da doldu ve scheduler hepsini askıya aldı. Mekanlar artık
listelerde görünmüyor (`/venues/nearby` → `count: 0`).

Config değişikliği yapılırken bu öngörülmedi; yalnızca yeni kayıtlar düşünülmüştü.

- [ ] **Karar gerekiyor:** askıdaki test mekanları canlandırılsın mı?
      Tek `UPDATE` ile `verification_due_at` yeni periyoda göre ileri taşınıp `status`
      `approved`'a döndürülebilir. Ancak bu, "askıya alma" iş kuralını elle ezmek demek —
      bilinçli bir karar olmalı. Prod'da benzer bir periyot değişikliği yapılırsa aynı
      durum gerçek verilerde oluşur; **periyot değişikliği yanına bir veri migrasyonu
      düşünülmeli.**

### 🟠 Faz 3 — S3 Depolama & Fotoğraf Proxy — ✅ TAMAMLANDI (2026-07-22/23)

- [x] **Göreli yol sakla (mimari borç)** — `migration 039`
      Fotoğraf ve kategori görselleri artık DB'ye TAM URL değil dosya ANAHTARI olarak yazılıyor;
      tam URL okuma anında `StorageService.PublicURL` ile üretiliyor. Bu borcun bedeli oturum
      içinde zaten iki kez görülmüştü: emülatör için `localhost → LAN IP` değişiminde
      `venue_photos` elle güncellendi ve o sırada **`food_categories` gözden kaçtı** (14 kategori
      görseli localhost'ta kaldı). Migration 039 her iki tabloyu da (17 kayıt) düzeltti.
      `PublicURL` geriye dönük uyumlu: `http(s)://` ile başlayan eski değerler olduğu gibi döner.
      **ASIL KAZANÇ İSPATLANDI:** aynı veri, DB'ye hiç dokunulmadan `STORAGE_URL=https://cdn...`
      ile çalıştırıldığında URL'ler yeni adrese göre üretildi → ortam değişikliği artık veri
      migrasyonu gerektirmiyor. `down` migration bilinçli no-op (atılan ön ek DB'de saklanmıyor).

- [x] **S3/MinIO entegrasyonu** — `BlobStore` arayüzü + `localBlobStore` + `s3BlobStore`
      Uzantı doğrulama, anahtar üretimi ve SSRF koruması arka uçtan bağımsız politikalar olarak
      `StorageService`'te kaldı; `BlobStore` yalnızca baytların nereye yazıldığını soyutluyor.
      Kütüphane: `minio-go` (aws-sdk-go-v2 yerine) — S3 API standart olduğu için aynı kod AWS S3,
      Cloudflare R2, DigitalOcean Spaces ve MinIO ile çalışıyor. `S3_ENDPOINT` doluysa S3, boşsa
      yerel disk. Yapılandırma hatalıysa açılışta **fail-fast** (bucket yoksa/kimlik yanlışsa).
      **Doğrulama:** GERÇEK MinIO'ya karşı (testcontainers) yazma/okuma/Content-Type/silme +
      fail-fast; ayrıca uygulama S3 moduyla başlatılıp bucket doğrulamasının geçtiği görüldü.
      *Bilinen sınır:* statik erişim anahtarı kullanıyor; AWS IAM rol tabanlı kimlik gerekirse
      aws-sdk-go-v2'ye geçiş `BlobStore` arkasında kalır.

- [x] **Fotoğraf proxy'si** — Faz 0'dan devreden Maps anahtarı güvenlik borcu KAPANDI
      `BuildPhotoURL` artık Google'a değil kendi ucumuza (`/api/v1/places/photo`) işaret ediyor;
      `PlacePhotoProxy` fotoğrafı sunucu tarafında çekip akıtıyor. **API anahtarı artık istemciye
      hiç gitmiyor → Cloud Console'da IP kısıtlaması uygulanabilir.** Uç guide/admin korumalı
      (kota koruması), genişlik 100-1600'e sıkıştırılmış (kota/bant genişliği koruması),
      `Cache-Control: private, max-age=86400`. Mobil tarafı da uyarlandı (`resolveMediaUrl` +
      `requiresAuthHeader` + Authorization başlığı) — aksi halde önizleme sessizce kırılırdı.
      *Test edilmeyen:* `FetchPhoto`'nun mutlu yolu (Google'dan gerçek görsel) — guide oturumu
      gerektirdiği için uçtan uca sınanmadı; doğrulama dalları ve URL üretimi kapsandı.

- [ ] **Boyutlandırma/sıkıştırma** (thumbnail, medium, full) — YAPILMADI, opsiyonel iyileştirme
- [ ] **CDN** — `S3_PUBLIC_BASE` ile hazır; sağlayıcı seçimi kullanıcıya bağlı

**Faz 0'daki Maps anahtarı maddesinin durumu:** proxy tamamlandığına göre artık şunlar yapılabilir:
Places/sunucu anahtarına Cloud Console'dan **IP kısıtlaması** (proxy sayesinde mümkün) ve
Android/iOS Maps SDK anahtarlarının ayrılıp platform kısıtı. Bunlar hesap erişimi gerektiriyor,
kullanıcıda.

### 🟡 Faz 4 — Store Yayını `[ ]`

- [ ] iOS code signing + provisioning profile
- [ ] Android keystore + signing config
- [ ] App Store Connect / Google Play Console metadata
- [ ] App ikonu + splash screen
- [ ] Privacy policy + terms of service sayfaları
- [ ] Store screenshot'ları

---

### Sonraki Öncelikler (prod sonrası)

**Güvenlik ince ayar** — temel hijyen sağlam, kalanlar iyileştirme:
- [ ] Endpoint bazlı rate limiting fine-tuning (şu an `guideSubmitLimiter` gibi noktasal)
- [ ] Brute-force login koruması
- [ ] Prod domain'leri için CORS daraltma
- [ ] Input validation güçlendirme

**Performans:**
- [ ] Pagination — `limit` var ama offset/cursor yok (`venue_handler.go:80`)
- [ ] N+1 sorgu analizi
- [ ] Image lazy/progressive loading
- [ ] HTTP cache header'ları

**UX** (kısmen mevcut — doğrulandı):
- [x] Pull-to-refresh — 4 ekranda var (home, favorites, my_venues, notifications)
- [x] Empty state — kısmen (`my_venues_screen`)
- [ ] Empty state'i tüm listelere yay
- [ ] Loading skeleton / shimmer — **hiç yok**
- [ ] Dark mode — **hiç yok** (`ThemeMode`/`darkTheme` tanımlı değil)
- [ ] Offline cache, hata ekranı + retry, onboarding

**Eksik iş mantığı:**
- [x] ~~Venue confirmation akışı~~ — tamamlandı (rozet & dönemsel doğrulama özelliği)
- [x] ~~Email bildirimleri~~ — `notification_service` + `scheduler_service` içinde mevcut
- [ ] Guide başvurusu: motivasyon metni + referans mekanizması
- [ ] Admin toplu işlemler (bulk approve/reject)
- [ ] Kullanıcı raporlama sistemi

**v2.0:**
- [ ] Push notification, gelişmiş filtreleme, çoklu dil (EN/AR), sosyal paylaşım,
      kişiselleştirilmiş öneriler, analitik dashboard

---

## Faz Durumu

| Faz | Açıklama | Durum |
|-----|----------|-------|
| Faz 1: Altyapı | Backend, DB, Auth, API | ✅ Tamamlandı fakat düzenleme gerek |
| Faz 2: Mobil Uygulama | Flutter, Harita, UI | ✅ Tamamlandı fakat düzenleme gerek|
| Faz 3: Sosyal Özellikler | Yorum, Favori, Guide | ✅ Tamamlandı fakat düzenleme gerek |
| Faz 4: Admin Paneli | Dashboard, Onay, Audit | ✅ Tamamlandı fakat düzenleme gerek|
| Faz 5: Test & Yayın | Test, Store yayını | 🔶 Devam Ediyor |

**Prod'a hazırlık durumu (2026-07-21 denetimi):**

| Faz | Kapsam | Durum |
|-----|--------|-------|
| Faz A | Android platform paritesi (SDK, izinler, URL, SHA-1, signing) | ✅ **Tamamlandı** — APK build ediliyor. Tek kalan: release keystore (Faz 4) |
| Faz 0 | Sessiz katiller (JWT fail-fast, SSRF, shutdown, DB pool, Maps key) | ✅ Kod maddeleri tamam — Maps anahtarı bölme bekliyor |
| Faz 1 | Test kapsamı (handlers %39.9, services %29.7, jwt %85.7) | ✅ Kritik yollar kapsandı; 1 güvenlik açığı bulunup düzeltildi (JWT tip ayrımı) |
| Faz 2 | Prod altyapı (Docker, CI, logging, readiness) | 🔶 Çekirdek tamam — secret/TLS/backup/monitoring hosting kararına bağlı |
| Faz 3 | S3 depolama + göreli yol + fotoğraf proxy | ✅ Tamamlandı (MinIO ile doğrulandı; Maps anahtarı borcu kapandı) |
| Faz 4 | Store yayını | ⬜ Başlanmadı |

*Her bir madde için detaylı implementasyon planları ayrı MD dosyalarında hazırlanacaktır.*

---

## Güvenilirlik Konumlandırması & Mutfak Sadeleştirmesi (2026-07-26)

Bir dizi ürün kararı `main`'e uygulandı:

| İş | Özet | Durum |
|----|------|-------|
| Sahipsiz doğrulama modeli | Mekan tazeleme `added_by`'dan alınıp "ekleyen VEYA doğrulayan"a açıldı; confirmations silinmez, rozet türetilir; yetim mekan sorunu çözüldü | ✅ |
| `is_double_verified` kaldırıldı | Ölü kolon (hiçbir yerde okunmuyordu); migration 040 | ✅ |
| Gecelik recompute | Scheduler Faz 0: `confirmation_count` bayatlaması düzeltildi (verified_at'e dokunmadan) | ✅ |
| Helal → Güvenilirlik | `halal_criteria`→`trust_criteria` tam rename (DB+backend+mobil+JSON); son kullanıcı kriterleri görmez, sadece güven rozeti + "N rehber güvenilir buldu" cümlesi; "helal"→"güven" dili | ✅ |
| Güven kriterleri genişletildi | 3→7 kriter (alkolsüz, temiz-bakımlı, yerinde görüldü, köklü işletme); admin panelde CRUD sayfası (migration 044-045) | ✅ |
| Tekil yemekler kaldırıldı | `food_items`+`venue_food_items` DROP → `venue_categories` (mekan doğrudan mutfak seçer); `food_halal_mode` 3→2 mod (`selected`→`all`); admin item CRUD kaldırıldı; dil "caiz"→"tavsiye edilen"; migration 046 | ✅ |

**Doğrulama:** Her iş için backend integration (testcontainers, migration zinciri dahil) + mobil `flutter test` (158) + admin-panel build yeşil; JSON kontratları katmanlar arası elle senkron doğrulandı. Spec'ler `docs/superpowers/specs/2026-07-25..26-*` altında (gitignore, diskte).

---

## Venue Detail: Mutfak Sadeleştirme + Güven Kriteri Rozetleri (2026-07-27)

Mekan detay ekranında iki UI iyileştirmesi `main`'e uygulandı (lokal, henüz push edilmedi):

| İş | Özet | Durum |
|----|------|-------|
| Mutfak bölümü yeniden yapılandırma | Turuncu/uyarı pill'leri kaldırıldı; iki düz alt-başlık: "Şu ürünler hariç tavsiye edilir" (kırmızı chip'ler) + "Tavsiye edilenler" (mutfak chip'leri **turuncu→yeşil**) | ✅ |
| Güven kriteri rozetleri | Daha önce son kullanıcıdan gizlenen kriterler artık amblem rozet olarak gösteriliyor: dairesel çerçeve + kritere özel Material ikon + kısa etiket; tek satır, sığmazsa yatay kaydırma; tıklayınca açıklama dialogu. 7 seed kritere özel ikon/renk, admin-ekli bilinmeyen key'lere deterministik renkli fallback. Yeni `trust_criteria_badge.dart`; ölü `trust_criteria_chip.dart` silindi | ✅ |

**Doğrulama:** `flutter analyze` temiz; 3 yeni widget testi (`trust_criteria_badge_test.dart`) geçiyor; golden render ile tek-satır düzeni + renkler görsel teyit edildi. API/model değişikliği yok (`trust_criteria` zaten dönüyordu). Spec: `docs/superpowers/specs/2026-07-27-venue-detail-cuisine-trust-design.md`.

---

## Pending Görünürlüğü Düzeltmesi + Düzenleme-Sonrası-Onay Özelliğinin Kaldırılması (2026-07-27)

### 1. Bulgu: `pending` statüsü hiçbir şeyi gizlemiyordu

"Rehber mekanı güncelleyince mekan tekrar admin onayına düşsün, onaylanana kadar uygulamada görünmesin" kuralı çalışmıyordu. Kök neden `ResetToPending` **değildi**; asıl sorun `pending` statüsünün okuma yolunda hiçbir şeyi gizlememesiydi:

| Okuma yolu | Eski davranış | Durum |
|---|---|---|
| `FindNearby` (harita/yakındakiler) | `status IN ('approved','pending')` — pending görünüyordu | ❌ → ✅ `= 'approved'` |
| `SearchByText` (arama) | `status IN ('approved','pending')` — pending görünüyordu | ❌ → ✅ `= 'approved'` |
| `Detail` (`GET /venues/:id`) | Statü kontrolü **yoktu**; her statü 200 dönüyordu | ❌ → ✅ onaylı değilse 404 |
| `FindByCity` / `FindPopular` / `FindNearbyApproved` / `FindByFoodCategory` | Zaten `= 'approved'` | ✅ değişmedi |

| İş | Özet | Durum |
|----|------|-------|
| Liste sorguları | `FindNearby` + `SearchByText` yalnızca `approved` döner; anlamsızlaşan `ORDER BY CASE WHEN status='approved'` dalları sadeleştirildi | ✅ |
| Detay ucu koruması | Onaylı olmayan mekan (pending/rejected/suspended) 404. İstisna `canViewUnapproved`: **admin** her statüyü, **ekleyen rehber** kendi mekanını görebilir — `my-venues` → detay akışı korunur (`FindByAddedBy` statüden bağımsız) | ✅ |

**Etki:** Yeni eklenen mekanlar artık admin onayına kadar uygulamada görünmez (önceki davranış: pending'ler listede en sonda gösteriliyordu). Bu, "onaylanmadan görünmesin" kuralının bilinçli sonucudur.

### 2. Karar: "Düzenleme sonrası tekrar onaya gönder" özelliği kaldırıldı

Yukarıdaki bulguyu takiben özelliğin kendisi **tamamen kaldırıldı** (ürün kararı). Sebebi: yeni mekanlar zaten `pending` doğuyor (`003_create_venues.up.sql` DEFAULT), `ResetToPending` ise yalnızca `status = 'approved'` satırını güncelliyordu ve hatası `_ =` ile yutuluyordu. Yani hiç onaylanmamış bir mekan düzenlendiğinde sessizce hiçbir şey olmuyordu. Yarım çalışan mekanizmayı onarmak yerine kaldırmak tercih edildi; **artık `PUT /venues/:id` mekanın statüsünü hiç değiştirmez.**

| İş | Özet | Durum |
|----|------|-------|
| `ResetToPending` kaldırıldı | Repo metodu (`venue_status_repo.go`), `venueStore` arayüz satırı, handler çağrısı ve test fake'i silindi — ölü kod bırakılmadı | ✅ |
| Mobil uyarı bandı kaldırıldı | Düzenleme ekranındaki "tekrar admin onayına gönderilecektir" bilgi kutusu silindi; başarı mesajı "Mekan güncellendi." olarak sadeleşti | ✅ |
| Şehir alanı salt-okunur | Düzenlemede şehir `enabled: false` (gri); artık PUT gövdesinde `city` gönderilmiyor; sahipsiz kalan `EditVenueNotifier.setCity` silindi | ✅ |
| Notlar ikonu hizası | `maxLines: 3` alanda dikeyde ortalanan `prefixIcon` üste sabitlendi (`prefixIconConstraints` + `Padding`), ikon `note_outlined`→`notes_outlined` | ✅ |

**Doğrulama:** `venue_detail_status_test.go` (3 test / 5 alt-vaka): pending+rejected+suspended anonim ve yabancı rehber için 404; approved herkese 200; pending ekleyen rehbere ve admine 200. Testlerin gerçekten hatayı yakaladığı, düzeltme `git stash`'lenerek doğrulandı (fix'siz: "404 beklendi, 200 alındı"). `go build ./...` + `go vet ./...` + `go vet -tags=integration ./internal/repository/` temiz, tüm backend testleri yeşil; `flutter analyze` düzenlenen dosyalarda yeni uyarı üretmiyor (6→5 pre-existing lint), `flutter test` 161 test geçiyor.

---

## Doğruladığım Mekanlar + Doğrulamayı Geri Çekme (2026-07-27)

Mekanlarım sayfası ikiye bölündü ve rehberler doğrulamalarını geri çekebiliyor. Spec: `docs/superpowers/specs/2026-07-27-dogruladigim-mekanlar-geri-cekme-design.md` (gitignore, diskte).

**Kavramsal not — Confirm ≠ Verify.** Kodda iki ayrı işlem "doğrulama" adıyla anılıyor; bu iş **Confirm** ile ilgilidir:

| İşlem | Endpoint | Ne yapar |
|---|---|---|
| **Confirm** (destekleme) | `POST/DELETE /venues/:id/confirm` | `venue_confirmations` kaydı → **rozeti** besler |
| **Verify** (dönem tazeleme) | `PUT /venues/:id/verify` | `verification_due_at` ileri → mekanı **canlı** tutar |

Ekleyen kişinin otomatik `venue_confirmations` kaydı **yoktur** (`Create` tabloya yazmaz); Verify için de gerekmez (`added_by` yetiyor). Mobil UI ekleyene Confirm butonunu göstermiyor (`venue_detail_screen.dart:692`), bu yüzden iki liste pratikte ayrıktır.

| İş | Özet | Durum |
|----|------|-------|
| `GET /guide/my-confirmations` | `FindConfirmedBy` — rehberin doğruladığı mekanlar, `vc.created_at` → `confirmed_at` ile; en yeni önce. Taze/eski ayrımı yok | ✅ |
| `DELETE /venues/:id/confirm` | `RemoveConfirmation` — `ConfirmVenue`'nün aynası: tek tx'te kayıt silinir + `confirmation_count` taze pencereye göre yeniden hesaplanır | ✅ |
| Yetki modeli | `guideID` **token'dan** alınır (path'ten değil) → rehber yalnızca kendi kaydını silebilir; kaydı yoksa 404 | ✅ |
| Mekanlarım ekranı | `CustomScrollView` + iki sliver bölüm ("Eklediğim Mekanlar" / "Doğruladığım Mekanlar"), başlıkta sayı; ortak `_MyVenueCard` opsiyonel `trailing` ile; doğrulanan kartta statü rozeti yerine doğrulama tarihi, aksiyon **yok** (salt liste) | ✅ |
| Geri çekme aksiyonu | **Yalnızca mekan detay ekranında.** `_ConfirmVenueButton` iki durumlu hale geldi: doğrulanmamışsa "Doğruluyorum", doğrulanmışsa "Bu mekanı doğruladınız" + "Doğrulamayı Geri Çek". Yerel `_localConfirmed` (tri-state) sunucu yanıtı ile detay tazelenmesi arasındaki boşlukta butonu doğru yönde tutar | ✅ |
| Geri çekme akışı | Onay dialogu → `myConfirmationsProvider.revokeConfirmation` → DELETE + **her iki liste** yenilenir (rozet düştüğü için "eklediklerim" de etkilenir) + `venueDetailProvider` invalidate → snackbar. Detay ekranı API'yi doğrudan çağırmaz: `MyVenuesScreen` yalnızca `initState`'te yüklendiği için, provider üzerinden gitmek detaydan geri dönüldüğünde listenin bayat kalmasını önler | ✅ |
| Migration | **Gerekmedi** — `venue_confirmations` PK'si zaten `(venue_id, guide_id)` | ✅ |

**Kasıtlı davranış:** Geri çekme `verified_at` / `verification_due_at`'e **dokunmaz** — bu bir güven sinyalidir, mekanı öldürme eylemi değil. Mekan canlı kalır, yalnızca rozeti zayıflar. Rehber o mekan için tazeleme (`VerifyByGuide`) yetkisini de kaybeder; ayrıca kodlanmadı, kayıt silinince `EXISTS(...)` dalı eşleşmediği için doğal sonuç. Geri çekilen doğrulama tekrar yapılabilir (kalıcı ceza değil).

**Kabul edilen risk:** Mekanı ayakta tutan tek doğrulayan geri çekerse tazeleme yalnızca ekleyene kalır; ekleyen pasifse mekan dönem sonunda suspend olabilir. Bilinçli karar.

**Doğrulama:** 5 yeni integration testi (testcontainers, gerçek PostGIS): sayaç düşüyor, kayıt siliniyor, **`verification_due_at`/`verified_at` değişmiyor** (en kritik regresyon koruması — `verification_due_at = NOW()` enjekte edilerek testin gerçekten yakaladığı doğrulandı), yabancı silemiyor (404), tekrar confirm edilebiliyor, liste doğru sırada ve geri çekince düşüyor. 4 yeni handler testi (token'dan guideID, 404, 401, liste ucu). 5 yeni mobil provider testi. Tüm suite'ler yeşil: backend `go test ./...` + `go test -tags=integration ./internal/repository/`, mobil `flutter test` 166 test (161→166), `flutter analyze` yeni uyarı yok (26 pre-existing).

---

## Fix: Mutfak Kategorisinden Geri Dönüş Ana Sayfaya (2026-07-27)

**Sorun:** Ana sayfadan bir mutfağa girip geri basınca ana sayfa yerine tam ekran bir kategori ızgarası açılıyordu.

**Bulgu:** `FoodDiscoveryScreen` iki modluydu — `selectedCategoryId == null` ise kategori ızgarası, doluysa mekan listesi. Geri tuşu `clearSelection()` çağırıp ekranı ızgara moduna düşürüyordu. Ancak ekrana **her zaman kategori seçilmiş olarak** giriliyor (`CategoryGrid` ve `CategorySlider` önce `selectCategory` çağırıp sonra `context.go`), yani ızgara modu yalnızca geri basınca görülebilen, giriş noktası olmayan bir ekrandı.

| İş | Özet | Durum |
|----|------|-------|
| Izgara modu kaldırıldı | `FoodDiscoveryScreen` tek modlu: yalnızca mekan listesi. Kullanılmayan `_CategoryCard` (82 satır) ve `foodCategoriesProvider` importu silindi | ✅ |
| Geri → ana sayfa | Hem başlıktaki geri oku hem sistem geri hareketi (`PopScope`) `clearSelection()` + `context.go(AppRoutes.home)` yapıyor. Seçim temizliği önemli: aksi halde ekrana tekrar girildiğinde önceki kategorinin sonuçları anlık görünürdü | ✅ |
| `category_grid.dart` silindi | `CategoryGrid` widget'ı hiçbir yerden kullanılmıyordu (ana sayfada yalnızca `CategorySlider` var). Slider ayrı dosya ve kendi private sınıflarını kullandığı için etkilenmedi | ✅ |

**Doğrulama:** `flutter analyze` 26 issue — değişiklik öncesiyle aynı taban, dokunulan/silinen dosyalarda uyarı yok (silme sonrası sayının artmaması hiçbir şeyin `CategoryGrid`'e bağlı olmadığını doğruluyor). `flutter test` 166 test geçiyor.

---

## Bildirimler: SnackBar → Üstten Kayan Toast (2026-07-28)

**Sorun:** Bildirimler ekranın altından, kenardan kenara, kare köşeli çıkıyor ve 4 saniye (Flutter varsayılanı) ekranda kalıyordu. Alt navigasyonun ve içeriğin üstünü kapatıyorlardı.

**Bulgu:** 12 `showSnackBar` çağrısı 7 dosyaya dağılmıştı ve her biri kendi stilini kuruyordu — üç farklı başarı rengi (`Colors.green`, `AppTheme.primary`, renksiz), ikon yok, süre yönetimi yok. Ortak bir bildirim bileşeni yoktu.

| İş | Özet | Durum |
|----|------|-------|
| `AppToast` bileşeni | `shared/widgets/app_toast.dart` — `Overlay` tabanlı, üstten kayarak gelen bildirim. `success` / `error` / `info` varyantları tema renklerini kullanır (`pinApproved` / `error` / `primary`), her biri kendi ikonuyla | ✅ |
| Konum ve görünüm | Status bar altında, 16px kenar boşluklu, radius 16, gölgeli kart. Alt navigasyonu ve sayfa içeriğini kapatmaz | ✅ |
| Süre | Başarı/bilgi 2 sn, hata 3.5 sn. Hatalar okunacak kadar duruyor, başarı mesajları yolu tıkamıyor | ✅ |
| Animasyon | 260 ms `easeOutCubic` ile yukarıdan kayma + fade. Yukarı sürükleyerek erken kapatılabilir (`Dismissible`) | ✅ |
| Tek toast garantisi | Statik `OverlayEntry` + `Timer`; yeni toast öncekini anında kaldırır, üst üste binme olmaz | ✅ |
| 12 çağrı yeri taşındı | 7 dosyada `ScaffoldMessenger.showSnackBar` → `AppToast.success/error`. Kodda `showSnackBar` kalmadı | ✅ |

**Kasıtlı karar:** Toast `Overlay.maybeOf(rootOverlay: true)` kullanıyor — bottom sheet içinden tetiklenen bildirimler (yorum ekleme, mekan bildirme) sheet kapanırken yok olmasın diye kök overlay'e biniyor.

**Doğrulama:** 5 yeni widget testi (mesaj+ikon+renk eşleşmesi, 2 sn'de kaybolma, hatanın daha uzun kalması, ikinci toast'ın birincinin yerini alması). `flutter test` 171 test geçiyor (166→171). `flutter analyze` 26 issue — değişiklik öncesiyle aynı taban, dokunulan dosyalarda uyarı yok.

---

## App Bar Logo: Sola Yaslama + Yatay Logo Denemesi (2026-07-28)

**İstek:** App bar'daki logoyu `assets/logo/logo_with_name/i_timat_yatay_effaf_logo.svg` ile değiştirmek, logoyu biraz sola yaslamak; arama çubuğu, bildirim ve favori ikonlarının yeri değişmemek.

| İş | Özet | Durum |
|----|------|-------|
| Logonun yatay konumu | `AppHeader` içinde logo `Transform.translate` ile sarıldı, kayma miktarı tek sabitte: `_logoShift`. `titleSpacing` yerine offset tercih edildi: `titleSpacing: 0` tüm `Row`'u kaydırıp diğer bileşenleri de taşırdı. Önce -12 (sola) denendi, ardından kullanıcı isteğiyle 12px sağa alınarak **0**'da karar kılındı | ✅ |
| Diğer bileşenlerin korunması | Konum çubuğu, bildirim ve favori ikonları `Row` içinde aynı sırada/aralıkta; offset yalnız logoya uygulandığı için layout'a etkisi yok | ✅ |
| Yatay logonun bağlanması | **Geri alındı** — dosya kullanılamaz durumda (aşağıya bak). `screen.svg` (isimsiz logo) korundu, `_Logo` içine TODO bırakıldı | ⛔ |

**Bulgu — `i_timat_yatay_effaf_logo.svg` kullanılamaz:** Dosya adında "şeffaf" geçmesine rağmen içinde hiç şeffaflık verisi yok. Gerçek bir vektör değil, raster bir görüntüden otomatik trace edilmiş:

- 6134 path, hepsi ~28×30 px opak kare; `opacity="0."` **0 adet**, `fill="none"` **0 adet**
- 35 farklı beyaz/gri ton (`#FEFEFD`, `#BFBFBE`, `#BDBDBD`...) — kaynak PNG'nin şeffaf pikselleri de opak gri karelere çevrilmiş
- Sonuç: app bar'da logonun arkasında gri dikdörtgen blok görünüyor
- Ayrıca ağır: 2.8 MB, çözümleme 207 ms (mevcut `screen.svg`: 9 KB / 16 path / 69 ms) — her ekranın app bar'ında ödenecek maliyet
- viewBox `0 0 1024 1024` (kare), ink bbox tuvali tamamen dolduruyor — dosya adının aksine yatay değil

Kodla düzeltilebilir değil: alpha bilgisi dosyada hiç mevcut olmadığı için `flutter_svg` tarafında çevrilecek bir ayar yok. Gri path'leri toplu silmek de logoyu bozar, çünkü aynı gri tonlar logonun kendi gölge/detaylarında da kullanılıyor.

**Not:** Aynı klasördeki `screen-3.png` gerçekten şeffaf (RGBA, piksellerin %92.9'u tam şeffaf) ama içerik bbox'ı 512×584 — kare/dikey logo, "İtimat" yazılı yatay versiyon değil.

**Çözüm (aynı gün):** Şeffaf yatay PNG sağlandı ve bağlandı — `assets/logo/logo_with_name/itimat_yatay_logo.png` (kaynak dosya adındaki boşluk/parantezler asset yolunda kırılganlık yaratmasın diye temiz adla kopyalandı).

| Kontrol | Sonuç |
|---------|-------|
| Şeffaflık | Gerçek — piksellerin %95'i tam şeffaf, dört köşe de alpha=0 | 
| İçerik oranı | 682×274, oran 2.49 → gerçekten yatay |
| Turuncu zeminde kontrast | Koyu yeşil yazı (#204020) 3.39:1 — WCAG metin-dışı eşiği 3:1 üzerinde ✅ |
| Dosya boyutu | 120 KB (reddedilen SVG 2.8 MB idi) |

**Kasıtlı karar — tuval boşluğunun telafisi:** PNG 1024×1024 kare tuval, görünür logo ortada 682×274'lük alanda; üstte/altta ~%37 şeffaf boşluk var. Düz `height: 70` verilse logo ~19px görünürdü. Bunun yerine görünür yükseklik (34px) hedeflenip tuval `OverflowBox` ile oranla büyütülüyor (≈127px çizim). Böylece logo istenen boyutta görünüyor ama layout'ta yalnızca 34px yer kaplıyor — konum çubuğu ve ikonlar etkilenmiyor.

**Doğrulama:** Geçici widget testiyle ölçüldü: görüntü 84.6×127.1 çiziliyor, layout slotu 84.6×34.0 (test sonrası silindi). `flutter analyze lib/shared/widgets/app_header.dart` → temiz (kullanılmayan `flutter_svg` import'u kaldırıldı). `flutter test` → 175 test geçiyor; mevcut `app_header_test.dart` (bildirim ikonu/badge) testleri dahil.

**Ek düzenleme — yazı beyaza çevrildi:** Turuncu app bar üzerinde koyu yeşil (#304830) yazı görsel olarak soluk kalıyordu. PNG piksel düzeyinde işlenerek `itimat_yatay_logo_beyaz.png` üretildi.

- Logo iki bölgeye ayrılıyor: **amblem** x158–382, **yazı** x414–841 (aradaki x≈390 boşluğu ayraç olarak kullanıldı)
- Yazı zaten %80 tek renkti → yalnızca x≥390 bölgesindeki RGB beyaza alındı, **alpha'ya dokunulmadı**
- Alpha'ya dokunmamak kritik: ilk denemede parlaklığa göre alpha düşürülünce harf gövdesi yarı saydam olup opak piksel sayısı 0'a düştü. İkinci sürümde yazının opak piksel sayısı 16695 — kaynakla birebir aynı, kenar antialias'ı korunuyor
- Amblem bilinçli olarak orijinal renklerinde bırakıldı: tamamı beyaz varyantı da üretilip görsel karşılaştırma yapıldı, amblemin beyaz iç dolgusu ile yeşil konturu aynı renge gelince kubbe/yaprak/altın şerit detayı düz siluete dönüşüyor. O varyant silindi.

**Doğrulama (beyaz sürüm):** Yazı %100 beyaz (16695 opak px, kaynakla aynı), amblem birebir korundu (31436 px değişmedi), şeffaflık %95.1. Beyaz yazı / turuncu zemin kontrastı 3.42:1. `flutter analyze` temiz, `flutter test` → 175 test geçiyor.

---

## Yayın Hazırlığı Adım 4: Lokalizasyon + Palet + Koordinat Girdisi (2026-07-28)

Yayın yol haritasının "yayın öncesi kalite" adımı tamamlandı. Denetim sırasında yol
haritasındaki **üç madde bayat çıktı** ve kod okunarak düzeltildi (aşağıda ✅ ile).

| İş | Özet | Durum |
|----|------|-------|
| Giriş/kayıt ekranı Türkçeleştirme | Uygulamanın tek İngilizce kalan yüzeyiydi: "Sign In", "Email Address", "Create Account", "Join the trusted community", "OR CONTINUE WITH", "Don't have an account?". Kullanıcının gördüğü **ilk ekran** olduğu için tutarsızlık en görünür yerdeydi | ✅ |
| Renk paleti tutarlılığı | Aynı iki ekran temayı bypass edip soğuk gri-mavi sabitler kullanıyordu (`0xFFF6F8F7` zemin, `0xFFE2E8F0` kenarlık, `Colors.grey.shade*`, `Colors.red`) — sıcak turuncu "Spice Market" paletiyle çakışıyordu. Tümü `AppTheme.background/border/textPrimary/textSecondary/error`'a bağlandı. **Hardcoded renk 18 → 0** | ✅ |
| Ölü "Forgot Password?" butonu | `onPressed: () {}` — basınca hiçbir şey olmuyordu. Şifre sıfırlama akışı yokken kırık bir söz olarak yayına çıkmasın diye kaldırıldı | ✅ |
| Düz koordinat girdisi | "Kullanıcı haritada kendi işaretlediği konumu eklerse koordinat parse edilebilmeli" maddesi | ✅ |

### Koordinat girdisi — kök neden parse değil, ondan önceki kapıydı

Sorunun parser'da olduğu varsayılıyordu. Kod okunarak ve **çalıştırılarak** doğrulandı:
Google Maps URL'lerinin tamamı (`?q=`, `?ll=`, `/@lat,lng` dahil — yani kullanıcının haritada
işaretlediği nokta linki) zaten doğru parse ediliyordu. Gerçekte kırık olan tek senaryo
**ham koordinat metni yapıştırma** (`41.0082, 28.9784`) idi.

Asıl engel `parseLink` değil, ondan önce çalışan kapıydı: `guide_provider.dart:180`
`isValidMapsLink` yalnızca bilinen Google host'larını kabul ediyor, koordinat metni bu
kontrolden geçemediği için `parseLink` **hiç çağrılmıyordu**. Sadece parser'ı düzeltmek
kullanıcı açısından hiçbir şeyi değiştirmezdi.

| Değişiklik | Detay |
|-----------|-------|
| `_rawCoordinatePattern` | `^(-?\d+\.?\d*)\s*,\s*(-?\d+\.?\d*)$` — `parseLink` URL çözümlemeye girmeden önce koordinatı doğrudan işler |
| `isValidMapsLink` genişletildi | Ham koordinat da kabul ediliyor; aksi halde kapı kapalı kalırdı |
| Aralık doğrulaması devredildi | Mevcut `_tryParse`'a bırakıldı → sınır dışı (91, 181) ve koordinat olmayan metin reddedilmeye devam ediyor, mantık tek yerde |
| Keşfedilebilirlik | Form başlığı "Google Maps Linki" → **"Mekan Konumu"**; alan etiketi "Maps linki veya koordinat"; hint ve hata mesajı koordinat seçeneğini söylüyor. Aksi halde özellik kodda var, kullanıcı için yok |

**Doğrulama:** 6 yeni test (virgüllü/boşluksuz/negatif koordinat, aralık dışı red, koordinat
olmayan metin red, kapı davranışı). Testlerin gerçekten eksik davranışı yakaladığı **önce RED
alınarak** doğrulandı (4 test başarısız → düzeltme → GREEN). `flutter test` **175 → 181**,
`flutter analyze` 26 issue (değişiklik öncesiyle **aynı taban**, dokunulan dosyalarda yeni uyarı
yok). Backend `go build` + `go vet` temiz.

### 🔄 Yol haritasında bayat çıkan üç madde (kod okunarak düzeltildi)

Bunlar bu oturumun asıl değerli bulgusu — plan gerçeğin gerisinde kalmıştı:

| Madde | Planda yazan | Gerçek durum |
|-------|--------------|--------------|
| **CI** | "⚠️ CI henüz GitHub'da koşmadı" | **Yanlış.** CI günlerdir koşuyor ve son iki koşu `success` (27 ve 28 Temmuz). İlk koşu endişesi geçersiz |
| **Push** | "Push edilmemiş lokal commit'ler gidecek" | **Yanlış.** `origin/main` lokal `main` ile aynı commit'teydi (d1fbe67); her şey push edilmişti |
| **Empty state** | "my_venues'ta var, diğerlerinde yok" | **Yanlış.** 11 ekranda mevcut (favoriler, arama, bildirimler, şehir mekanları, filtre sonuçları, mutfak keşfi…). Ayrıca ortak `error_retry_widget.dart` de var |

**Ders:** Yol haritası maddeleri iş başlamadan önce kodda doğrulanmalı; aksi halde zaten
yapılmış iş tekrar planlanıyor, gerçek boşluk (koordinat kapısı) ise gözden kaçıyor.

**Temizlik:** `.DS_Store` dosyaları takipten çıkarıldı ve `.gitignore`'a eklendi (her klasör
gezintisinde kirli çalışma ağacı üretiyorlardı).

**Commit'ler:** `834d88e` (auth TR+palet), `9a25d02` (koordinat girdisi), `132f40d` (.DS_Store).
