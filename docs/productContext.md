# İtimat — Ürün Bağlamı

## Konumlandırma

Uygulama bir **güvenilirlik platformu**dur: son kullanıcı bir mekanın "güvenilir" olup olmadığını görür. Helallik, daha geniş **güven** kavramının bir bileşenidir (güven kriterlerinden biridir), tek ölçüt değildir. Son kullanıcı güven kriterlerinin ne olduğunu bilmez; yalnızca kaba bir güven sinyali (güven rozeti + doğrulayan sayısı cümlesi) görür. Güven kriterleri guide/admin bağlamında kalır; mekan onayı tamamen adminin inisiyatif ve içgörüsündedir.

## Kullanıcı Profilleri (Personas)

### 1. Müslüman Gezgin (Traveler)
**Demografik**: şehir dışına seyahat eden, helal beslenmeye özen gösteren
**İhtiyaçlar**: 
- Yeni şehirde güvenilir mekan bulma
- Mekanın güvenilirliği hakkında hızlı sinyal (güven rozeti), fotoğraflar
- Kolay navigasyon ve yol tarifi
**Davranış**: Harita üzerinde keşif yapar, yorumları okur, favoriler

### 2. Yerel Rehber (Guide)
**Demografik**: yerel halktan, güvenilir mekanları iyi bilen
**İhtiyaçlar**:
- Bildiği güvenilir mekanları paylaşma
- Topluma katkı sağlama
- Güvenilir bilgi kaynağı olma
**Davranış**: Aktif mekan ekler, güven kriterlerini işaretler, düzeltmeler önerir, fotoğraf paylaşır

### 3. Sistem Yöneticisi (Admin)
**Demografik**: Platform yöneticisi, içerik moderatörü
**İhtiyaçlar**:
- Kaliteli içerik sağlama
- Platform güvenilirliğini koruma
- Kullanıcı deneyimini optimize etme
**Davranış**: İçerikleri inceler, onaylar/reddeder, kullanıcıları yönetir

## Özellik Listesi ve Öncelikler

### Yüksek Öncelik (MVP)

#### 1. Keşif ve Harita
- **GPS Tabanlı Keşif**: Konum tespiti ile yakındaki güvenilir mekanlar
- **Şehir Bazlı Arama**: Belirli şehirdeki mekanları listeleme
- **Harita Görünümü**: Pin'ler ile mekan konumları (yeşil: onaylı, sarı: beklemede)
- **Mekan Detayı**: Bottom sheet animasyonu ile hızlı bilgi

#### 2. Mekan Bilgileri
- **Temel Bilgiler**: Ad, adres, çalışma saatleri
- **Güven Kriterleri** (`trust_criteria`): Guide'ın işaretlediği, adminin süzdüğü önceden tanımlı kriterler. **Son kullanıcıya GÖSTERİLMEZ** — yalnızca güven rozetine dolaylı katkı sağlar; guide/admin bağlamında görünür.
  - Helal Sertifikası
  - İşletme Sahibinden Teyit
  - Boykot Ürünü Yok
  - Alkolsüz İşletme
  - Temiz ve Bakımlı (öznel gözlem)
  - Yerinde Görüldü
  - Köklü İşletme
- **Fotoğraf Galerisi**: Mekan fotoğrafları
- **Güven Göstergeleri (son kullanıcı)**: Güven rozeti (Temel→Platin) + doğrulayan sayısı cümlesi ("N yerel rehber güvenilir buldu") + son doğrulanma tarihi. Kriter isimleri ve güven skoru gösterilmez.

#### Venue Rozet Sistemi (Dönemsel Doğrulama)

**Rozet seviyeleri** (mevcut periyottaki farklı doğrulayan sayısına göre, ekleyen dahil):

| Sayı | Seviye  |
|------|---------|
| 0    | Temel   |
| 1    | Bronz   |
| 2–5  | Gümüş   |
| 6–10 | Altın   |
| 11+  | Platin  |

**Dağıtık sahiplik modeli:**
- **Silme**: Yalnızca admin silebilir; guide'lar kendi ekledikleri mekanı silemez.
- **Düzenleme**: Guide'lar `correction_suggestions` üzerinden öneri gönderir; admin onaylar.

**Dönemsel tazelik doğrulaması:**
- O şehirdeki herhangi bir onaylı rehber mekanı tazeleyebilir; bir kişinin doğrulaması bile mekanı canlı tutar. Ekleyen ayrıcalıklı değildir — `added_by` yalnızca tarihsel atıftır.
- Her guide'ın onayı periyot başına bir kez geçerlidir.
- Doğrulama kayıtları silinmez; rozet, son periyottaki farklı doğrulayan sayısından (ekleyen dahil) türetilir.

