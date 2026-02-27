# Caiz mi? — Proje Özeti

> "Caiz mi?" — Müslüman gezginlerin ziyaret ettikleri şehirlerde helal mekan bulmalarını sağlayan Flutter mobil uygulaması.

## Proje Vizyonu

Müslüman gezginler yeni bir şehre gittiklerinde hangi restoranların helal yiyecek sunduğunu bilmiyorlar. "Caiz mi?" bu sorunu çözüyor.

## Temel Hedefler

- **Güvenilir Helal Mekan Keşfi**: Onaylı yerel rehberler (Guide) helal kriterleriyle mekan ekliyor
- **Kalite Kontrolü**: Adminler içerikleri denetliyor ve onaylıyor
- **Kolay Keşif**: Gezginler harita üzerinde mekanları keşfediyor
- **Topluluk Doğrulaması**: Çift doğrulanmış mekanlar için güven sistemi

## Anahtar Paydaşlar

### Kullanıcı Rolleri

| Rol | Açıklama | Yetkileri |
|---|---|---|
| **Traveler** | Gezgin kullanıcılar | Mekan görme, yorum yapma, favorileme |
| **Guide** | Yerel rehberler | Mekan ekleme, düzeltme önerme |
| **Admin** | Sistem yöneticileri | Onaylama, reddetme, kullanıcı yönetimi |

### Rol Akışı
- Yeni kullanıcı → otomatik **Traveler**
- Traveler → **Guide** başvurusu yapabilir → Admin onaylar
- Admin, herhangi bir kullanıcıyı **Admin** yapabilir

## Başarı Metrikleri

- **Kullanıcı Aktivitesi**: Aktif kullanıcı sayısı ve uygulama kullanım sıklığı
- **Mekan Kalitesi**: Onaylı mekan sayısı ve çift doğrulanmış mekan oranı
- **Topluluk Katılımı**: Guide başvuru sayısı ve mekan ekleme aktivitesi
- **Kullanıcı Memnuniyeti**: Uygulama değerlendirmeleri ve geri bildirimler

## Kısıtlar ve Sınırlamalar

### Teknik Kısıtlar
- iOS App Store zorunluluğu: Sign in with Apple desteği
- Harita API maliyetleri: Google Maps/MapKit kullanım limitleri
- Fotoğraf depolama: S3 uyumlu depolama maliyetleri

### İş Kısıtları
- Guide kalitesi: Manuel onay süreci gerekli
- İçerik moderasyonu: Admin kapasitesi sınırlı
- Spam önleme: Rate limiting ve güvenlik önlemleri

### Yasal Kısıtlar
- KVKK/GDPR uyumluluğu: Kişisel veri koruma
- Kullanıcı içeriği sorumluluğu: Mekan bilgilerinin doğruluğu
- Platform politikaları: App Store ve Google Play kuralları

## Zaman Çizelgesi Genel Bakış

### Faz 1: Altyapı (2-3 hafta)
- Backend temel yapı ve veritabanı
- Authentication sistemi
- Temel API endpoint'leri

### Faz 2: Mobil Uygulama (3-4 hafta)
- Flutter altyapı ve navigasyon
- Harita entegrasyonu
- Kullanıcı arayüzleri

### Faz 3: Sosyal Özellikler (2 hafta)
- Yorum ve puanlama sistemi
- Favoriler
- Guide özellikleri

### Faz 4: Admin Paneli (1-2 hafta)
- Admin dashboard
- Onay süreçleri
- Audit log sistemi

### Faz 5: Test ve Yayın (1 hafta)
- Kapsamlı test
- App Store/Google Play yayını
- İlk kullanıcı geri bildirimleri

## Proje Kapsamı

### Dahil Olanlar
- iOS ve Android mobil uygulaması
- Backend API servisleri
- Admin web paneli (mobil uygulama içinde)
- Harita entegrasyonu
- Fotoğraf yükleme sistemi
- Kullanıcı yönetimi ve roller

### Dahil Olmayanlar
- Web uygulaması (sadece mobil)
- Push notification sistemi (v1.0'da)
- Çoklu dil desteği (v1.0'da sadece Türkçe)
- Gelişmiş analitik dashboard
- Ödeme sistemi
- Sosyal medya entegrasyonu

---

*Bu belge, projenin temel vizyonunu ve hedeflerini tanımlar. Detaylı teknik özellikler için diğer dokümanlara başvurun.*