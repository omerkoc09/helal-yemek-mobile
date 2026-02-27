# Caiz mi? — Sistem Mimarisi ve Tasarım Desenleri

## Sistem Mimarisi Genel Bakış

### Üst Düzey Mimari

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Flutter App   │    │   Flutter App   │    │   Admin Panel   │
│     (iOS)       │    │   (Android)     │    │   (Mobile Web)  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │   Go Backend    │
                    │   (Fiber API)   │
                    └─────────────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         │                       │                       │
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   PostgreSQL    │    │   S3 Storage    │    │  External APIs  │
│   + PostGIS     │    │  (Photos)       │    │ Google/Apple    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Katmanlı Mimari

#### 1. Presentation Layer (Flutter)
- **Screens**: Kullanıcı arayüzü ekranları
- **Widgets**: Yeniden kullanılabilir UI bileşenleri
- **Providers**: State management (Riverpod)
- **Router**: Navigasyon yönetimi (GoRouter)

#### 2. API Layer (Go Backend)
- **Handlers**: HTTP request/response işleme
- **Middleware**: Auth, RBAC, rate limiting
- **Services**: İş mantığı katmanı
- **Repository**: Veri erişim katmanı

#### 3. Data Layer
- **PostgreSQL**: İlişkisel veri depolama
- **PostGIS**: Coğrafi veri ve sorgular
- **S3 Storage**: Fotoğraf ve medya dosyaları

## Veritabanı Şeması

### Temel Tablolar

