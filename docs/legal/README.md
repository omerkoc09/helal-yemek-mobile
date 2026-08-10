# Yasal Metinler

Uygulamanın gizlilik politikası, kullanım şartları ve KVKK aydınlatma metni.

## Neden burada, uygulamada değil

Metinler uygulamaya **gömülmez**, web'de barındırılır:

1. Apple ve Google, mağaza listesinde gizlilik politikası için bir **URL** ister.
   Uygulama içi ekran bu şartı karşılamaz — adres zaten var olmak zorunda.
2. Metin değişince uygulama güncellemesi ve mağaza incelemesi gerekmez.

CRUD/admin paneli **bilinçli olarak yapılmadı**: bu metinler yılda bir-iki kez
değişir, altyapı maliyeti faydasını aşardı. Sık değişen çok dilli içerik ihtiyacı
doğarsa yeniden değerlendirilebilir.

## Yayın öncesi yapılacaklar

**1. Yer tutucuları doldurun.** Üç dosyada da `[KÖŞELİ PARANTEZ]` içinde işaretli:

- `[ŞİRKET ADI]`, `[ADRES]`, `[VERGİ NO]`, `[TİCARET SİCİL NO]`
- `[YETKİLİ MAHKEME]` (kullanım şartları, bölüm 11)
- `[VERBİS KAYIT NO]` — kayıt yükümlülüğünüz varsa

**2. Hukuk danışmanına okutun.** Bu metinler gerçek veri akışına dayalı sağlam
birer taslaktır, ancak hukuki belge niteliğindedir. Özellikle veri sorumlusu
kimliği, saklama süreleri ve VERBİS yükümlülüğü ticari yapınıza bağlıdır.

**3. Şu adreslerde yayınlayın** (mobil uygulama bu adresleri açar):

| Dosya | Adres |
|---|---|
| `gizlilik-politikasi.md` | `https://caizmi.com/gizlilik` |
| `kullanim-sartlari.md` | `https://caizmi.com/kullanim-sartlari` |
| `kvkk-aydinlatma-metni.md` | `https://caizmi.com/kvkk` |

Adresler `mobile/lib/core/config/legal_links.dart` içinde tanımlı. Farklı bir
alan adı kullanacaksanız orayı güncelleyin ya da derlemede geçin:

```
flutter build apk --dart-define=LEGAL_BASE_URL=https://ornek.com
```

**4. Mağaza listelerine gizlilik politikası URL'sini girin** (App Store Connect
ve Google Play Console'da zorunlu alan).

## Metin güncellenirse

Uygulamada değişiklik gerekmez — web sayfasını güncellemek yeterli. Yalnızca
**esaslı** değişikliklerde (ör. veri kullanımının genişlemesi) kullanıcıya
yeniden onay sunulması gerekebilir; o durumda `users` tablosuna kabul edilen
sürümü tutan bir alan eklemek gerekir. Şu an böyle bir alan yok, ihtiyaç
doğduğunda eklenebilir.
