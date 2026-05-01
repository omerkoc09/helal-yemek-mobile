# Notification System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Periyodik rehber doğrulama bildirimi sistemi — email + DB-driven in-app notification, arka plan scheduler, admin log ekranı.

**Architecture:** Go backend'de background goroutine her gece 02:00'de süresi yaklaşan/dolan mekanları bulur, `notifications` tablosuna yazar ve SMTP email gönderir. Flutter tarafında AppHeader'a bildirim ikonu + ayrı bir bildirim ekranı eklenir. Rehber kendi mekan detay ekranından doğrulama yapabilir.

**Tech Stack:** Go + Fiber, PostgreSQL, net/smtp (stdlib), Flutter + Riverpod + freezed

---

## Dosya Haritası

### Backend — Yeni dosyalar
| Dosya | Sorumluluk |
|---|---|
| `backend/internal/database/migrations/023_notification_system.up.sql` | venues yeni kolonlar + notifications + venue_verification_logs tabloları |
| `backend/internal/database/migrations/023_notification_system.down.sql` | Geri alma |
| `backend/internal/models/notification.go` | Notification + VerificationLog Go struct'ları |
| `backend/internal/repository/notification_repo.go` | notifications CRUD |
| `backend/internal/repository/verification_log_repo.go` | venue_verification_logs CRUD + admin queries |
| `backend/internal/services/email_service.go` | EmailService interface + SMTPEmailService impl |
| `backend/internal/services/notification_service.go` | DB kaydı + email tetikleme |
| `backend/internal/services/scheduler_service.go` | Background goroutine, iki faz |
| `backend/internal/handlers/notification_handler.go` | Bildirim endpoint'leri |

### Backend — Değiştirilen dosyalar
| Dosya | Değişiklik |
|---|---|
| `backend/internal/config/config.go` | SMTP + scheduler env var'ları |
| `backend/internal/models/venue.go` | VenueStatus'a `suspended` ekleme |
| `backend/internal/repository/venue_status_repo.go` | `Approve`'a `verification_due_at` ekleme; yeni `SuspendForVerification` + `VerifyByGuide` + `Reactivate` fonksiyonları |
| `backend/internal/handlers/venue_handler.go` | `Verify` metodu ekleme |
| `backend/internal/handlers/admin_handler.go` | `VerificationLogs` + `ReactivateVenue` metodları |
| `backend/cmd/api/main.go` | Yeni repo/servis/handler wiring + route'lar |

### Flutter — Yeni dosyalar
| Dosya | Sorumluluk |
|---|---|
| `mobile/lib/core/models/notification_model.dart` | Notification freezed model |
| `mobile/lib/features/notifications/providers/notification_provider.dart` | Riverpod state |
| `mobile/lib/features/notifications/screens/notifications_screen.dart` | Bildirim listesi ekranı |
| `mobile/lib/features/admin/screens/verification_logs_screen.dart` | Admin log ekranı (3 sekme) |

### Flutter — Değiştirilen dosyalar
| Dosya | Değişiklik |
|---|---|
| `mobile/lib/core/api/api_endpoints.dart` | Yeni endpoint sabitleri |
| `mobile/lib/shared/widgets/app_header.dart` | Zil ikonu + badge |
| `mobile/lib/features/venue/screens/venue_detail_screen.dart` | Rehber doğrulama butonu |
| `mobile/lib/core/router/app_router.dart` | `/notifications` + `/admin/verification-logs` route'ları |

---

## Task 1: DB Migration

**Files:**
- Create: `backend/internal/database/migrations/023_notification_system.up.sql`
- Create: `backend/internal/database/migrations/023_notification_system.down.sql`

- [ ] **Step 1: up.sql dosyasını oluştur**

```sql
-- venues tablosuna yeni kolonlar
ALTER TABLE venues
  ADD COLUMN IF NOT EXISTS verification_due_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS last_notified_at    TIMESTAMPTZ;

-- Mevcut approved mekanlar için verification_due_at'ı doldur
UPDATE venues
SET verification_due_at = created_at + INTERVAL '90 days'
WHERE status = 'approved' AND verification_due_at IS NULL;

-- notifications tablosu
CREATE TABLE IF NOT EXISTS notifications (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type       VARCHAR(50) NOT NULL,
    title      VARCHAR(255) NOT NULL,
    body       TEXT NOT NULL,
    data       JSONB,
    is_read    BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS notifications_user_idx
    ON notifications(user_id, is_read, created_at DESC);

-- venue_verification_logs tablosu
CREATE TABLE IF NOT EXISTS venue_verification_logs (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    venue_id   UUID NOT NULL REFERENCES venues(id),
    guide_id   UUID NOT NULL REFERENCES users(id),
    action     VARCHAR(50) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS vvl_venue_idx ON venue_verification_logs(venue_id);
CREATE INDEX IF NOT EXISTS vvl_action_idx ON venue_verification_logs(action, created_at DESC);
```

- [ ] **Step 2: down.sql dosyasını oluştur**

```sql
DROP TABLE IF EXISTS venue_verification_logs;
DROP TABLE IF EXISTS notifications;

ALTER TABLE venues
  DROP COLUMN IF EXISTS verification_due_at,
  DROP COLUMN IF EXISTS last_notified_at;
```

- [ ] **Step 3: Migration'ın çalıştığını doğrula**

```bash
cd backend
go run cmd/api/main.go
# Beklenen: "migration'lar başarıyla çalıştırıldı" log satırı
# Sonra Ctrl+C ile kapat
```

- [ ] **Step 4: Commit**

```bash
git add backend/internal/database/migrations/023_notification_system.up.sql \
        backend/internal/database/migrations/023_notification_system.down.sql
git commit -m "feat: add notification system db migration"
```

---

## Task 2: Config Güncelleme

**Files:**
- Modify: `backend/internal/config/config.go`

- [ ] **Step 1: Config struct ve Load fonksiyonunu güncelle**

`config.go` dosyasındaki `Config` struct'ını şu şekilde değiştir:

```go
type Config struct {
	DatabaseURL      string
	JWTSecret        string
	Port             string
	StorageURL       string
	StorageBucket    string
	GoogleClientID   string
	GoogleMapsAPIKey string

	// SMTP
	SMTPHost     string
	SMTPPort     string
	SMTPUser     string
	SMTPPassword string
	SMTPFrom     string

	// Scheduler
	VerificationPeriodDays  int
	VerificationWarningDays int
	SchedulerRunHour        int
}
```

`Load()` fonksiyonundaki return ifadesini şu şekilde güncelle:

```go
func Load() *Config {
	_ = godotenv.Load()
	return &Config{
		DatabaseURL:      os.Getenv("DATABASE_URL"),
		JWTSecret:        os.Getenv("JWT_SECRET"),
		Port:             getEnv("PORT", "8080"),
		StorageURL:       os.Getenv("STORAGE_URL"),
		StorageBucket:    os.Getenv("STORAGE_BUCKET"),
		GoogleClientID:   os.Getenv("GOOGLE_CLIENT_ID"),
		GoogleMapsAPIKey: os.Getenv("GOOGLE_MAPS_API_KEY"),

		SMTPHost:     getEnv("SMTP_HOST", "smtp.gmail.com"),
		SMTPPort:     getEnv("SMTP_PORT", "587"),
		SMTPUser:     os.Getenv("SMTP_USER"),
		SMTPPassword: os.Getenv("SMTP_PASSWORD"),
		SMTPFrom:     getEnv("SMTP_FROM", "Caiz mi? <noreply@caizmi.com>"),

		VerificationPeriodDays:  getEnvInt("VERIFICATION_PERIOD_DAYS", 90),
		VerificationWarningDays: getEnvInt("VERIFICATION_WARNING_DAYS", 14),
		SchedulerRunHour:        getEnvInt("SCHEDULER_RUN_HOUR", 2),
	}
}
```

Aynı dosyaya `getEnvInt` yardımcı fonksiyonu ekle:

```go
func getEnvInt(key string, fallback int) int {
	if v := os.Getenv(key); v != "" {
		if i, err := strconv.Atoi(v); err == nil {
			return i
		}
	}
	return fallback
}
```

Import'a `"strconv"` ekle.

- [ ] **Step 2: Derlemeyi doğrula**

```bash
cd backend && go build ./...
# Beklenen: hata yok
```