#### 3. Kullanıcı Yönetimi
- **Çoklu Giriş**: Email/şifre, Google
- **Rol Sistemi**: Traveler → Guide → Admin hiyerarşisi
- **Profil Yönetimi**: Kullanıcı bilgileri ve ayarları

### Orta Öncelik

#### 4. Sosyal Özellikler
- **Yorum ve Puanlama**: 1-5 yıldız + metin yorumu
- **Favoriler Sistemi**: Mekanları kaydetme ve listeleme
- **Guide Özellikleri**: Mekan ekleme, düzeltme önerme

#### 5. İçerik Yönetimi
- **Admin Paneli**: Onay süreçleri ve moderasyon
- **Kalite Kontrolü**: Mekan onaylama/reddetme
- **Audit Sistemi**: Admin işlem geçmişi

### Düşük Öncelik (Gelecek Sürümler)

#### 6. Gelişmiş Özellikler
- **Push Bildirimler**: Yeni mekan bildirimleri
- **Gelişmiş Filtreleme**: Mesafe, puan, kategori filtreleri

## Kullanıcı Hikayeleri

### Traveler Hikayeleri
1. **Mekan Keşfi**: "Yeni bir şehirdeyim ve yakınımda helal restoran arıyorum"
2. **Detay İnceleme**: "Bir mekanın ne kadar güvenilir olduğunu (kaç rehberin doğruladığını, ne kadar taze) görmek istiyorum"
3. **Favorileme**: "Beğendiğim mekanları kaydetmek istiyorum"
4. **Yorum Yapma**: "Gittiğim mekan hakkında deneyimimi paylaşmak istiyorum"

### Guide Hikayeleri
1. **Mekan Ekleme**: "Bildiğim güvenilir helal mekanı sisteme eklemek istiyorum"
2. **Fotoğraf Paylaşma**: "Mekanın fotoğraflarını çekerek diğer kullanıcılara yardımcı olmak istiyorum"
3. **Düzeltme Önerme**: "Bir mekanın bilgilerinde hata gördüm ve düzeltmek istiyorum"
4. **Katkı Takibi**: "Eklediğim mekanların durumunu görmek istiyorum"

### Admin Hikayeleri
1. **İçerik Moderasyonu**: "Gelen mekan başvurularını inceleyip onaylamak istiyorum"
2. **Kalite Kontrolü**: "Platformdaki içeriklerin kalitesini sağlamak istiyorum"
3. **Kullanıcı Yönetimi**: "Guide başvurularını değerlendirmek istiyorum"
4. **İşlem Takibi**: "Yaptığım admin işlemlerinin geçmişini görmek istiyorum"

## Rekabet Analizi


### Rekabet Avantajları
- **Uzman Doğrulama**: Guide sistemi ile yerel uzman onayı
- **Dağıtık Güven**: Birden fazla rehberin doğrulamasından türetilen güven rozeti
- **Güven Odaklı**: Helallik dahil çok boyutlu güven kriterlerine odaklı tasarım
- **Yerel Topluluk**: Türkiye'deki Müslüman topluluk odaklı

### Farklılaştırıcı Özellikler
- **Katmanlı Onay Sistemi**: Guide → Admin onay süreci
- **Güven Göstergeleri**: Güven rozeti (dönemsel doğrulayan sayısından türetilir) + son doğrulanma
- **Yerel Rehber Ağı**: Şehir bazlı uzman Guide sistemi
- **Mobil Öncelikli**: Seyahat anında kullanım odaklı tasarım

## Ürün Yol Haritası

## Kullanıcı Deneyimi Prensipleri

### Basitlik
- Minimum adımda mekan bulma
- Sezgisel navigasyon
- Temiz ve odaklanmış arayüz

### Güvenilirlik
- Çoklu doğrulama sistemi
- Şeffaf onay süreci
- Açık güven göstergeleri

### Erişilebilirlik
- Çevrimdışı temel özellikler
- Hızlı yükleme süreleri
- Düşük veri kullanımı

### Topluluk Odaklı
- Kullanıcı katkısını teşvik etme
- Geri bildirim döngüsü
- Sosyal doğrulama mekanizmaları

---

*Bu belge, ürünün işlevsel gereksinimlerini ve kullanıcı deneyimi hedeflerini tanımlar.*