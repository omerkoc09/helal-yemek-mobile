# Caiz mi? - Proje Raporu


## 1. Yönetici Özeti

**Caiz mi?**, Müslüman seyyahların seyahat ettikleri şehirlerde helal gıda sunan mekanları kolayca bulmalarını sağlayan bir mobil uygulamadır. Uygulama; rehberler (gönüllüler), seyyahlar ve yöneticilerden oluşan üç katmanlı bir kullanıcı yapısına sahiptir. Rehberler mekanları ekler ve doğrular, seyyahlar mekanları keşfeder ve değerlendirir, yöneticiler ise içerik moderasyonunu gerçekleştirir.

Proje, **Flutter** (mobil) ve **Go** (backend) teknolojileri üzerine inşa edilmiştir. Konum tabanlı arama için **PostGIS** destekli PostgreSQL veritabanı kullanılmaktadır.

---

## 2. Problem Tanımı ve Motivasyon

- **Bilgi eksikliği:** Yeni bir şehirde hangi restoranların helal yemek sunduğu bilinmemektedir.
- **Dağınık bilgi:** Helal mekan bilgileri sosyal medya grupları, ve ağızdan ağıza iletişim gibi dağınık kaynaklarda bulunmaktadır.
**Caiz mi?**, bu sorunları topluluk destekli doğrulama mekanizması ve konum tabanlı akıllı arama ile çözmeyi hedeflemektedir.

---

## 3. Hedef Kitle

| Segment | Açıklama |
|---------|----------|
| **Seyyahlar** | Seyahat eden ve helal mekan Müslüman kullanıcılar |
| **Rehberler** | Yaşadıkları şehirdeki helal mekanları bilen ve gönüllü olarak ekleyen kullanıcılar |

---

## 4. Mevcut Özellikler

### 4.1 Kimlik Doğrulama ve Yetkilendirme
- E-posta/şifre ile kayıt ve giriş
- **Google Sign-In** ile sosyal giriş
- JWT tabanlı oturum yönetimi 
- Rol tabanlı erişim kontrolü (RBAC): Seyyah, Rehber, Yönetici

### 4.2 Mekan Keşfi
- **Konum tabanlı arama:** Kullanıcının GPS konumuna göre yakındaki helal mekanları harita üzerinde gösterme (PostGIS)
- **Şehir bazlı arama:** Belirli bir şehirdeki mekanları listeleme
- **Harita görünümü:** Google Maps entegrasyonu ile mekanları pin olarak gösterme
  - Yeşil pin: Onaylı mekan
  - Sarı pin: Onay bekleyen mekan
- **Navigasyon desteği:** Seçilen mekana yol tarifi alma

### 4.3 Mekan Yönetimi
- Rehberler tarafından mekan ekleme
- Mekan bilgileri: Ad, adres, şehir, helal kriterleri, helal yemek kategorileri, fotoğraflar
- Mekan fotoğrafı yükleme desteği
- Mekan statüleri *rejected, *pending, *approved
- Mekan eklendiğinde pending durumunda admin onayını bekler.

### 4.4 Yemek Kategorileri
14 önceden tanımlı kategori: Döner, Tost, Börek, Pide & Lahmacun, Pizza, Köfte ve daha fazlası. Her kategoride alt yemek kalemleri mevcuttur. Rehberler özel yemek kalemleri de ekleyebilir.

### 4.5 Helal Kriterleri
- Kişisel Deneyim
- Helal Sertifikasına sahip
- Mekan Sahibini Tanıma
- ...
- Mekanlar birden fazla kriter ile ilişkilendirilebilir

### 4.6 Değerlendirme Sistemi
- 1-5 yıldız puanlama ve yorum
- Ortalama puanın mekan detayında gösterimi

### 4.7 Favoriler
- Beğenilen mekanları kaydetme
- Kişisel favori listesi

### 4.8 Düzeltme
- Rehberler mevcut mekanların konum bilgilerini değiştirse mekan pending durumuna düşer
- Yönetici onay/ret iş akışı

### 4.9 Rehber Başvuru Sistemi
- Seyyahlar rehber olmak için bir rehberin referans kodu ile başvuru yapabilir
- Yönetici onayı ile rol yükseltmesi