- [ ] **Step 3: Commit**

```bash
git add backend/internal/config/config.go
git commit -m "feat: add smtp and scheduler config"
```

---

## Task 3: Go Modelleri

**Files:**
- Modify: `backend/internal/models/venue.go`
- Create: `backend/internal/models/notification.go`

- [ ] **Step 1: venue.go'da VenueStatus'a suspended ekle**

`venue.go` dosyasındaki const bloğunu şu şekilde değiştir:

```go
const (
	VenueStatusPending   VenueStatus = "pending"
	VenueStatusApproved  VenueStatus = "approved"
	VenueStatusRejected  VenueStatus = "rejected"
	VenueStatusSuspended VenueStatus = "suspended"
)
```

`Venue` struct'ına `VerificationDueAt` ve `LastNotifiedAt` alanlarını ekle (mevcut `VerifiedAt` satırının altına):

```go
VerifiedAt          *time.Time      `json:"verified_at,omitempty"`
VerificationDueAt   *time.Time      `json:"verification_due_at,omitempty"`
LastNotifiedAt      *time.Time      `json:"last_notified_at,omitempty"`
```

- [ ] **Step 2: notification.go dosyasını oluştur**

```go
package models

import "time"

type NotificationType string

const (
	NotificationTypeVerificationWarning NotificationType = "verification_warning"
	NotificationTypeVenueSuspended      NotificationType = "venue_suspended"
)

type Notification struct {
	ID        string           `json:"id"`
	UserID    string           `json:"user_id"`
	Type      NotificationType `json:"type"`
	Title     string           `json:"title"`
	Body      string           `json:"body"`
	Data      map[string]string `json:"data,omitempty"`
	IsRead    bool             `json:"is_read"`
	CreatedAt time.Time        `json:"created_at"`
}

type VerificationLog struct {
	ID        string    `json:"id"`
	VenueID   string    `json:"venue_id"`
	VenueName string    `json:"venue_name,omitempty"`
	GuideID   string    `json:"guide_id"`
	GuideName string    `json:"guide_name,omitempty"`
	City      string    `json:"city,omitempty"`
	Action    string    `json:"action"`
	CreatedAt time.Time `json:"created_at"`
}

// VenueForScheduler — scheduler'ın ihtiyaç duyduğu minimal venue bilgisi.
type VenueForScheduler struct {
	ID                 string
	Name               string
	AddedBy            string
	GuideEmail         string
	GuideName          string
	VerificationDueAt  *time.Time
}
```

- [ ] **Step 3: Derlemeyi doğrula**

```bash
cd backend && go build ./...
# Beklenen: hata yok
```

- [ ] **Step 4: Commit**

```bash
git add backend/internal/models/venue.go \
        backend/internal/models/notification.go
git commit -m "feat: add notification and verification log models"
```

---

## Task 4: Notification Repository

**Files:**
- Create: `backend/internal/repository/notification_repo.go`

- [ ] **Step 1: notification_repo.go oluştur**

```go
package repository

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/omerkoc/caiz-mi/internal/models"
)

type NotificationRepo struct {
	db *pgxpool.Pool
}

func NewNotificationRepo(db *pgxpool.Pool) *NotificationRepo {
	return &NotificationRepo{db: db}
}

func (r *NotificationRepo) Create(ctx context.Context, n *models.Notification) error {
	return r.db.QueryRow(ctx,
		`INSERT INTO notifications (user_id, type, title, body, data)
		 VALUES ($1, $2, $3, $4, $5)
		 RETURNING id, created_at`,
		n.UserID, n.Type, n.Title, n.Body, n.Data,
	).Scan(&n.ID, &n.CreatedAt)
}

func (r *NotificationRepo) ListByUserID(ctx context.Context, userID string, limit, offset int) ([]*models.Notification, error) {
	rows, err := r.db.Query(ctx,
		`SELECT id, user_id, type, title, body, data, is_read, created_at
		 FROM notifications
		 WHERE user_id = $1
		 ORDER BY created_at DESC
		 LIMIT $2 OFFSET $3`,
		userID, limit, offset,
	)
	if err != nil {
		return nil, fmt.Errorf("bildirimler listelenemedi: %w", err)
	}
	defer rows.Close()

	var result []*models.Notification
	for rows.Next() {
		n := &models.Notification{}
		if err := rows.Scan(&n.ID, &n.UserID, &n.Type, &n.Title, &n.Body, &n.Data, &n.IsRead, &n.CreatedAt); err != nil {
			return nil, err
		}
		result = append(result, n)
	}
	return result, rows.Err()
}

func (r *NotificationRepo) UnreadCount(ctx context.Context, userID string) (int, error) {
	var count int
	err := r.db.QueryRow(ctx,
		`SELECT COUNT(*) FROM notifications WHERE user_id = $1 AND is_read = false`,
		userID,
	).Scan(&count)
	return count, err
}

func (r *NotificationRepo) MarkRead(ctx context.Context, id, userID string) error {
	result, err := r.db.Exec(ctx,
		`UPDATE notifications SET is_read = true WHERE id = $1 AND user_id = $2`,
		id, userID,
	)
	if err != nil {
		return fmt.Errorf("bildirim güncellenemedi: %w", err)
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (r *NotificationRepo) MarkAllRead(ctx context.Context, userID string) error {
	_, err := r.db.Exec(ctx,
		`UPDATE notifications SET is_read = true WHERE user_id = $1 AND is_read = false`,
		userID,
	)
	return err
}
```

- [ ] **Step 2: Derlemeyi doğrula**

```bash
cd backend && go build ./...
```

- [ ] **Step 3: Commit**

```bash
git add backend/internal/repository/notification_repo.go
git commit -m "feat: add notification repository"
```

---

## Task 5: Verification Log Repository

**Files:**
- Create: `backend/internal/repository/verification_log_repo.go`

- [ ] **Step 1: verification_log_repo.go oluştur**

```go
package repository

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/omerkoc/caiz-mi/internal/models"
)

type VerificationLogRepo struct {
	db *pgxpool.Pool
}

func NewVerificationLogRepo(db *pgxpool.Pool) *VerificationLogRepo {
	return &VerificationLogRepo{db: db}
}

func (r *VerificationLogRepo) Create(ctx context.Context, venueID, guideID, action string) error {
	_, err := r.db.Exec(ctx,
		`INSERT INTO venue_verification_logs (venue_id, guide_id, action) VALUES ($1, $2, $3)`,
		venueID, guideID, action,
	)
	return err
}

// ListVerified — son doğrulanan mekanlar (action='verified')
func (r *VerificationLogRepo) ListVerified(ctx context.Context, limit, offset int) ([]*models.VerificationLog, error) {
	return r.queryLogs(ctx,
		`SELECT vl.id, vl.venue_id, v.name, vl.guide_id, u.name, v.city, vl.action, vl.created_at
		 FROM venue_verification_logs vl
		 JOIN venues v ON v.id = vl.venue_id
		 JOIN users u ON u.id = vl.guide_id
		 WHERE vl.action = 'verified'
		 ORDER BY vl.created_at DESC
		 LIMIT $1 OFFSET $2`,
		limit, offset,
	)
}

// ListSuspended — askıdaki mekanlar
func (r *VerificationLogRepo) ListSuspended(ctx context.Context) ([]*models.VerificationLog, error) {
	return r.queryLogs(ctx,
		`SELECT vl.id, vl.venue_id, v.name, vl.guide_id, u.name, v.city, vl.action, vl.created_at
		 FROM venue_verification_logs vl
		 JOIN venues v ON v.id = vl.venue_id
		 JOIN users u ON u.id = vl.guide_id
		 WHERE v.status = 'suspended'
		 ORDER BY vl.created_at DESC`,
	)
}

// ListUpcoming — yaklaşan süresi bitenler (sonraki X gün içinde)
func (r *VerificationLogRepo) ListUpcoming(ctx context.Context, withinDays int) ([]*models.VerificationLog, error) {
	rows, err := r.db.Query(ctx,
		`SELECT vl.id, vl.venue_id, v.name, vl.guide_id, u.name, v.city, vl.action, vl.created_at
		 FROM venues v
		 JOIN users u ON u.id = v.added_by
		 LEFT JOIN LATERAL (
		   SELECT id, guide_id, action, created_at
		   FROM venue_verification_logs
		   WHERE venue_id = v.id
		   ORDER BY created_at DESC
		   LIMIT 1
		 ) vl ON true
		 WHERE v.status = 'approved'
		   AND v.verification_due_at < NOW() + ($1 * INTERVAL '1 day')
		   AND v.verification_due_at > NOW()
		 ORDER BY v.verification_due_at ASC`,
		withinDays,
	)
	if err != nil {
		return nil, fmt.Errorf("yaklaşan doğrulamalar listelenemedi: %w", err)
	}
	defer rows.Close()
	return scanLogs(rows)
}

func (r *VerificationLogRepo) queryLogs(ctx context.Context, query string, args ...any) ([]*models.VerificationLog, error) {
	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("log sorgusu başarısız: %w", err)
	}
	defer rows.Close()
	return scanLogs(rows)
}

func scanLogs(rows interface {
	Next() bool
	Scan(...any) error
	Err() error
}) ([]*models.VerificationLog, error) {
	var result []*models.VerificationLog
	for rows.Next() {
		l := &models.VerificationLog{}
		if err := rows.Scan(&l.ID, &l.VenueID, &l.VenueName, &l.GuideID, &l.GuideName, &l.City, &l.Action, &l.CreatedAt); err != nil {
			return nil, err
		}
		result = append(result, l)
	}
	return result, rows.Err()
}
```

