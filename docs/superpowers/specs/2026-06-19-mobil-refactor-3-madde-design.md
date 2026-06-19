# Mobil Refactor — 3 Madde (Tasarım)

> Tarih: 2026-06-19
> Kapsam: (1) Profili zenginleştirme, (2) Yorumlarda anonimliği kaldırma, (3) Demote sonrası takılan rehber başvurusu.
> İlgili: [progress.md](../../progress.md) "mobil" maddeleri.

## Özet

Üç bağımsız UX/davranış düzeltmesi. 1. madde tamamen mobil (backend zaten hazır).
2. ve 3. maddeler kök nedeni backend'de olduğu için hem backend hem mobil değişikliği gerektirir.

---

## Madde 1 — Profili Zenginleştirme

### Mevcut Durum
- `User` modelinde `surname`, `phone`, `avatarUrl` **zaten var** (`mobile/lib/core/models/user.dart`).
- Backend `PUT /auth/profile` **zaten** `name + surname + phone` kabul ediyor
  (`auth_handler.go:142`, `auth_service.go:199`).
- Eksik olan: mobil `edit_profile_screen.dart` sadece `name` gönderiyor;
  `EditProfileNotifier.updateProfile` yalnızca `name` parametresi alıyor.

### Karar
Düzenlenebilir alanlar: **Ad, Soyad, Telefon**. **Email salt-okunur** kalır
(giriş kimliği; özellikle Google/Apple OAuth kullanıcılarında değiştirmek girişi bozabilir).

### Yapılacaklar (sadece mobil)
1. `EditProfileNotifier.updateProfile` → `name`, `surname`, `phone` alır ve gönderir
   (`mobile/lib/features/profile/providers/profile_provider.dart`).
2. `edit_profile_screen.dart`:
   - Soyad `TextFormField` (opsiyonel; girilirse min 2 karakter).
   - Telefon `TextFormField` (opsiyonel; girilirse basit format/uzunluk kontrolü, `keyboardType: phone`).
   - Email `readOnly` kalır (mevcut davranış).
   - Controller'lar `initState`'te mevcut `user.surname` / `user.phone` ile dolar.
3. `_ProfileHeader` (`profile_screen.dart`): ad + soyad birleşik gösterilir
   (`'${user.name} ${user.surname ?? ''}'.trim()`).

### Risk / Test
- Düşük risk; mevcut backend alanlarını kullanıma açıyoruz.
- Doğrulama: `flutter analyze` temiz; manuel olarak soyad/telefon kaydedip prof header'da görünmesi.

---

## Madde 2 — Yorumlarda Anonimliği Kaldırma

### Kök Neden (doğrulandı)
Yorumlar bugün "kısmen anonim" değil, **tamamen anonim**:
- Backend `models.Review` struct'ında isim/avatar alanı **yok** (`backend/internal/models/review.go`).
- `ReviewRepo.ListByVenue` sorgusu `users` tablosuna **join atmıyor**
  (`backend/internal/repository/review_repo.go:20`), sadece `reviews` kolonlarını seçiyor.
- Sonuç: API `user_name` döndürmüyor → mobil `review_card.dart` her zaman `'Anonim'` gösteriyor.

### Karar
Görünen ad formatı: **Ad + Soyad baş harfi** (örn. `Ahmet Y.`).
Birleştirme **backend'de** yapılır → mobil sadece gösterir.

### Yapılacaklar

**Backend:**
1. `models.Review`'a alanlar eklenir:
   - `UserName *string  json:"user_name,omitempty"` (hesaplanmış görünen ad: `Ad S.`)
   - `UserAvatar *string json:"user_avatar,omitempty"`
2. `ReviewRepo.ListByVenue` sorgusu `LEFT JOIN users u ON u.id = r.user_id`;
   `u.name, u.surname, u.avatar_url` çekilir.
3. Görünen ad backend'de üretilir:
   - `name` boş değilse → `name`; `surname` doluysa `+ " " + surname[0] + "."`.
   - `name` boşsa → `"Kullanıcı"` (nötr fallback; pratikte olmaz).
   - Türkçe karakterli baş harf için `[]rune` üzerinden ilk rune alınır, `strings.ToUpper` uygulanır.
4. (Opsiyonel tutarlılık) `FindByID` aynı join'i gerektirmiyor; sadece liste endpoint'i kullanıcıya gösteriliyor.
   Gerekirse aynı pattern uygulanır.

**Mobil:**
1. `review_card.dart`: `review.userName ?? 'Anonim'` → `review.userName ?? 'Kullanıcı'`
   (join sonrası normalde hep dolu gelir; `'Anonim'` metni kaldırılır).
2. Avatar baş harfi zaten `userName`/`?` üzerinden çalışıyor; değişiklik gerekmez.