### 4.10 Yönetici Paneli
- Genel durum panosu (bekleyen mekanlar, başvurular vb.)
- Mekan onay/ret yönetimi
- Rehber başvuru yönetimi
- Düzeltme önerisi yönetimi
- Denetim günlüğü (audit log): Tüm yönetici aksiyonlarının kaydı
- Kullanıcı yönetimi

---


## 6. Teknik Mimari

### 6.1 Sistem Mimarisi

```
┌─────────────────────┐
│   Flutter Mobil App  │
│  (iOS + Android)     │
│                      │
│  Riverpod + GoRouter │
│  Dio HTTP Client     │
│  Google Maps         │
└──────────┬──────────┘
           │ HTTPS / REST API
           ▼
┌─────────────────────┐
│   Go Backend (Fiber) │
│                      │
│  JWT Auth + RBAC     │
│  Rate Limiting       │
│  File Upload         │
└──────────┬──────────┘
           │
     ┌─────┴─────┐
     ▼           ▼
┌─────────┐ ┌──────────┐
│PostgreSQL│ │ S3/MinIO │
│+ PostGIS │ │ (Photos) │
└─────────┘ └──────────┘
```

### 6.2 Teknoloji Yığını

#### Mobil Uygulama
| Teknoloji | Kullanım Alanı |
|-----------|---------------|
| **Flutter** | Cross-platform mobil framework (iOS + Android) |
| **Riverpod** | State management |
| **GoRouter** | Tip güvenli yönlendirme (routing) |
| **Dio** | HTTP istemci (interceptor ile token yenileme) |
| **Google Maps Flutter** | Harita görüntüleme |
| **Geolocator** | GPS konum servisleri |
| **Freezed + JSON Serializable** | Veri modelleri |
| **flutter_secure_storage** | Güvenli token saklama (Android Keystore) |

#### Backend
| Teknoloji | Kullanım Alanı |
|-----------|---------------|
| **Go 1.24** | Backend programlama dili |
| **Fiber v2** | Yüksek performanslı HTTP framework |
| **PostgreSQL 16 + PostGIS 3.4** | İlişkisel veritabanı + coğrafi sorgulama |
| **pgx/v5** | Veritabanı bağlantı havuzu |
| **golang-jwt/jwt v5** | JWT token yönetimi |
| **bcrypt** | Şifre hashleme |
| **golang-migrate** | Veritabanı migrasyonları (gömülü SQL) |

#### Altyapı
| Teknoloji | Kullanım Alanı |
|-----------|---------------|
| **Docker + Docker Compose** | Konteyner yönetimi |
| **PostGIS** | Coğrafi veri desteği |
| **S3 uyumlu depolama** | Fotoğraf saklama |

### 6.3 Veritabanı Tasarımı

Veritabanı 12 ana tablodan oluşmaktadır:

- **users** — Kullanıcı bilgileri ve roller
- **venues** — Mekan bilgileri (PostGIS GEOGRAPHY konum verisi)
- **reviews** — Kullanıcı değerlendirmeleri
- **favorites** — Favori mekanlar
- **halal_criteria** — Helal kriterleri (referans tablo)
- **venue_criteria** — Mekan-kriter ilişkisi (M:N)
- **venue_photos** — Mekan fotoğrafları
- **food_categories** — Yemek kategorileri
- **food_items** — Yemek kalemleri
- **guide_applications** — Rehber başvuruları
- **correction_suggestions** — Düzeltme önerileri
- **audit_logs** — Denetim günlüğü
- **venue_confirmations** — Çift doğrulama takibi

Konum tabanlı sorgulamalar için **PostGIS** kullanılmakta, `ST_DWithin()` ve `ST_Distance()` fonksiyonları ile yarıçap bazlı mekan araması yapılmaktadır.


## 10. Dağıtım Planı

### Sunucu Tarafı
- Docker ile konteynerleştirme (Go multi-stage build)
- PostgreSQL + PostGIS üretim ortamı
- S3 veya MinIO ile fotoğraf depolama
- Redis ile oturum ve oran sınırlama önbelleği
- Load balancer ile yatay ölçeklenebilirlik

### Mobil
- **iOS:** App Store
- **Android:** Google Play Store
- Kod imzalama ve sertifika yönetimi

---

---

*Bu rapor, projenin mevcut durumunu ve teknik detaylarını özetlemek amacıyla hazırlanmıştır.*