- [ ] **Step 2: Derlemeyi doğrula**

```bash
cd backend && go build ./...
```

- [ ] **Step 3: Commit**

```bash
git add backend/internal/repository/verification_log_repo.go
git commit -m "feat: add verification log repository"
```

---

## Task 6: Email Service

**Files:**
- Create: `backend/internal/services/email_service.go`

- [ ] **Step 1: email_service.go oluştur**

```go
package services

import (
	"crypto/tls"
	"fmt"
	"net"
	"net/smtp"
	"strings"
)

type EmailService interface {
	Send(to, subject, htmlBody string) error
}

type SMTPEmailService struct {
	host     string
	port     string
	user     string
	password string
	from     string
}

func NewSMTPEmailService(host, port, user, password, from string) *SMTPEmailService {
	return &SMTPEmailService{host: host, port: port, user: user, password: password, from: from}
}

func (s *SMTPEmailService) Send(to, subject, htmlBody string) error {
	auth := smtp.PlainAuth("", s.user, s.password, s.host)

	headers := strings.Join([]string{
		"From: " + s.from,
		"To: " + to,
		"Subject: " + subject,
		"MIME-Version: 1.0",
		"Content-Type: text/html; charset=UTF-8",
	}, "\r\n")
	msg := headers + "\r\n\r\n" + htmlBody

	addr := net.JoinHostPort(s.host, s.port)

	tlsConfig := &tls.Config{ServerName: s.host}
	conn, err := tls.Dial("tcp", addr, tlsConfig)
	if err != nil {
		// TLS başarısız olursa STARTTLS dene
		return smtp.SendMail(addr, auth, s.user, []string{to}, []byte(msg))
	}
	defer conn.Close()

	client, err := smtp.NewClient(conn, s.host)
	if err != nil {
		return fmt.Errorf("smtp client oluşturulamadı: %w", err)
	}
	defer client.Close()

	if err = client.Auth(auth); err != nil {
		return fmt.Errorf("smtp auth başarısız: %w", err)
	}
	if err = client.Mail(s.user); err != nil {
		return err
	}
	if err = client.Rcpt(to); err != nil {
		return err
	}
	w, err := client.Data()
	if err != nil {
		return err
	}
	_, err = fmt.Fprint(w, msg)
	if err != nil {
		return err
	}
	return w.Close()
}

// NoopEmailService — test ve geliştirme ortamı için email göndermeden loglar.
type NoopEmailService struct{}

func NewNoopEmailService() *NoopEmailService { return &NoopEmailService{} }

func (s *NoopEmailService) Send(to, subject, _ string) error {
	fmt.Printf("[EMAIL NOOP] To: %s | Subject: %s\n", to, subject)
	return nil
}
```

- [ ] **Step 2: Derlemeyi doğrula**

```bash
cd backend && go build ./...
```

- [ ] **Step 3: Commit**

```bash
git add backend/internal/services/email_service.go
git commit -m "feat: add smtp email service"
```

---

## Task 7: Notification Service

**Files:**
- Create: `backend/internal/services/notification_service.go`

- [ ] **Step 1: notification_service.go oluştur**

```go
package services

import (
	"context"
	"fmt"

	"github.com/omerkoc/caiz-mi/internal/models"
	"github.com/omerkoc/caiz-mi/internal/repository"
)

type NotificationService struct {
	notifRepo *repository.NotificationRepo
	email     EmailService
}

func NewNotificationService(notifRepo *repository.NotificationRepo, email EmailService) *NotificationService {
	return &NotificationService{notifRepo: notifRepo, email: email}
}

// SendVerificationWarning — 14 gün kala uyarı: DB kaydı + email.
func (s *NotificationService) SendVerificationWarning(ctx context.Context, v *models.VenueForScheduler) error {
	n := &models.Notification{
		UserID: v.AddedBy,
		Type:   models.NotificationTypeVerificationWarning,
		Title:  fmt.Sprintf(""%s" için doğrulama zamanı yaklaşıyor", v.Name),
		Body:   fmt.Sprintf(""%s" mekanının doğrulama süresi yakında dolacak. Lütfen uygulamadan onaylayın.", v.Name),
		Data:   map[string]string{"venue_id": v.ID, "venue_name": v.Name},
	}
	if err := s.notifRepo.Create(ctx, n); err != nil {
		return fmt.Errorf("uyarı bildirimi kaydedilemedi: %w", err)
	}

	htmlBody := warningEmailHTML(v.GuideName, v.Name)
	_ = s.email.Send(v.GuideEmail, n.Title, htmlBody) // email hatası scheduler'ı durdurmaz
	return nil
}

// SendSuspensionNotice — mekan askıya alındı: DB kaydı + email.
func (s *NotificationService) SendSuspensionNotice(ctx context.Context, v *models.VenueForScheduler) error {
	n := &models.Notification{
		UserID: v.AddedBy,
		Type:   models.NotificationTypeVenueSuspended,
		Title:  fmt.Sprintf(""%s" askıya alındı", v.Name),
		Body:   fmt.Sprintf(""%s" mekanı doğrulama yapılmadığı için askıya alındı. Uygulamadan doğrulayarak yeniden aktif edebilirsiniz.", v.Name),
		Data:   map[string]string{"venue_id": v.ID, "venue_name": v.Name},
	}
	if err := s.notifRepo.Create(ctx, n); err != nil {
		return fmt.Errorf("askıya alma bildirimi kaydedilemedi: %w", err)
	}

	htmlBody := suspensionEmailHTML(v.GuideName, v.Name)
	_ = s.email.Send(v.GuideEmail, n.Title, htmlBody)
	return nil
}

func warningEmailHTML(guideName, venueName string) string {
	return fmt.Sprintf(`<!DOCTYPE html><html><body>
<p>Merhaba %s,</p>
<p>Eklediğiniz <strong>"%s"</strong> mekanının doğrulama süresi <strong>14 gün içinde</strong> dolacak.</p>
<p>Mekanın hâlâ helal kriterlerini karşıladığını uygulamadan teyit etmenizi rica ederiz.</p>
<p>Doğrulamayı yapmazsanız mekan 14 gün sonra askıya alınacaktır.</p>
<p>Uygulamayı açın → Mekan Detayı → Doğrula</p>
<br><p>— Caiz mi? ekibi</p>
</body></html>`, guideName, venueName)
}

func suspensionEmailHTML(guideName, venueName string) string {
	return fmt.Sprintf(`<!DOCTYPE html><html><body>
<p>Merhaba %s,</p>
<p><strong>"%s"</strong> mekanı doğrulama yapılmadığı için <strong>askıya alınmıştır</strong>.</p>
<p>Mekan artık diğer kullanıcılara gösterilmemektedir.</p>
<p>Uygulamayı açıp doğrulamayı tamamlarsanız mekan otomatik olarak yeniden aktif olur.</p>
<br><p>— Caiz mi? ekibi</p>
</body></html>`, guideName, venueName)
}
```

- [ ] **Step 2: Derlemeyi doğrula**

```bash
cd backend && go build ./...
```

