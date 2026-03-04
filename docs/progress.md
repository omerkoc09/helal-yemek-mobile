# Caiz mi? — Proje İlerleme Durumu

> Son güncelleme: 2026-02-28
Mevcut Durum Notu: Proje genel hatlarıyla Faz 5'e (Test & Yayın) geçmiş gibi görünse de, Faz 1-4 arasındaki bazı özelliklerde (MVP çekirdeği) mimari değişiklikler, UX revizyonları ve bug fix'ler yapılmaktadır. Bir modülü düzenlerken, eski kodun kusursuz olduğunu varsayma; refactoring (kod iyileştirme) ve mantık değişiklikleri yapmak serbesttir ve gereklidir.
---

## Düzgün Çalışmayan Kısımlar
1. Eklenen fotoğraf gözükmüyor

## Revize Edilecek Özellikler:

1. rehberin ekklediği mekanın bilgilerini belli süre geçtikten sonra (3 ay, 6 ay) güncellemesi için bildirim atılır. Güncellemezse mekan uygulamada askıya alınır.


2. admin panelinde
onay bekleyen mekanların koordinatları yerine rehberin sisteme eklediği  mekanın google maps linki olsun. Tıklandığında google mapse yönlendirsin Böylece admin onun doğruluğunu kontrol edebilir. 

## Öncelikli Olarak Yapılması Gerekenler
1. ayrı bir tane tab olsun ne yesem? adında ->yemek kategorileri çıksın karşısına  seçebileceği ( çorba, döner, tatlı gibi) mevcut konuma göre var olan uygun mekanlar listelensin. (yakından uzağa göre en alakalı)


## Tamamlanan İşler

### Backend (Go + Fiber)

| Modül | Durum | Detay |
|-------|-------|-------|
| Proje yapısı (cmd/internal/pkg) | ✅ | Clean architecture: handler → service → repository |
| PostgreSQL + PostGIS bağlantısı | ✅ | Connection pool, docker-compose ile dev ortamı |
| Veritabanı migration sistemi | ✅ | 13 migration dosyası, golang-migrate |
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
| Harita yönlendirme | ✅ | map_launcher (Google/Apple Maps) |
| Güvenli token depolama | ✅ | flutter_secure_storage |

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
