# Notification System — Design Spec
**Tarih:** 2026-05-01  
**Kapsam:** Rehber doğrulama bildirimleri (Guide Verification Notifications)  
**Ertelendi:** Seyyah bildirimleri (Traveler Notifications), FCM push notifications

---

## Özet

Rehberlerin eklediği mekanların helallik güncelliğini korumak için periyodik doğrulama bildirimi sistemi. Her mekânın kendi sayacı vardır; süre dolduğunda rehbere email + uygulama içi bildirim gönderilir. Doğrulama yapılmazsa mekan askıya alınır. Admin panelinde doğrulama log ekranı bulunur.

---

## 1. Veri Modeli

### 1.1 venues — Değişiklikler

```sql
-- Status enum'a ekleme
-- 'pending' | 'approved' | 'rejected' | 'suspended'

ALTER TABLE venues ADD COLUMN verification_due_at TIMESTAMPTZ;
ALTER TABLE venues ADD COLUMN last_notified_at    TIMESTAMPTZ;
```

- `verification_due_at`: Bir sonraki doğrulama tarihi. Mekan onaylandığında `NOW() + VERIFICATION_PERIOD` olarak set edilir. **Migration notu:** Bu sistem devreye alınmadan önce zaten `approved` olan mekanlar için `verification_due_at = approved_at + VERIFICATION_PERIOD` ile doldurulacak.
- `last_notified_at`: Aynı güne tekrar bildirim gitmesini önler.
- `verified_at`: Zaten mevcut — rehber doğruladığında güncellenir.

### 1.2 notifications (yeni tablo)

```sql
CREATE TABLE notifications (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type       VARCHAR(50) NOT NULL,
    -- 'verification_warning' | 'venue_suspended'
    title      VARCHAR(255) NOT NULL,
    body       TEXT NOT NULL,
    data       JSONB,        -- {venue_id, venue_name}
    is_read    BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX notifications_user_idx ON notifications(user_id, is_read, created_at DESC);
```

### 1.3 venue_verification_logs (yeni tablo)

```sql
CREATE TABLE venue_verification_logs (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    venue_id   UUID NOT NULL REFERENCES venues(id),
    guide_id   UUID NOT NULL REFERENCES users(id),
    action     VARCHAR(50) NOT NULL,
    -- 'warning_sent' | 'verified' | 'suspended'
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

---

## 2. Backend Tasarımı

### 2.1 Konfigürasyon (env vars)

```bash
VERIFICATION_PERIOD_DAYS=90         # Doğrulama periyodu (gün)
VERIFICATION_WARNING_DAYS=14        # Kaç gün kala uyarı gönderilir
SCHEDULER_RUN_HOUR=2                # Scheduler'ın çalışacağı saat (02:00)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=noreply@caizmi.com
SMTP_PASS=...
SMTP_FROM=Caiz mi? <noreply@caizmi.com>
```

### 2.2 Scheduler — Akış

Her gece `SCHEDULER_RUN_HOUR`'da çalışır. İki faz:

**Faz 1 — Uyarı**
```sql
SELECT v.*, u.email, u.name
FROM venues v
JOIN users u ON u.id = v.added_by
WHERE v.status = 'approved'
  AND v.verification_due_at < NOW() + INTERVAL '14 days'
  AND v.verification_due_at > NOW()
  AND (v.last_notified_at IS NULL OR v.last_notified_at < NOW() - INTERVAL '1 day')
```
- `notifications` tablosuna `type = 'verification_warning'` kaydı ekle
- Email gönder
- `last_notified_at = NOW()` güncelle
- `venue_verification_logs`'a `action = 'warning_sent'` ekle

**Faz 2 — Askıya Alma**
```sql
SELECT v.*, u.email, u.name
FROM venues v
JOIN users u ON u.id = v.added_by
WHERE v.status = 'approved'
  AND v.verification_due_at < NOW()
```
- `venues.status = 'suspended'` yap
- `notifications` tablosuna `type = 'venue_suspended'` kaydı ekle
- Email gönder
- `venue_verification_logs`'a `action = 'suspended'` ekle

### 2.3 Rehber Doğrulama Akışı

```
PUT /api/v1/venues/:id/verify
Auth: Guide (sadece kendi mekanı)

→ venues.verified_at = NOW()
→ venues.verification_due_at = NOW() + VERIFICATION_PERIOD
→ venues.status = 'approved'  (suspended idiyse geri açılır)
→ venue_verification_logs: action = 'verified'
```

**Not:** Mevcut admin approve akışı (`PUT /admin/venues/:id/approve`) da `verification_due_at = NOW() + VERIFICATION_PERIOD` set etmek üzere güncellenecek.

### 2.4 Servis Yapısı

```
internal/
├── services/
│   ├── notification_service.go   -- DB'ye bildirim yazar + email tetikler
│   ├── email_service.go          -- EmailService interface + SMTP impl
│   └── scheduler_service.go     -- background goroutine, iki faz
├── handlers/
│   ├── notification_handler.go   -- bildirim endpoint'leri
│   └── venue_handler.go          -- PUT /venues/:id/verify eklenir
└── repository/
    ├── notification_repository.go
    └── verification_log_repository.go
