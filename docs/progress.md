# Caiz mi? — Proje İlerleme Durumu

> Son güncelleme: 2026-06-19
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

smtp env yi doldur.

mekan puanlamasını çeşitlendirme?

kullanıcının şehrine veya yakınına yeni mekan eklenirse bildirim? uygulama arka planda konum çekmeye devam edecek mi?


birden fazla rehberin onaylamasıyla yeni rozet takdimi 

mobil:
-~~profili düzenle zenginleştirilecek.~~ ✅ (2026-06-19)
-~~yorumların anonimliği kaldırılacak.~~ ✅ (2026-06-19)
-seyyahın rehberliği onaylanınca uygulamadan çıkıp  geri girmesi gerekiyor? (bildirim atılabilir)
-~~status rehber->seyyah yapınca rehber başvurunuz inceleniyor sayfası geliyor ama tekrar bir guide başvurusu yapılmıyor otomatik olarak.~~ ✅ (2026-06-19)

rehberlere yeni bir özellik ekleyelim:
hangi şehir için rehberlik yapacağını belirleyelim.
hali hazırda ikamet ettiği şehirde rehberlik yapabilsin. (semt seçmeli mi)
bunu rehberlik başvurusunda şart koşalım. Referans kodu ile rehber ekleme mantığını kaldırsak mı? o tarafı kontrol etmek zor. Hem aynı kontrolleri iki defa yapmış olacağız. Herkes bizim kontrolümüzden geçse daha iyi gibi. 
hem panelden hangi şehirlerde kaç tane rehber olduğunu görürüz (harita mantıklı)



## Tamamlanan İşler

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

## Daha sonra Yapılması Gerekenler

### 1. Test & Kalite (Yüksek Öncelik)
- [ ] Backend unit testleri (sadece auth_handler_test.go mevcut, diğer handler/service/repo testleri eksik)
- [ ] Flutter widget ve integration testleri
- [ ] API endpoint'leri için E2E testler
- [ ] Error handling iyileştirmeleri (standart hata formatı, kullanıcı dostu mesajlar)

### 2. Fotoğraf Depolama — S3 Entegrasyonu (Yüksek Öncelik)
- [ ] S3/MinIO cloud storage entegrasyonu (şu an local uploads/ klasörüne yazılıyor)
- [ ] Fotoğraf boyutlandırma ve sıkıştırma (thumbnail, medium, full)
- [ ] CDN entegrasyonu (CloudFlare veya benzeri)

### 3. Production Deployment (Yüksek Öncelik)
- [ ] Production Docker image ve multi-stage build
- [ ] CI/CD pipeline (GitHub Actions veya benzeri)
- [ ] Production ortam değişkenleri ve secret yönetimi
- [ ] SSL/TLS sertifikası ve HTTPS yapılandırması
- [ ] Database backup stratejisi
- [ ] Monitoring ve alerting (Prometheus + Grafana veya benzeri)
- [ ] Logging altyapısı (structured logging, log aggregation)
- [ ] Health check ve readiness probe

### 4. App Store & Google Play Yayın Hazırlığı (Yüksek Öncelik)
- [ ] iOS code signing ve provisioning profile
- [ ] Android keystore ve signing config
- [ ] App Store Connect hesabı ve metadata
- [ ] Google Play Console hesabı ve metadata
- [ ] App ikonu ve splash screen tasarımı
- [ ] Privacy policy ve terms of service sayfaları
- [ ] App Store screenshot'ları

### 5. Güvenlik İyileştirmeleri (Orta Öncelik)
- [ ] Input validation güçlendirme (tüm endpoint'ler)
- [ ] CORS yapılandırması (production domain'ler)
- [ ] Rate limiting fine-tuning (endpoint bazlı)
- [ ] SQL injection audit
- [ ] Dosya yükleme güvenliği (dosya tipi, boyut kontrolü)
- [ ] Brute-force login koruması

### 6. UX İyileştirmeleri (Orta Öncelik)
- [ ] Offline destek (temel verilerin cache'lenmesi)
- [ ] Pull-to-refresh tüm listelerde
- [ ] Boş durum (empty state) ekranları
- [ ] Loading skeleton'lar (shimmer effect)
- [ ] Hata ekranları ve retry mekanizması
- [ ] Onboarding/tanıtım ekranları (ilk kullanım)
- [ ] Dark mode desteği

### 7. Performans Optimizasyonları (Orta Öncelik)
- [ ] API response pagination (venue listesi, review listesi)
- [ ] Image lazy loading ve progressive loading
- [ ] Database query optimization ve N+1 analizi
- [ ] Flutter build optimizasyonu (tree shaking, code splitting)
- [ ] API response caching (HTTP cache headers)

### 8. Eksik İş Mantığı (Orta Öncelik)
- [ ] Guide başvurusu: motivasyon metni ve referans mekanizma
- [ ] Venue confirmation akışı (başka Guide'ların mevcut mekanı doğrulaması)
- [ ] Admin: toplu işlemler (bulk approve/reject)
- [ ] Kullanıcı raporlama sistemi (uygunsuz yorum/mekan bildirimi)
- [ ] Email bildirimleri (Guide başvuru sonucu, mekan onay/red)

### 9. Gelecek Sürüm Özellikleri (Düşük Öncelik — v2.0)
- [ ] Push notification sistemi
- [ ] Gelişmiş filtreleme (mesafe, puan, kategori, çalışma saati)
- [ ] Çoklu dil desteği (İngilizce, Arapça)
- [ ] Sosyal medya paylaşımı
- [ ] Mekan önerileri (kişiselleştirilmiş)
- [ ] Analitik dashboard (kullanıcı/mekan istatistikleri)

---

## Faz Durumu

| Faz | Açıklama | Durum |
|-----|----------|-------|
| Faz 1: Altyapı | Backend, DB, Auth, API | ✅ Tamamlandı fakat düzenleme gerek |
| Faz 2: Mobil Uygulama | Flutter, Harita, UI | ✅ Tamamlandı fakat düzenleme gerek|
| Faz 3: Sosyal Özellikler | Yorum, Favori, Guide | ✅ Tamamlandı fakat düzenleme gerek |
| Faz 4: Admin Paneli | Dashboard, Onay, Audit | ✅ Tamamlandı fakat düzenleme gerek|
| Faz 5: Test & Yayın | Test, Store yayını | 🔶 Devam Ediyor |


*Her bir madde için detaylı implementasyon planları ayrı MD dosyalarında hazırlanacaktır.*
