# Yayın Öncesi Yapılacaklar

**Son güncelleme:** 11 Ağustos 2026

Mağaza yayınına çıkmadan önce kapatılması gereken açıklar. Her madde, neden
gerekli olduğu ve nerede duruyla birlikte yazıldı.

Öncelik sırası: **A** yayını bloklar, **B** yayından önce yapılmalı, **C** sonraya
bırakılabilir.

---

## A — Yayını bloklayanlar

### A1. Alan adı alınmadı

Alan adı hiçbir yerde tanımlı değil; deploy yapılandırması `{$DOMAIN}` değişkeni
üzerinden çalışıyor.

Alan adı alınınca **üç yer** hizalanmalı:

| Yer | Ne |
|---|---|
| `mobile/lib/core/config/legal_links.dart` | `baseUrl` varsayılanı (`TODO(yayın)` işaretli) |
| `deploy/.env` | `DOMAIN` |
| `backend/.env` | `SMTP_FROM` gönderen adresi |

### A2. Yasal metinler yayınlanmadı

Metinler yazıldı (`docs/legal/`) ama **web'de yayınlanmadı**. App Store Connect
ve Google Play Console'da gizlilik politikası URL'si **zorunlu alan** — boş
bırakılamaz.

Yapılacaklar `docs/legal/README.md` içinde adım adım yazılı. Özet:

1. Metinlerdeki yer tutucuları doldur: `[ŞİRKET ADI]`, `[ADRES]`, `[VERGİ NO]`,
   `[TİCARET SİCİL NO]`, `[DESTEK E-POSTA]`, `[YETKİLİ MAHKEME]`, `[VERBİS KAYIT NO]`
2. **Hukuk danışmanına okut** — metinler gerçek veri akışına dayalı sağlam
   taslaklar, ancak hukuki belge niteliğinde
3. `<alan-adı>/gizlilik`, `/kullanim-sartlari`, `/kvkk` adreslerinde yayınla
4. Mağaza listelerine gizlilik politikası URL'sini gir

### A3. SMTP yapılandırması

`SMTP_USER` ve `SMTP_PASSWORD` boş — bu hâlde e-posta gönderimi **devre dışı**
(NoopEmailService) ve şifre sıfırlama kodları yalnızca sunucu loguna düşer.
Kullanıcı şifresini sıfırlayamaz.

Resend önerilir (3.000 mail/ay ücretsiz); ayrıntılar `backend/.env.example`
içinde. `SMTP_FROM` artık zorunlu: SMTP dolu ama FROM boşsa sunucu açılışta
hata verip durur (bilinçli fail-fast).

---

## B — Yayından önce yapılmalı

### B1. Seed hesapları hâlâ eski alan adında

`admin@caizmi.com` ve `rehber@caizmi.com` (migration 013) canlı veritabanında
**gerçekten kullanımda** — 3 mekan eklenmiş, giriş kayıtları var.

Bu yüzden temizlik turunda dokunulmadı: uygulanmış bir migration'ı düzenlemek
yeni kurulumla mevcut veritabanı arasında sapma yaratır.

Yapılması gereken: e-postaları güncelleyen **yeni bir migration**. Karar
gerektiren nokta — bu hesaplarla hâlâ giriş yapılıyor mu, yoksa gerçek admin
hesabına devredilip kapatılabilir mi?

### B2. Firebase'de eski uygulama kayıtları

`google-services.json` **güncel ve doğru** (`com.itimat.itimat` kayıtlı, backend
ile Web client ID'si eşleşiyor — doğrulandı). Ancak aynı Firebase projesinde
`com.caizmi` ve `com.caizmi.caiz_mi` eski kayıtları da duruyor.

Zararsızlar; Firebase konsolundan silinirse dosya sadeleşir. İşlevsel kazanç yok.

### B3. Veritabanı adı ve kullanıcısı

Canlı veritabanı `caizmi` adında, kullanıcı da `caizmi`. Çalışan sistemi
kopartmamak için dokunulmadı.

Değiştirmek isterseniz: dump → yeni adla restore → `DATABASE_URL` güncelle.
Yayın öncesi yapılırsa risk düşük, sonrasında veri taşıma gerektirir. Tamamen
kozmetik bir düzeltme; atlanabilir.

---

## C — İhtiyaç doğunca

### C1. Onay sürümü takibi

Kayıt ekranında kullanım şartları ve KVKK onayı alınıyor, ancak **hangi sürümün
ne zaman onaylandığı kaydedilmiyor**.

Bugün için yeterli. Ancak şartlarda **esaslı bir değişiklik** yapıp (ör. veri
kullanımının genişlemesi) kullanıcıdan yeniden onay istemeniz gerekirse, kimin
neyi kabul ettiğine dair kanıt olmayacak.

Gerektiğinde eklenecek: `users` tablosuna `terms_accepted_version` ve
`terms_accepted_at`, metinlere de bir sürüm numarası. Küçük bir iş; şimdi
yapılmadı çünkü ihtiyaç netleşmeden şema eklemek erken olur.

### C2. Uygulama sürümü elle senkronlanıyor

`mobile/lib/core/config/legal_links.dart` içindeki `appVersion` sabiti,
`pubspec.yaml`'daki `version:` ile **elle** eşit tutulmalı.

`package_info_plus` bağımlılığı eklemek yerine sabit tercih edildi: tek bir metin
için ek paket ve platform kanalı maliyeti gereksiz görüldü. Sürüm yükseltirken
ikisini birlikte güncelleyin.

### C3. Yasal metinler için çoklu dil

Metinler yalnızca Türkçe. Uygulama Türkiye pazarına yönelik olduğu sürece
yeterli; yurt dışına açılırken İngilizce sürüm gerekir.

---

## Tamamlananlar

Bu listeyi bağlama oturtmak için — yayın gereklilikleri arasından kapatılanlar:

- ✅ **Hesap silme** (App Store 5.1.1(v) + Google Play zorunluluğu) —
  anonimleştirme ile; kişisel veri silinir, topluluk katkısı anonim kalır
- ✅ **Yasal metinler yazıldı** — gizlilik, kullanım şartları, KVKK aydınlatma
  (gerçek veri akışına göre; teknik iddialar koda karşı doğrulandı)
- ✅ **Kayıt ekranında onay adımı** — şartlar zorunlu, KVKK açık rızası ayrı ve
  isteğe bağlı (rızanın özgür iradeye dayanması için)
- ✅ **Profilde "Hakkında ve Yasal" bölümü** — üç link + sürüm numarası
- ✅ **Eski alan adı kalıntıları** — `SMTP_FROM` varsayılanı, bucket adları, test
  fixture'ları temizlendi (canlı veriye bağlı olanlar B bölümünde)