```

**EmailService interface** — ileride SendGrid/SES'e geçişi kolaylaştırır:
```go
type EmailService interface {
    Send(to, subject, htmlBody string) error
}
```

### 2.5 Yeni API Endpoint'leri

| Method | Path | Açıklama | Rol |
|---|---|---|---|
| `GET` | `/api/v1/notifications?page=1&limit=20` | Bildirimleri listele (sayfalı) | Any |
| `PUT` | `/api/v1/notifications/:id/read` | Okundu işaretle | Any |
| `PUT` | `/api/v1/notifications/read-all` | Tümünü okundu işaretle | Any |
| `GET` | `/api/v1/notifications/unread-count` | Badge sayısı | Any |
| `PUT` | `/api/v1/venues/:id/verify` | Mekanı doğrula | Guide (sahip) |
| `GET` | `/api/v1/admin/verification-logs` | Admin log sayfası | Admin |
| `PUT` | `/api/v1/admin/venues/:id/reactivate` | Suspended mekanı manuel aç (status=approved + verification_due_at sıfırla) | Admin |

---

## 3. Flutter UI

### 3.1 AppHeader Değişikliği

`shared/widgets/app_header.dart` — mevcut: `Logo | Konum | ❤️`  
Yeni: `Logo | Konum | 🔔 (unread badge) | ❤️`

- Zil ikonu sadece giriş yapan kullanıcılara görünür
- Okunmamış bildirim varsa kırmızı badge gösterilir
- Tıklayınca `/notifications` rotasına yönlendirir

### 3.2 Bildirim Merkezi

```
features/notifications/
├── notifications_screen.dart       -- liste ekranı
├── notification_item_widget.dart   -- tek satır widget
└── notifications_provider.dart    -- Riverpod provider
```

- Pull-to-refresh
- Tıklayınca ilgili mekan detayına yönlendirir + okundu işaretler
- Boş state: "Henüz bildiriminiz yok"

### 3.3 Mekan Doğrulama Butonu

`venue_detail_screen.dart`'a eklenir. Görünüm koşulları:
- Kullanıcı bu mekanın sahibi olan guide olmalı
- Mekan status'u `approved` veya `suspended` olmalı

```
"Bu mekanın hâlâ helal kriterlerini karşıladığını onaylıyorum"
[ Doğrula ]
```

Confirmation dialog → `PUT /venues/:id/verify` → başarıda Snackbar.

### 3.4 Admin Doğrulama Log Ekranı

Rota: `/admin/verification-logs`  
`features/admin/screens/verification_logs_screen.dart`

3 sekme (TabBar):

| Sekme | Filtre |
|---|---|
| Son Doğrulamalar | `action = 'verified'`, en yeni üstte |
| Askıya Alınanlar | `venues.status = 'suspended'` |
| Yaklaşan Süre Bitişi | `verification_due_at < NOW() + 30 gün` |

Her satır: mekan adı, rehber adı, şehir, tarih, aksiyon badge.  
"Askıya Alınanlar" sekmesinde admin için **"Yeniden Aktive Et"** butonu.

---

## 4. Email Şablonları

### Uyarı Emaili (14 gün kala)
```
Konu: [Caiz mi?] "Köfte Salonu" için doğrulama zamanı yaklaşıyor

Merhaba Ahmet Bey,

Eklediğiniz "Köfte Salonu" mekanının doğrulama süresi 14 gün içinde dolacak.
Mekanın hâlâ helal kriterlerini karşıladığını uygulamadan teyit etmenizi rica ederiz.

Doğrulamayı yapmazsanız mekan 14 gün sonra askıya alınacaktır.

Uygulamayı açın → Mekanlarım → Köfte Salonu → Doğrula
```

### Askıya Alma Emaili
```
Konu: [Caiz mi?] "Köfte Salonu" askıya alındı

Merhaba Ahmet Bey,

"Köfte Salonu" mekanı doğrulama yapılmadığı için askıya alınmıştır.
Mekan artık diğer kullanıcılara gösterilmemektedir.

Doğrulamayı tamamlarsanız mekan otomatik olarak yeniden aktif olur.
```

---

## 5. Ertelenen Özellikler

- **FCM Push Notifications:** Şimdilik DB-driven in-app + email yeterli. `EmailService` interface'i sayesinde ileride FCM entegrasyonu tek bir yeni implementasyon gerektirir.
- **Seyyah Bildirimleri:** "Konuma yakın yeni mekan" bildirimi sonraki iterasyona bırakıldı.