### Risk / Test
- `LEFT JOIN` kullanılır ki user silinmiş olsa bile yorum kaybolmasın.
- Test: `ListByVenue` integration testi — dönen review'da `user_name` dolu ve `Ad S.` formatında.
- Manuel: bir mekânın yorumlarında gerçek isim + soyad baş harfi görünmeli.

---

## Madde 3 — Demote (rehber→seyyah) Sonrası Takılan Başvuru

### Kök Neden (doğrulandı)
1. Kullanıcı guide olurken `guide_applications`'a kayıt yazılır:
   - Kodlu yol → `status='approved'` (`ReferralRepo.ApproveGuideTx`, `referral_repo.go:95`).
   - Kodsuz yol → `status='pending'`; admin panelden **rol dropdown'u** ile onaylarsa bu satır
     `pending` kalır (yalnızca "başvuruyu onayla" butonu `UpdateStatus` ile approved yapar).
2. Admin demote edince (`AdminHandler.UpdateUser`, `admin_handler.go:378`) rol düşer ve referral
   kodu revoke edilir — ama **`guide_applications` satırı aynen kalır**.
3. Kullanıcı profili açınca `GET /guide/my-application` → `FindLatestByUserID` eski satırı döndürür:
   - `pending` ise → mobil "inceleniyor" gösterir **ve** `HasPendingApplication=true` olduğundan
     yeni kodsuz başvuru **409** alır → çıkmaz sokak (gözlemlenen semptom).
   - `approved` ise → mobil bunu pending/rejected saymaz, forma düşer ama kayıt yine de yanıltıcı durur.

### Karar
**Demote'ta kaydı kapat** (silme değil — audit izi korunur): yeni `cancelled` durumu.

### Yapılacaklar

**Backend:**
1. `models.ApplicationStatus`'a sabit eklenir: `ApplicationStatusCancelled = "cancelled"`.
2. `GuideRepo`'ya metot: `CancelOpenByUserID(ctx, userID) error`
   - `UPDATE guide_applications SET status='cancelled' WHERE user_id=$1 AND status IN ('pending','approved')`.
   - İdempotent; etkilenen satır 0 ise sessizce geçer.
3. `AdminHandler.UpdateUser`: mevcut `prevRole == guide && *req.Role != guide` bloğunun içinde
   (referral revoke'un hemen yanında) `CancelOpenByUserID` çağrılır. Hata loglanır, akış bozulmaz.
4. `MyApplication` davranışı: `FindLatestByUserID` artık en güncel satırı döndürür; demote sonrası
   bu `cancelled` olur. Ek filtre gerekmez (mobil `cancelled`'ı "başvuru yok" gibi ele alır).
   - Not: `HasPendingApplication` zaten yalnızca `status='pending'` sayıyor; `cancelled` sonrası
     yeni başvuru 409 almaz.

**Mobil:**
1. `_GuideApplicationCardState.build` (`profile_screen.dart`):
   - "inceleniyor" kartı yalnızca **gerçek açık** `pending` için gösterilir
     (mevcut `currentStatus == 'pending' || isSuccess` korunur — `cancelled`/`approved` buraya düşmez).
   - `currentStatus`'ın `'cancelled'` (ve eski `'approved'`) olduğu durumda normal başvuru formu gösterilir.
     Mevcut kod zaten yalnızca `pending`/`rejected`'ı özel ele aldığı için `cancelled` doğal olarak forma düşer;
     ek olarak: rejected banner'ına benzer şekilde gerekiyorsa nötr bilgilendirme **eklenmez** (sade form yeter).
2. Davranış doğrulaması: demote edilen kullanıcı profili açtığında "inceleniyor" yerine başvuru formu görür
   ve yeniden başvurabilir.

### Risk / Test
- `cancelled` yeni bir enum değeri. `guide_applications.status` kolonu `VARCHAR(20) NOT NULL DEFAULT 'pending'`
  olup **CHECK constraint yok** (migration 008 doğrulandı), `cancelled` 9 karakter →
  **migration gerekmez**, yalnızca Go sabiti + UPDATE sorgusu yeterli.
- Test: demote integration testi — guide demote edilince açık başvuru `cancelled` olur,
  `HasPendingApplication=false`, kullanıcı yeniden kodsuz başvurabilir.

---

## Uygulama Sırası (bağımsız parçalar)

1. **Madde 1** (mobil-only, en hızlı, risksiz).
2. **Madde 2** (backend join + model + mobil metin).
3. **Madde 3** (backend status + cancel + admin hook + mobil davranış).

Her madde kendi içinde test edilebilir; aralarında bağımlılık yok.

## Kapsam Dışı (YAGNI)
- Avatar yükleme (multipart/storage) — bu turda yok.
- Bio/hakkımda alanı — bu turda yok.
- Email düzenleme — bilinçli olarak salt-okunur.
- Yorum için tam ad gösterimi — "Ad + soyad baş harfi" tercih edildi.