- [ ] **Step 3: Commit**

```bash
git add backend/internal/services/notification_service.go
git commit -m "feat: add notification service with email templates"
```

---

## Task 8: VenueRepo Güncelleme — Scheduler Sorguları

**Files:**
- Modify: `backend/internal/repository/venue_status_repo.go`

- [ ] **Step 1: Approve fonksiyonunu güncelle — verification_due_at ekle**

`venue_status_repo.go` dosyasındaki `Approve` fonksiyonunu şu şekilde değiştir (periodDays parametresi ekle):

```go
// Approve — mekanı onaylar ve ilk doğrulama süresini başlatır.
func (r *VenueRepo) Approve(ctx context.Context, id, adminID string, periodDays int) error {
	result, err := r.db.Exec(ctx,
		`UPDATE venues
		 SET status = 'approved',
		     approved_by = $1,
		     verified_at = NOW(),
		     verification_due_at = NOW() + ($3 * INTERVAL '1 day'),
		     updated_at = NOW()
		 WHERE id = $2 AND status IN ('pending', 'rejected') AND deleted_at IS NULL`,
		adminID, id, periodDays,
	)
	if err != nil {
		return fmt.Errorf("mekan onaylama başarısız: %w", err)
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}
```

- [ ] **Step 2: SuspendForVerification fonksiyonunu ekle**

`Reject` fonksiyonunun altına ekle:

```go
// SuspendForVerification — doğrulama yapılmadığı için mekânı askıya alır.
func (r *VenueRepo) SuspendForVerification(ctx context.Context, id string) error {
	result, err := r.db.Exec(ctx,
		`UPDATE venues
		 SET status = 'suspended',
		     updated_at = NOW()
		 WHERE id = $1 AND status = 'approved' AND deleted_at IS NULL`,
		id,
	)
	if err != nil {
		return fmt.Errorf("mekan askıya alma başarısız: %w", err)
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// VerifyByGuide — rehberin kendi mekanını doğrulaması.
// Sadece mekan sahibi guide çağırabilir.
func (r *VenueRepo) VerifyByGuide(ctx context.Context, venueID, guideID string, periodDays int) error {
	result, err := r.db.Exec(ctx,
		`UPDATE venues
		 SET verified_at = NOW(),
		     verification_due_at = NOW() + ($3 * INTERVAL '1 day'),
		     status = 'approved',
		     updated_at = NOW()
		 WHERE id = $1
		   AND added_by = $2
		   AND status IN ('approved', 'suspended')
		   AND deleted_at IS NULL`,
		venueID, guideID, periodDays,
	)
	if err != nil {
		return fmt.Errorf("mekan doğrulama başarısız: %w", err)
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// ReactivateVenue — admin'in suspended mekânı manuel olarak yeniden açması.
func (r *VenueRepo) ReactivateVenue(ctx context.Context, id string, periodDays int) error {
	result, err := r.db.Exec(ctx,
		`UPDATE venues
		 SET status = 'approved',
		     verified_at = NOW(),
		     verification_due_at = NOW() + ($2 * INTERVAL '1 day'),
		     updated_at = NOW()
		 WHERE id = $1 AND status = 'suspended' AND deleted_at IS NULL`,
		id, periodDays,
	)
	if err != nil {
		return fmt.Errorf("mekan yeniden aktive edilemedi: %w", err)
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}
```

- [ ] **Step 3: Scheduler'ın kullanacağı sorgu fonksiyonlarını ekle**

Dosyanın sonuna ekle:

```go
// FindDueForWarning — verilen gün sayısı içinde süresi dolacak ve henüz bugün bildirilmemiş mekanlar.
func (r *VenueRepo) FindDueForWarning(ctx context.Context, withinDays int) ([]*models.VenueForScheduler, error) {
	rows, err := r.db.Query(ctx,
		`SELECT v.id, v.name, v.added_by, u.email, u.name, v.verification_due_at
		 FROM venues v
		 JOIN users u ON u.id = v.added_by
		 WHERE v.status = 'approved'
		   AND v.verification_due_at < NOW() + ($1 * INTERVAL '1 day')
		   AND v.verification_due_at > NOW()
		   AND (v.last_notified_at IS NULL OR v.last_notified_at < NOW() - INTERVAL '1 day')`,
		withinDays,
	)
	if err != nil {
		return nil, fmt.Errorf("uyarı listesi alınamadı: %w", err)
	}
	defer rows.Close()
	return scanVenuesForScheduler(rows)
}

// FindDueForSuspension — süresi dolmuş approved mekanlar.
func (r *VenueRepo) FindDueForSuspension(ctx context.Context) ([]*models.VenueForScheduler, error) {
	rows, err := r.db.Query(ctx,
		`SELECT v.id, v.name, v.added_by, u.email, u.name, v.verification_due_at
		 FROM venues v
		 JOIN users u ON u.id = v.added_by
		 WHERE v.status = 'approved'
		   AND v.verification_due_at < NOW()`,
	)
	if err != nil {
		return nil, fmt.Errorf("askıya alınacaklar listesi alınamadı: %w", err)
	}
	defer rows.Close()
	return scanVenuesForScheduler(rows)
}

// UpdateLastNotified — spam önleme: son bildirim zamanını günceller.
func (r *VenueRepo) UpdateLastNotified(ctx context.Context, id string) error {
	_, err := r.db.Exec(ctx,
		`UPDATE venues SET last_notified_at = NOW() WHERE id = $1`,
		id,
	)
	return err
}

func scanVenuesForScheduler(rows interface {
	Next() bool
	Scan(...any) error
	Err() error
}) ([]*models.VenueForScheduler, error) {
	var result []*models.VenueForScheduler
	for rows.Next() {
		v := &models.VenueForScheduler{}
		if err := rows.Scan(&v.ID, &v.Name, &v.AddedBy, &v.GuideEmail, &v.GuideName, &v.VerificationDueAt); err != nil {
			return nil, err
		}
		result = append(result, v)
	}
	return result, rows.Err()
}
```

- [ ] **Step 4: Derlemeyi doğrula — Approve imzası değiştiği için hata beklenir**

```bash
cd backend && go build ./...
# Beklenen hata: admin_handler.go'daki Approve çağrısı eski imzayla
```

- [ ] **Step 5: admin_handler.go'daki ApproveVenue'yu düzelt**

`admin_handler.go`'daki `h.venueRepo.Approve(c.Context(), id, adminID)` satırını şu şekilde değiştir:

```go
if err := h.venueRepo.Approve(c.Context(), id, adminID, h.verificationPeriodDays); err != nil {
```

`AdminHandler` struct'ına `verificationPeriodDays int` alanını ekle:

```go
type AdminHandler struct {
	venueRepo              *repository.VenueRepo
	guideRepo              *repository.GuideRepo
	userRepo               *repository.UserRepo
	auditRepo              *repository.AuditRepo
	referralRepo           *repository.ReferralRepo
	verificationPeriodDays int
}
```

`NewAdminHandler` fonksiyonunu şu şekilde güncelle:

```go
func NewAdminHandler(venueRepo *repository.VenueRepo, guideRepo *repository.GuideRepo, userRepo *repository.UserRepo, auditRepo *repository.AuditRepo, referralRepo *repository.ReferralRepo, verificationPeriodDays int) *AdminHandler {
	return &AdminHandler{
		venueRepo:              venueRepo,
		guideRepo:              guideRepo,
		userRepo:               userRepo,
		auditRepo:              auditRepo,
		referralRepo:           referralRepo,
		verificationPeriodDays: verificationPeriodDays,
	}
}
```

- [ ] **Step 6: Derlemeyi doğrula**

```bash
cd backend && go build ./...
# main.go'da NewAdminHandler çağrısı da hata verecek — bir sonraki adımda düzeltilecek
```

- [ ] **Step 7: Commit**

```bash
git add backend/internal/repository/venue_status_repo.go \
        backend/internal/handlers/admin_handler.go
git commit -m "feat: add scheduler venue queries and update Approve signature"
```

---

## Task 9: Scheduler Service

**Files:**
- Create: `backend/internal/services/scheduler_service.go`

- [ ] **Step 1: scheduler_service.go oluştur**