#### users
```sql
CREATE TABLE users (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email       VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255),           -- NULL ise sosyal login
    name        VARCHAR(255) NOT NULL,
    avatar_url  TEXT,
    role        VARCHAR(20) NOT NULL DEFAULT 'traveler', -- traveler | guide | admin
    provider    VARCHAR(20) DEFAULT 'email',             -- email | google | apple
    provider_id VARCHAR(255),
    is_active   BOOLEAN NOT NULL DEFAULT true,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

#### venues
```sql
CREATE TABLE venues (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            VARCHAR(255) NOT NULL,
    address         TEXT NOT NULL,
    city            VARCHAR(100) NOT NULL,
    country         VARCHAR(100) NOT NULL,
    location        GEOGRAPHY(POINT, 4326) NOT NULL,  -- PostGIS
    working_hours   JSONB,                             -- {mon: "09:00-22:00", ...}
    notes           TEXT,
    status          VARCHAR(20) NOT NULL DEFAULT 'pending', -- pending | approved | rejected
    rejection_note  TEXT,
    added_by        UUID NOT NULL REFERENCES users(id),
    approved_by     UUID REFERENCES users(id),
    verified_at     TIMESTAMPTZ,                       -- son onay tarihi
    confirmation_count INT NOT NULL DEFAULT 0,         -- kaç guide onayladı
    is_double_verified BOOLEAN NOT NULL DEFAULT false,
    deleted_at      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX venues_location_idx ON venues USING GIST (location);
CREATE INDEX venues_city_idx ON venues (city);
CREATE INDEX venues_status_idx ON venues (status);
```

### İlişki Tabloları

#### halal_criteria
```sql
CREATE TABLE halal_criteria (
    id    SMALLINT PRIMARY KEY,
    key   VARCHAR(50) UNIQUE NOT NULL,    -- 'personal_experience', 'halal_certified'
    label_tr VARCHAR(100) NOT NULL,
    label_en VARCHAR(100) NOT NULL
);

-- Sabit veriler (seed)
INSERT INTO halal_criteria VALUES
(1, 'personal_experience', 'Kişisel Tecrübe', 'Personal Experience'),
(2, 'halal_certified', 'Helal Sertifikası var', 'Halal Certified');
```

#### venue_criteria
```sql
CREATE TABLE venue_criteria (
    venue_id    UUID REFERENCES venues(id) ON DELETE CASCADE,
    criteria_id SMALLINT REFERENCES halal_criteria(id),
    PRIMARY KEY (venue_id, criteria_id)
);
```

### Sosyal Özellik Tabloları

#### reviews
```sql
CREATE TABLE reviews (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    venue_id    UUID NOT NULL REFERENCES venues(id) ON DELETE CASCADE,
    user_id     UUID NOT NULL REFERENCES users(id),
    rating      SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment     TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (venue_id, user_id)  -- kullanıcı başına 1 yorum
);
```

#### favorites
```sql
CREATE TABLE favorites (
    user_id     UUID REFERENCES users(id) ON DELETE CASCADE,
    venue_id    UUID REFERENCES venues(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, venue_id)
);
```

### Yönetim Tabloları

#### guide_applications
```sql
CREATE TABLE guide_applications (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id),
    status      VARCHAR(20) NOT NULL DEFAULT 'pending', -- pending | approved | rejected
    note        TEXT,                   -- admin notu
    reviewed_by UUID REFERENCES users(id),
    reviewed_at TIMESTAMPTZ,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

#### correction_suggestions
```sql
CREATE TABLE correction_suggestions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    venue_id        UUID NOT NULL REFERENCES venues(id),
    suggested_by    UUID NOT NULL REFERENCES users(id),
    field_name      VARCHAR(100) NOT NULL,   -- 'name', 'address', 'working_hours', 'criteria'
    old_value       TEXT,
    new_value       TEXT NOT NULL,
    status          VARCHAR(20) NOT NULL DEFAULT 'pending', -- pending | approved | rejected
    reviewed_by     UUID REFERENCES users(id),
    reviewed_at     TIMESTAMPTZ,
    note            TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

#### audit_logs
```sql
CREATE TABLE audit_logs (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id    UUID NOT NULL REFERENCES users(id),
    action      VARCHAR(100) NOT NULL,  -- 'approve_venue', 'reject_guide', ...
    target_type VARCHAR(50) NOT NULL,   -- 'venue', 'user', 'correction', ...
    target_id   UUID NOT NULL,
    note        TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

## Tasarım Desenleri

### 1. Repository Pattern
```go
type VenueRepository interface {
    Create(venue *models.Venue) error
    GetByID(id uuid.UUID) (*models.Venue, error)
    GetNearby(lat, lng, radius float64) ([]*models.Venue, error)
    GetByCity(city string) ([]*models.Venue, error)
    Update(venue *models.Venue) error
    SoftDelete(id uuid.UUID) error
}
```

### 2. Service Layer Pattern
```go
type VenueService struct {
    repo VenueRepository
    storageService StorageService
    auditService AuditService
}

func (s *VenueService) ApproveVenue(venueID uuid.UUID, adminID uuid.UUID) error {
    // İş mantığı: venue onaylama, double-verified kontrolü, audit log
}
```

### 3. Middleware Chain Pattern
```go
// Auth -> RBAC -> Rate Limiting -> Handler
app.Use(middleware.Auth())
app.Use(middleware.RBAC("guide"))
app.Use(middleware.RateLimit())
app.Post("/venues", handlers.CreateVenue)
```

### 4. Provider Pattern (Flutter)
```dart
@riverpod
class VenuesNotifier extends _$VenuesNotifier {
  @override
  Future<List<Venue>> build() async {
    return await _venueService.getNearbyVenues();
  }
  
  Future<void> addVenue(Venue venue) async {
    // State güncelleme mantığı
  }
}
```

## Veri Akışı

### 1. Mekan Keşif Akışı
```
User Location Request
    ↓
GPS Service (Flutter)
    ↓
API Request: GET /venues?lat=X&lng=Y
    ↓
PostGIS Query: ST_DWithin
    ↓
JSON Response: Venue List
    ↓
Map Rendering (Flutter)
```

### 2. Mekan Ekleme Akışı
```
Guide Form Submission
    ↓
Validation (Flutter)
    ↓
Photo Upload (S3)
    ↓
API Request: POST /venues
    ↓
Database Insert (Pending Status)
    ↓
Admin Notification
    ↓
Admin Review & Approval
    ↓
Status Update (Approved)
    ↓
Double-Verified Check
```

### 3. Authentication Akışı
```
User Login Request
    ↓
OAuth Provider (Google/Apple) / Email Validation
    ↓
JWT Token Generation
    ↓
Token Storage (Flutter Secure Storage)
    ↓
API Requests with Bearer Token
    ↓
JWT Middleware Validation
    ↓
User Context in Request
```

## Coğrafi Veri Yönetimi

### PostGIS Sorguları

#### Yakın Mekan Bulma
```sql
SELECT v.*, ST_Distance(v.location, ST_MakePoint($1, $2)::geography) AS distance
FROM venues v
WHERE v.status = 'approved'
  AND v.deleted_at IS NULL
  AND ST_DWithin(v.location, ST_MakePoint($1, $2)::geography, $3)
ORDER BY distance
LIMIT 50;
-- $1: lng, $2: lat, $3: radius (metre)
```

#### Şehir Sınırları İçinde
```sql
SELECT * FROM venues v
WHERE v.city = $1
  AND v.status = 'approved'
  AND v.deleted_at IS NULL
ORDER BY v.created_at DESC;
```

## Güvenlik Mimarisi

### 1. Authentication
- **JWT Tokens**: Access (15 min) + Refresh (30 gün)
- **OAuth Integration**: Google ve Apple Sign-In
- **Token Storage**: Flutter Secure Storage

### 2. Authorization (RBAC)
- **Role-based Access**: Traveler < Guide < Admin
- **Endpoint Protection**: Middleware ile rol kontrolü
- **Resource Ownership**: Kullanıcı kendi verilerine erişim

### 3. Data Protection
- **Input Validation**: Request seviyesinde doğrulama
- **SQL Injection Prevention**: Parameterized queries
- **Rate Limiting**: Spam ve abuse önleme
- **Soft Delete**: Veri kaybını önleme

## Performans Optimizasyonları

### 1. Database Indexing
- **Coğrafi Index**: GIST index for location queries
- **Composite Index**: city + status for city queries
- **Foreign Key Index**: Join performansı için

### 2. API Optimizasyonları
- **Pagination**: Büyük liste sorguları için
- **Field Selection**: Sadece gerekli alanları döndürme
- **Caching Headers**: Browser caching için

### 3. Mobile Optimizasyonları
- **Image Compression**: Otomatik fotoğraf sıkıştırma
- **Lazy Loading**: Sayfa bazlı veri yükleme
- **Offline Support**: Temel verilerin cache'lenmesi

---

*Bu belge, sistemin teknik mimarisini ve veri yapılarını tanımlar.*