```go
package services

import (
	"context"
	"log"
	"time"

	"github.com/omerkoc/caiz-mi/internal/repository"
)

type SchedulerService struct {
	venueRepo       *repository.VenueRepo
	verifLogRepo    *repository.VerificationLogRepo
	notifService    *NotificationService
	runHour         int
	warningDays     int
}

func NewSchedulerService(
	venueRepo *repository.VenueRepo,
	verifLogRepo *repository.VerificationLogRepo,
	notifService *NotificationService,
	runHour, warningDays int,
) *SchedulerService {
	return &SchedulerService{
		venueRepo:    venueRepo,
		verifLogRepo: verifLogRepo,
		notifService: notifService,
		runHour:      runHour,
		warningDays:  warningDays,
	}
}

// Start — context iptal edilene kadar her gece runHour'da çalışır.
func (s *SchedulerService) Start(ctx context.Context) {
	log.Printf("scheduler başlatıldı, her gece %02d:00'da çalışacak", s.runHour)
	for {
		next := s.nextRunTime()
		select {
		case <-ctx.Done():
			log.Println("scheduler durduruldu")
			return
		case <-time.After(time.Until(next)):
			log.Println("doğrulama döngüsü başlıyor...")
			s.runVerificationCycle(ctx)
		}
	}
}

func (s *SchedulerService) nextRunTime() time.Time {
	now := time.Now()
	next := time.Date(now.Year(), now.Month(), now.Day(), s.runHour, 0, 0, 0, now.Location())
	if now.After(next) {
		next = next.Add(24 * time.Hour)
	}
	return next
}

func (s *SchedulerService) runVerificationCycle(ctx context.Context) {
	// Faz 1: Uyarı
	warnings, err := s.venueRepo.FindDueForWarning(ctx, s.warningDays)
	if err != nil {
		log.Printf("scheduler uyarı sorgusu hatası: %v", err)
	} else {
		for _, v := range warnings {
			if err := s.notifService.SendVerificationWarning(ctx, v); err != nil {
				log.Printf("uyarı gönderilemedi (venue %s): %v", v.ID, err)
				continue
			}
			_ = s.venueRepo.UpdateLastNotified(ctx, v.ID)
			_ = s.verifLogRepo.Create(ctx, v.ID, v.AddedBy, "warning_sent")
			log.Printf("uyarı gönderildi: venue=%s guide=%s", v.ID, v.AddedBy)
		}
	}

	// Faz 2: Askıya alma
	suspensions, err := s.venueRepo.FindDueForSuspension(ctx)
	if err != nil {
		log.Printf("scheduler askıya alma sorgusu hatası: %v", err)
	} else {
		for _, v := range suspensions {
			if err := s.venueRepo.SuspendForVerification(ctx, v.ID); err != nil {
				log.Printf("mekan askıya alınamadı (venue %s): %v", v.ID, err)
				continue
			}
			if err := s.notifService.SendSuspensionNotice(ctx, v); err != nil {
				log.Printf("askıya alma bildirimi gönderilemedi (venue %s): %v", v.ID, err)
			}
			_ = s.verifLogRepo.Create(ctx, v.ID, v.AddedBy, "suspended")
			log.Printf("mekan askıya alındı: venue=%s guide=%s", v.ID, v.AddedBy)
		}
	}
}
```

- [ ] **Step 2: Derlemeyi doğrula**

```bash
cd backend && go build ./...
```

- [ ] **Step 3: Commit**

```bash
git add backend/internal/services/scheduler_service.go
git commit -m "feat: add verification scheduler service"
```

---

## Task 10: Notification Handler

**Files:**
- Create: `backend/internal/handlers/notification_handler.go`

- [ ] **Step 1: notification_handler.go oluştur**

```go
package handlers

import (
	"errors"

	"github.com/gofiber/fiber/v2"

	"github.com/omerkoc/caiz-mi/internal/models"
	"github.com/omerkoc/caiz-mi/internal/repository"
)

type NotificationHandler struct {
	notifRepo *repository.NotificationRepo
}

func NewNotificationHandler(notifRepo *repository.NotificationRepo) *NotificationHandler {
	return &NotificationHandler{notifRepo: notifRepo}
}

// GET /api/v1/notifications?page=1&limit=20
func (h *NotificationHandler) List(c *fiber.Ctx) error {
	userID, err := getUserID(c)
	if err != nil {
		return err
	}
	page := max(c.QueryInt("page", 1), 1)
	limit := min(c.QueryInt("limit", 20), 100)
	offset := (page - 1) * limit

	items, err := h.notifRepo.ListByUserID(c.Context(), userID, limit, offset)
	if err != nil {
		return fiber.ErrInternalServerError
	}
	if items == nil {
		items = []*models.Notification{} // nil yerine boş dizi döndür
	}
	return c.JSON(fiber.Map{"data": items, "page": page, "limit": limit})
}

// GET /api/v1/notifications/unread-count
func (h *NotificationHandler) UnreadCount(c *fiber.Ctx) error {
	userID, err := getUserID(c)
	if err != nil {
		return err
	}
	count, err := h.notifRepo.UnreadCount(c.Context(), userID)
	if err != nil {
		return fiber.ErrInternalServerError
	}
	return c.JSON(fiber.Map{"count": count})
}

// PUT /api/v1/notifications/:id/read
func (h *NotificationHandler) MarkRead(c *fiber.Ctx) error {
	userID, err := getUserID(c)
	if err != nil {
		return err
	}
	id := c.Params("id")
	if err := h.notifRepo.MarkRead(c.Context(), id, userID); err != nil {
		return fiber.ErrNotFound
	}
	return c.JSON(fiber.Map{"status": "ok"})
}

// PUT /api/v1/notifications/read-all
func (h *NotificationHandler) MarkAllRead(c *fiber.Ctx) error {
	userID, err := getUserID(c)
	if err != nil {
		return err
	}
	if err := h.notifRepo.MarkAllRead(c.Context(), userID); err != nil {
		return fiber.ErrInternalServerError
	}
	return c.JSON(fiber.Map{"status": "ok"})
}
```

**Not:** `MarkRead` handler'ında `ErrNotFound` kontrolü için `errors` import'u gereklidir — yukarıdaki import bloğunda dahil edilmiştir.

- [ ] **Step 2: Derlemeyi doğrula**

```bash
cd backend && go build ./...
```

- [ ] **Step 3: Commit**

```bash
git add backend/internal/handlers/notification_handler.go
git commit -m "feat: add notification handler"
```

---

## Task 11: Venue Handler — Verify Endpoint

**Files:**
- Modify: `backend/internal/handlers/venue_handler.go`

- [ ] **Step 1: VenueHandler struct'ına verificationPeriodDays ekle**

`VenueHandler` struct'ını şu şekilde değiştir:

```go
type VenueHandler struct {
	venueRepo              *repository.VenueRepo
	storageService         *services.StorageService
	placesService          *services.PlacesService
	verifLogRepo           *repository.VerificationLogRepo
	verificationPeriodDays int
}

func NewVenueHandler(
	venueRepo *repository.VenueRepo,
	storageService *services.StorageService,
	placesService *services.PlacesService,
	verifLogRepo *repository.VerificationLogRepo,
	verificationPeriodDays int,
) *VenueHandler {
	return &VenueHandler{
		venueRepo:              venueRepo,
		storageService:         storageService,
		placesService:          placesService,
		verifLogRepo:           verifLogRepo,
		verificationPeriodDays: verificationPeriodDays,
	}
}
```

- [ ] **Step 2: Verify metodunu ekle (dosyanın sonuna)**

```go
// PUT /api/v1/venues/:id/verify
// Rehber kendi mekanının hâlâ helal olduğunu teyit eder.
func (h *VenueHandler) Verify(c *fiber.Ctx) error {
	venueID := c.Params("id")
	guideID, err := getUserID(c)
	if err != nil {
		return err
	}

	if err := h.venueRepo.VerifyByGuide(c.Context(), venueID, guideID, h.verificationPeriodDays); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return fiber.ErrNotFound
		}
		return fiber.ErrInternalServerError
	}

	_ = h.verifLogRepo.Create(c.Context(), venueID, guideID, "verified")

	return c.JSON(fiber.Map{"status": "verified"})
}
```

- [ ] **Step 3: Derlemeyi doğrula**

```bash
cd backend && go build ./...
# main.go'daki NewVenueHandler çağrısı hata verecek — bir sonraki task'ta düzeltilir
```

- [ ] **Step 4: Commit**

```bash
git add backend/internal/handlers/venue_handler.go
git commit -m "feat: add venue verify endpoint"
```

---

## Task 12: Admin Handler — Verification Endpoints

**Files:**
- Modify: `backend/internal/handlers/admin_handler.go`

- [ ] **Step 1: AdminHandler'a verif log repo ekle**

`AdminHandler` struct'ına `verifLogRepo *repository.VerificationLogRepo` ekle ve `NewAdminHandler` fonksiyonunu güncelle:

```go
type AdminHandler struct {
	venueRepo              *repository.VenueRepo
	guideRepo              *repository.GuideRepo
	userRepo               *repository.UserRepo
	auditRepo              *repository.AuditRepo
	referralRepo           *repository.ReferralRepo
	verifLogRepo           *repository.VerificationLogRepo
	verificationPeriodDays int
}

func NewAdminHandler(
	venueRepo *repository.VenueRepo,
	guideRepo *repository.GuideRepo,
	userRepo *repository.UserRepo,
	auditRepo *repository.AuditRepo,
	referralRepo *repository.ReferralRepo,
	verifLogRepo *repository.VerificationLogRepo,
	verificationPeriodDays int,
) *AdminHandler {
	return &AdminHandler{
		venueRepo:              venueRepo,
		guideRepo:              guideRepo,
		userRepo:               userRepo,
		auditRepo:              auditRepo,
		referralRepo:           referralRepo,
		verifLogRepo:           verifLogRepo,
		verificationPeriodDays: verificationPeriodDays,
	}
}
```

- [ ] **Step 2: VerificationLogs ve ReactivateVenue metodlarını ekle**

```go
// GET /admin/verification-logs?tab=verified|suspended|upcoming
func (h *AdminHandler) VerificationLogs(c *fiber.Ctx) error {
	tab := c.Query("tab", "verified")
	switch tab {
	case "verified":
		page := max(c.QueryInt("page", 1), 1)
		logs, err := h.verifLogRepo.ListVerified(c.Context(), 50, (page-1)*50)
		if err != nil {
			return fiber.ErrInternalServerError
		}
		return c.JSON(fiber.Map{"data": logs})
	case "suspended":
		logs, err := h.verifLogRepo.ListSuspended(c.Context())
		if err != nil {
			return fiber.ErrInternalServerError
		}
		return c.JSON(fiber.Map{"data": logs})
	case "upcoming":
		logs, err := h.verifLogRepo.ListUpcoming(c.Context(), 30)
		if err != nil {
			return fiber.ErrInternalServerError
		}
		return c.JSON(fiber.Map{"data": logs})
	default:
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "geçersiz tab parametresi"})
	}
}

// PUT /admin/venues/:id/reactivate
func (h *AdminHandler) ReactivateVenue(c *fiber.Ctx) error {
	id := c.Params("id")
	adminID, err := getUserID(c)
	if err != nil {
		return err
	}

	if err := h.venueRepo.ReactivateVenue(c.Context(), id, h.verificationPeriodDays); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return fiber.ErrNotFound
		}
		return fiber.ErrInternalServerError
	}

	h.writeAuditLog(c, "reactivate_venue", "venue", id, nil)
	_ = adminID
	return c.JSON(fiber.Map{"status": "reactivated"})
}
```

- [ ] **Step 3: Derlemeyi doğrula**

```bash
cd backend && go build ./...
```

- [ ] **Step 4: Commit**

```bash
git add backend/internal/handlers/admin_handler.go
git commit -m "feat: add admin verification logs and reactivate endpoints"
```

---

## Task 13: main.go Wiring

**Files:**
- Modify: `backend/cmd/api/main.go`

- [ ] **Step 1: Yeni repo, servis ve handler'ları ekle**

`main.go`'daki repository katmanı bloğuna ekle:

```go
notifRepo     := repository.NewNotificationRepo(pool)
verifLogRepo  := repository.NewVerificationLogRepo(pool)
```

Service katmanı bloğuna ekle:

```go
var emailSvc services.EmailService
if cfg.SMTPUser != "" && cfg.SMTPPassword != "" {
    emailSvc = services.NewSMTPEmailService(cfg.SMTPHost, cfg.SMTPPort, cfg.SMTPUser, cfg.SMTPPassword, cfg.SMTPFrom)
} else {
    emailSvc = services.NewNoopEmailService()
}
notifService  := services.NewNotificationService(notifRepo, emailSvc)
schedulerSvc  := services.NewSchedulerService(venueRepo, verifLogRepo, notifService, cfg.SchedulerRunHour, cfg.VerificationWarningDays)
```

Handler katmanı bloğuna ekle ve mevcut handler çağrılarını güncelle:

```go
// VenueHandler güncellendi (verifLogRepo + verificationPeriodDays eklendi)
venueHandler := handlers.NewVenueHandler(venueRepo, storageService, placesService, verifLogRepo, cfg.VerificationPeriodDays)

// AdminHandler güncellendi (verifLogRepo + verificationPeriodDays eklendi)
adminHandler := handlers.NewAdminHandler(venueRepo, guideRepo, userRepo, auditRepo, referralRepo, verifLogRepo, cfg.VerificationPeriodDays)

notifHandler := handlers.NewNotificationHandler(notifRepo)
```

- [ ] **Step 2: Scheduler'ı background goroutine olarak başlat**

`log.Printf("sunucu başlatılıyor..."` satırının hemen üstüne:

```go
// Verification scheduler'ı başlat
ctx, cancel := context.WithCancel(context.Background())
defer cancel()
go schedulerSvc.Start(ctx)
```

Import'a `"context"` ekle.

- [ ] **Step 3: Yeni route'ları ekle**

`// Favorite endpoint'leri` bloğunun üstüne:

```go
// Notification endpoint'leri
notif := api.Group("/notifications", middleware.Auth(cfg.JWTSecret))
notif.Get("/", notifHandler.List)
notif.Get("/unread-count", notifHandler.UnreadCount)
notif.Put("/read-all", notifHandler.MarkAllRead)
notif.Put("/:id/read", notifHandler.MarkRead)
```

`// Venue endpoint'leri (Guide + Admin)` bloğuna ekle:

```go
api.Put("/venues/:id/verify",
    middleware.Auth(cfg.JWTSecret),
    middleware.RequireRole("guide", "admin"),
    venueHandler.Verify,
)
```

Admin route'larına ekle:

```go
admin.Get("/verification-logs", adminHandler.VerificationLogs)
admin.Put("/venues/:id/reactivate", adminHandler.ReactivateVenue)
```

- [ ] **Step 4: Derlemeyi doğrula**

```bash
cd backend && go build ./...
# Beklenen: hata yok
```

- [ ] **Step 5: Sunucuyu ayağa kaldır ve temel endpoint'leri test et**

```bash
cd backend && go run cmd/api/main.go &
curl -s http://localhost:8080/health
# Beklenen: {"status":"ok","service":"caiz-mi-api"}
curl -s http://localhost:8080/api/v1/notifications/unread-count \
  -H "Authorization: Bearer <geçerli_token>"
# Beklenen: {"count":0}
kill %1
```

- [ ] **Step 6: Commit**

```bash
git add backend/cmd/api/main.go
git commit -m "feat: wire notification system in main.go"
```

---

## Task 14: Flutter — Notification Model

**Files:**
- Create: `mobile/lib/core/models/notification_model.dart`

- [ ] **Step 1: notification_model.dart oluştur**

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_model.freezed.dart';
part 'notification_model.g.dart';

@freezed
abstract class AppNotification with _$AppNotification {
  const factory AppNotification({
    required String id,
    @JsonKey(name: 'user_id') required String userId,
    required String type,
    required String title,
    required String body,
    Map<String, String>? data,
    @JsonKey(name: 'is_read') @Default(false) bool isRead,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _AppNotification;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      _$AppNotificationFromJson(json);
}
```

- [ ] **Step 2: Kod üretimini çalıştır**

```bash
cd mobile
dart run build_runner build --delete-conflicting-outputs
# Beklenen: notification_model.freezed.dart ve notification_model.g.dart oluşur
```

- [ ] **Step 3: Commit**

```bash
git add mobile/lib/core/models/notification_model.dart \
        mobile/lib/core/models/notification_model.freezed.dart \
        mobile/lib/core/models/notification_model.g.dart
git commit -m "feat: add notification freezed model"
```

---

## Task 15: Flutter — API Endpoints

**Files:**
- Modify: `mobile/lib/core/api/api_endpoints.dart`

- [ ] **Step 1: Yeni endpoint sabitlerini ekle**

`api_endpoints.dart` dosyasına `// Misc` bloğunun üstüne ekle:

```dart
// Notifications
static const String notifications = '/notifications';
static const String notificationsUnreadCount = '/notifications/unread-count';
static const String notificationsReadAll = '/notifications/read-all';
static String notificationRead(String id) => '/notifications/$id/read';

// Venue verify
static String venueVerify(String id) => '/venues/$id/verify';

// Admin verification logs
static const String adminVerificationLogs = '/admin/verification-logs';
static String adminReactivateVenue(String id) => '/admin/venues/$id/reactivate';
```

- [ ] **Step 2: Derlemeyi doğrula**

```bash
cd mobile && flutter analyze lib/core/api/api_endpoints.dart
# Beklenen: hata yok
```

- [ ] **Step 3: Commit**

```bash
git add mobile/lib/core/api/api_endpoints.dart
git commit -m "feat: add notification api endpoints"
```

---

## Task 16: Flutter — Notification Provider

**Files:**
- Create: `mobile/lib/features/notifications/providers/notification_provider.dart`

- [ ] **Step 1: notification_provider.dart oluştur**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/models/notification_model.dart';

class NotificationState {
  final List<AppNotification> notifications;
  final int unreadCount;
  final bool isLoading;
  final String? error;

  const NotificationState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.isLoading = false,
    this.error,
  });

  NotificationState copyWith({
    List<AppNotification>? notifications,
    int? unreadCount,
    bool? isLoading,
    String? error,
  }) => NotificationState(
    notifications: notifications ?? this.notifications,
    unreadCount: unreadCount ?? this.unreadCount,
    isLoading: isLoading ?? this.isLoading,
    error: error,
  );
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  final ApiClient _api;

  NotificationNotifier(this._api) : super(const NotificationState());

  Future<void> fetchNotifications() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _api.get(ApiEndpoints.notifications);
      final items = (res.data['data'] as List)
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(notifications: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Bildirimler yüklenemedi');
    }
  }

  Future<void> fetchUnreadCount() async {
    try {
      final res = await _api.get(ApiEndpoints.notificationsUnreadCount);
      state = state.copyWith(unreadCount: res.data['count'] as int);
    } catch (_) {}
  }

  Future<void> markRead(String id) async {
    try {
      await _api.put(ApiEndpoints.notificationRead(id), data: {});
      state = state.copyWith(
        notifications: state.notifications.map((n) =>
          n.id == id ? n.copyWith(isRead: true) : n
        ).toList(),
        unreadCount: (state.unreadCount - 1).clamp(0, 999),
      );
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    try {
      await _api.put(ApiEndpoints.notificationsReadAll, data: {});
      state = state.copyWith(
        notifications: state.notifications.map((n) => n.copyWith(isRead: true)).toList(),
        unreadCount: 0,
      );
    } catch (_) {}
  }
}

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  return NotificationNotifier(ref.watch(apiClientProvider));
});
```

- [ ] **Step 2: Derlemeyi doğrula**

```bash
cd mobile && flutter analyze lib/features/notifications/
# Beklenen: hata yok (apiClientProvider mevcut projede var)
```

- [ ] **Step 3: Commit**

```bash
git add mobile/lib/features/notifications/providers/notification_provider.dart
git commit -m "feat: add notification riverpod provider"
```

---

## Task 17: Flutter — AppHeader Güncelleme

**Files:**
- Modify: `mobile/lib/shared/widgets/app_header.dart`

- [ ] **Step 1: app_header.dart'a auth import ve bildirim ikonu ekle**

Mevcut import'lara ekle:

```dart
import '../../core/auth/auth_provider.dart';
import '../../features/notifications/providers/notification_provider.dart';
```

`AppBar`'ın `actions` özelliği bulunmadığından, `title` içindeki Row'a zil ikonunu `Favoriler` ikonundan önce ekle. Mevcut favoriler `IconButton`'unun hemen önüne:

```dart
// Bildirim ikonu (sadece giriş yapan kullanıcılara)
Consumer(builder: (context, ref, _) {
  final isLoggedIn = ref.watch(authProvider).isAuthenticated;
  if (!isLoggedIn) return const SizedBox.shrink();
  final unread = ref.watch(
    notificationProvider.select((s) => s.unreadCount),
  );
  return Stack(
    clipBehavior: Clip.none,
    children: [
      IconButton(
        icon: const Icon(Icons.notifications_none, color: Colors.white),
        onPressed: () => context.push('/notifications'),
      ),
      if (unread > 0)
        Positioned(
          right: 6,
          top: 6,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            child: Text(
              unread > 99 ? '99+' : '$unread',
              style: const TextStyle(color: Colors.white, fontSize: 9),
            ),
          ),
        ),
    ],
  );
}),
const SizedBox(width: 4),
```

- [ ] **Step 2: Derlemeyi doğrula**

```bash
cd mobile && flutter analyze lib/shared/widgets/app_header.dart
```

- [ ] **Step 3: Commit**

```bash
git add mobile/lib/shared/widgets/app_header.dart
git commit -m "feat: add notification bell icon to AppHeader"
```

---

## Task 18: Flutter — Notifications Screen

**Files:**
- Create: `mobile/lib/features/notifications/screens/notifications_screen.dart`
- Modify: `mobile/lib/core/router/app_router.dart`

- [ ] **Step 1: notifications_screen.dart oluştur**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../providers/notification_provider.dart';
import '../../../core/models/notification_model.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationProvider.notifier).fetchNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler'),
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              onPressed: () => ref.read(notificationProvider.notifier).markAllRead(),
              child: const Text('Tümünü okundu işaretle',
                style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
        ],
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(NotificationState state) {
    if (state.isLoading && state.notifications.isEmpty) {
      return const LoadingIndicator();
    }
    if (state.notifications.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 64, color: AppTheme.textSecondary),
            SizedBox(height: 16),
            Text('Henüz bildiriminiz yok',
              style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(notificationProvider.notifier).fetchNotifications(),
      child: ListView.builder(
        itemCount: state.notifications.length,
        itemBuilder: (context, index) => _NotificationItem(
          notification: state.notifications[index],
          onTap: () => _handleTap(state.notifications[index]),
        ),
      ),
    );
  }

  void _handleTap(AppNotification n) {
    if (!n.isRead) {
      ref.read(notificationProvider.notifier).markRead(n.id);
    }
    final venueId = n.data?['venue_id'];
    if (venueId != null) {
      context.push('/venue/$venueId');
    }
  }
}

class _NotificationItem extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationItem({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isWarning = notification.type == 'verification_warning';
    final color = isWarning ? Colors.orange : Colors.red;
    final icon = isWarning ? Icons.warning_amber_rounded : Icons.pause_circle_outline;

    return ListTile(
      tileColor: notification.isRead ? null : color.withValues(alpha: 0.06),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(notification.title,
        style: TextStyle(
          fontWeight: notification.isRead ? FontWeight.normal : FontWeight.w600,
          fontSize: 14,
        )),
      subtitle: Text(notification.body,
        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        DateFormat('dd MMM', 'tr').format(notification.createdAt),
        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
      ),
      onTap: onTap,
    );
  }
}
```

**Not:** `intl` paketi pubspec.yaml'da yoksa `flutter pub add intl` komutuyla ekle.

- [ ] **Step 2: Router'a /notifications rotasını ekle**

`app_router.dart`'a import ekle:

```dart
import '../../features/notifications/screens/notifications_screen.dart';
```

`AppRoutes` class'ına:

```dart
static const String notifications = '/notifications';
```

Route listesine (home route'unun yanına):

```dart
GoRoute(
  path: AppRoutes.notifications,
  builder: (context, state) => const NotificationsScreen(),
),
```

- [ ] **Step 3: Derlemeyi doğrula**

```bash
cd mobile && flutter analyze lib/features/notifications/ lib/core/router/app_router.dart
```

- [ ] **Step 4: Commit**

```bash
git add mobile/lib/features/notifications/screens/notifications_screen.dart \
        mobile/lib/core/router/app_router.dart
git commit -m "feat: add notifications screen and route"
```

---

## Task 19: Flutter — Mekan Doğrulama Butonu

**Files:**
- Modify: `mobile/lib/features/venue/screens/venue_detail_screen.dart`

- [ ] **Step 1: venue_detail_screen.dart'ı incele — doğrulama butonunun ekleneceği yeri bul**

```bash
grep -n "addedBy\|ElevatedButton\|FloatingAction\|SliverAppBar\|bottomNavigationBar\|Column\|Stack" \
  mobile/lib/features/venue/screens/venue_detail_screen.dart | head -30
```

- [ ] **Step 2: VerifyVenueButton widget'ını ekle (dosyanın sonuna)**

```dart
class _VerifyVenueButton extends ConsumerStatefulWidget {
  final String venueId;
  final String addedBy;
  final String status;

  const _VerifyVenueButton({
    required this.venueId,
    required this.addedBy,
    required this.status,
  });

  @override
  ConsumerState<_VerifyVenueButton> createState() => _VerifyVenueButtonState();
}

class _VerifyVenueButtonState extends ConsumerState<_VerifyVenueButton> {
  bool _isLoading = false;

  Future<void> _verify() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mekan Doğrulama'),
        content: const Text(
          'Bu mekanın hâlâ helal kriterlerini karşıladığını onaylıyor musunuz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Doğrula'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.put(ApiEndpoints.venueVerify(widget.venueId), data: {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mekan başarıyla doğrulandı'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doğrulama başarısız, tekrar deneyin')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(authProvider).user?.id;
    final isOwner = currentUserId == widget.addedBy;
    final isVerifiable = widget.status == 'approved' || widget.status == 'suspended';

    if (!isOwner || !isVerifiable) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isLoading ? null : _verify,
          icon: _isLoading
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.verified_outlined),
          label: const Text('Helal Kriterlerini Doğrula'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: VenueDetailScreen'e doğrulama butonunu ekle**

`venue_detail_screen.dart`'ta mekan içeriğini saran `Column` veya `ListView`'ın uygun bir yerine (fotoğraf galerisi ve bilgiler bittikten sonra) `_VerifyVenueButton` widget'ını ekle:

```dart
_VerifyVenueButton(
  venueId: venue.id,
  addedBy: venue.addedBy,
  status: venue.status,
),
```

Gerekli import'ları ekle:

```dart
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_client.dart';
```

- [ ] **Step 4: Derlemeyi doğrula**

```bash
cd mobile && flutter analyze lib/features/venue/screens/venue_detail_screen.dart
```

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/venue/screens/venue_detail_screen.dart
git commit -m "feat: add verify button to venue detail screen"
```

---

## Task 20: Flutter — Admin Verification Logs Ekranı

**Files:**
- Create: `mobile/lib/features/admin/screens/verification_logs_screen.dart`
- Modify: `mobile/lib/core/router/app_router.dart`
- Modify: `mobile/lib/features/admin/screens/admin_dashboard_screen.dart`

- [ ] **Step 1: verification_logs_screen.dart oluştur**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/loading_indicator.dart';

class VerificationLogsScreen extends ConsumerStatefulWidget {
  const VerificationLogsScreen({super.key});

  @override
  ConsumerState<VerificationLogsScreen> createState() => _VerificationLogsScreenState();
}

class _VerificationLogsScreenState extends ConsumerState<VerificationLogsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<dynamic> _verified = [];
  List<dynamic> _suspended = [];
  List<dynamic> _upcoming = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    setState(() => _isLoading = true);
    final api = ref.read(apiClientProvider);
    try {
      final results = await Future.wait([
        api.get('${ApiEndpoints.adminVerificationLogs}?tab=verified'),
        api.get('${ApiEndpoints.adminVerificationLogs}?tab=suspended'),
        api.get('${ApiEndpoints.adminVerificationLogs}?tab=upcoming'),
      ]);
      setState(() {
        _verified  = results[0].data['data'] as List? ?? [];
        _suspended = results[1].data['data'] as List? ?? [];
        _upcoming  = results[2].data['data'] as List? ?? [];
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _reactivate(String venueId) async {
    final api = ref.read(apiClientProvider);
    try {
      await api.put(ApiEndpoints.adminReactivateVenue(venueId), data: {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mekan yeniden aktive edildi'), backgroundColor: Colors.green));
      _fetchAll();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İşlem başarısız')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doğrulama Logları'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Son Doğrulamalar'),
            Tab(text: 'Askıdakiler'),
            Tab(text: 'Yaklaşanlar'),
          ],
        ),
      ),
      body: _isLoading
          ? const LoadingIndicator()
          : TabBarView(
              controller: _tabController,
              children: [
                _LogList(items: _verified, actionLabel: null, onAction: null),
                _LogList(items: _suspended, actionLabel: 'Aktive Et', onAction: _reactivate),
                _LogList(items: _upcoming, actionLabel: null, onAction: null),
              ],
            ),
    );
  }
}

class _LogList extends StatelessWidget {
  final List<dynamic> items;
  final String? actionLabel;
  final void Function(String venueId)? onAction;

  const _LogList({required this.items, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('Kayıt yok'));
    }
    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index] as Map<String, dynamic>;
          final venueId = item['venue_id'] as String? ?? '';
          final dt = item['created_at'] != null
              ? DateTime.tryParse(item['created_at'] as String)
              : null;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              title: Text(item['venue_name'] as String? ?? '-',
                style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['guide_name'] as String? ?? '-'),
                  Text(item['city'] as String? ?? '-',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (dt != null)
                    Text(DateFormat('dd MMM yy', 'tr').format(dt),
                      style: const TextStyle(fontSize: 11)),
                  if (actionLabel != null && onAction != null)
                    GestureDetector(
                      onTap: () => onAction!(venueId),
                      child: Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(actionLabel!,
                          style: const TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                    ),
                ],
              ),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 2: Router'a admin route ekle**

`app_router.dart`'a import:

```dart
import '../../features/admin/screens/verification_logs_screen.dart';
```

`AppRoutes`'a:

```dart
static const String adminVerificationLogs = '/admin/verification-logs';
```

Route listesine (admin route'ları arasına):

```dart
GoRoute(
  path: AppRoutes.adminVerificationLogs,
  builder: (context, state) => const VerificationLogsScreen(),
),
```

- [ ] **Step 3: Admin dashboard'a giriş linki ekle**

`admin_dashboard_screen.dart`'ta mevcut menü item'larına (audit-log, venue-reports gibi) ekle:

```dart
_DashboardItem(
  icon: Icons.verified_user_outlined,
  label: 'Doğrulama Logları',
  onTap: () => context.push(AppRoutes.adminVerificationLogs),
),
```

- [ ] **Step 4: Derlemeyi doğrula**

```bash
cd mobile && flutter analyze lib/features/admin/
```

- [ ] **Step 5: Final build kontrolü**

```bash
cd mobile && flutter build apk --debug 2>&1 | tail -5
# Beklenen: "Built build/app/outputs/flutter-apk/app-debug.apk"
```

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/features/admin/screens/verification_logs_screen.dart \
        mobile/lib/features/admin/screens/admin_dashboard_screen.dart \
        mobile/lib/core/router/app_router.dart
git commit -m "feat: add admin verification logs screen"
```

---

## Özet

| # | Task | Bileşen |
|---|---|---|
| 1 | DB Migration | Backend |
| 2 | Config güncelleme | Backend |
| 3 | Go Modelleri | Backend |
| 4 | Notification Repository | Backend |
| 5 | Verification Log Repository | Backend |
| 6 | Email Service (SMTP) | Backend |
| 7 | Notification Service | Backend |
| 8 | VenueRepo scheduler sorguları | Backend |
| 9 | Scheduler Service | Backend |
| 10 | Notification Handler | Backend |
| 11 | Venue Verify Handler | Backend |
| 12 | Admin Verification Handler | Backend |
| 13 | main.go wiring | Backend |
| 14 | Flutter Notification Model | Flutter |
| 15 | Flutter API Endpoints | Flutter |
| 16 | Flutter Notification Provider | Flutter |
| 17 | AppHeader Bell Icon | Flutter |
| 18 | Notifications Screen | Flutter |
| 19 | Venue Verify Button | Flutter |
| 20 | Admin Verification Logs | Flutter |
