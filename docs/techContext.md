# İtimat — Teknoloji Bağlamı

## Teknoloji Yığını

| Katman | Teknoloji | Versiyon | Açıklama |
|---|---|---|---|
| **Mobil Framework** | Flutter | 3.x | Cross-platform iOS + Android |
| **State Management** | Riverpod | 2.x | Reactive state management |
| **HTTP Client** | Dio | 5.x | HTTP requests ve interceptors |
| **Routing** | GoRouter | 10.x | Declarative routing |
| **Haritalar** | google_maps_flutter | 2.x | Harita entegrasyonu |
| **Backend Framework** | Go + Fiber | 1.19+ / 2.x | High-performance web framework |
| **Veritabanı** | PostgreSQL + PostGIS | 15+ / 3.x | İlişkisel DB + coğrafi extension |
| **Authentication** | JWT + OAuth | - | Token-based auth |
| **File Storage** | S3 Compatible | - | Fotoğraf depolama |
| **Deployment** | Docker | - | Containerization |

## Geliştirme Ortamı

### Gerekli Araçlar
- **Flutter SDK**: 3.13+
- **Go**: 1.19+
- **PostgreSQL**: 15+ with PostGIS extension
- **Docker & Docker Compose**: Development environment
- **Git**: Version control
- **IDE**: VS Code / Android Studio / GoLand

### Ortam Kurulumu
```bash
# Flutter dependencies
flutter pub get

# Go dependencies
go mod tidy

# Database setup
docker-compose up -d postgres

# Run migrations
go run cmd/migrate/main.go

# Start backend
go run cmd/api/main.go

# Start Flutter app
flutter run
```

## Backend API Yapısı

### Proje Dizin Yapısı
```
itimat-mobile-backend/
├── cmd/
│   └── api/main.go                 # Application entry point
├── internal/
│   ├── config/config.go            # Environment configuration
│   ├── database/
│   │   ├── db.go                   # PostgreSQL connection
│   │   └── migrations/             # SQL migration files
│   ├── middleware/
│   │   ├── auth.go                 # JWT validation
│   │   ├── rbac.go                 # Role-based access control
│   │   └── rate_limit.go           # Rate limiting
│   ├── models/                     # Data models
│   ├── handlers/                   # HTTP handlers
│   ├── services/                   # Business logic
│   └── repository/                 # Data access layer
├── pkg/
│   ├── jwt/jwt.go                  # JWT utilities
│   └── validator/validator.go      # Request validation
└── docker-compose.yml              # Development environment
```

## API Endpoint Listesi

### Authentication Endpoints
| Method | Path | Açıklama | Auth | Role |
|---|---|---|---|---|
| POST | `/api/v1/auth/register` | Email/şifre kayıt | - | Public |
| POST | `/api/v1/auth/login` | Email/şifre giriş | - | Public |
| POST | `/api/v1/auth/google` | Google OAuth | - | Public |
| POST | `/api/v1/auth/refresh` | Token yenileme | ✅ | Any |
| GET | `/api/v1/auth/me` | Kullanıcı profili | ✅ | Any |
| DELETE | `/api/v1/auth/me` | **Hesap silme** (App Store 5.1.1(v) + Google Play zorunluluğu). Anonimleştirme: kişisel veri temizlenir, mekan/yorum/doğrulama anonim kalır. Kimlik token'dan alınır (gövdeden ID kabul edilmez). Son admin engellenir (403). Geri alınamaz | ✅ | Any |
| POST | `/api/v1/auth/forgot-password` | Şifre sıfırlama kodu talebi | - | Public |
| POST | `/api/v1/auth/reset-password` | Kod ile yeni şifre belirleme | - | Public |

### Venue Endpoints
| Method | Path | Açıklama | Auth | Role |
|---|---|---|---|---|
| GET | `/api/v1/venues` | Yakın/şehir mekanları; `?q=<terim>&lat=&lng=` verilirse ad/şehir/ilçe/yemek kategorisi üzerinde Türkçe karakter duyarsız (unaccent) serbest metin araması yapar; `?city=<şehir>&district=<ilçe>&lat=&lng=` verilirse şehir+ilçe **kesin** filtresiyle listeler (limitsiz) — `district` yoksa mevcut şehir-only davranış (limit 10) değişmeden çalışır — `lat`/`lng` opsiyoneldir, verilirse mesafeye göre sıralanır | - | Public |
| GET | `/api/v1/venues/districts` | Onaylı mekanı olan benzersiz şehir/ilçe çiftleri (arama önerileri için) | - | Public |
| GET | `/api/v1/venues/by-category/:categoryId` | Kategoriye göre yakın mekanlar | - | Public |
| GET | `/api/v1/venues/:id` | Mekan detayı | - | Public |
| POST | `/api/v1/venues` | Mekan ekleme. `google_photo_urls` (sıralı liste, **ilki kapak**, en fazla 3) ile seçilen Google fotoğrafları indirilip kalıcı depoya yazılır; eski istemcilerin tekil `google_photo_url` alanı da kabul edilir | ✅ | Guide+ |
| PUT | `/api/v1/venues/:id` | Mekan güncelleme | ✅ | Owner/Admin |
| POST | `/api/v1/venues/:id/photos` | Fotoğraf yükleme. Mevcut fotoğrafları **silmez**, listeye ekler (mekan başına en fazla 5; aşılırsa 400). İlk fotoğraf kapak olur | ✅ | Guide+ |
| DELETE | `/api/v1/venues/:id/photos/:photoId` | Fotoğraf silme. Silinen kapaksa kalanların **en eskisi** otomatik kapak olur (mekan kapaksız kalmasın) | ✅ | Owner/Admin |
| PUT | `/api/v1/venues/:id/photos/:photoId/primary` | Kapak fotoğrafını değiştirir; diğerlerinin işareti tek transaction'da kaldırılır. Güncel fotoğraf listesini döner | ✅ | **Admin** |
| POST | `/api/v1/venues/:id/photos/backfill` | Fotoğrafsız kalmış mekanın fotoğraflarını `place_id` üzerinden Google'dan yeniden çeker (en fazla 3). Mekanda fotoğraf varsa 409 | ✅ | **Admin** |
| GET | `/api/v1/venues/place-preview` | Mekan ekleme önizlemesi: `?place_id=ChIJ...` veya `?lat=&lng=&name=`. Hex/eksik place_id'yi Places API ile gerçek `ChIJ`'ye çözer; ad/şehir/ilçe/fotoğraf, `city_allowed` ve **`existing_venue`** (mekan zaten kayıtlıysa özeti) döner | ✅ | Guide+ |
| POST | `/api/v1/venues/preview-location` | Google Maps linkini parse edip koordinat + place_id + mekan bilgilerini döndürür (kısa linkleri sunucuda çözer) | ✅ | Guide+ |
| GET | `/api/v1/venues/check-duplicate` | `?google_place_id=` ile erken duplicate kontrolü. `place-preview`'daki `existing_venue` ile aynı veriyi verir (ek güvence) | ✅ | Guide+ |
| GET | `/api/v1/places/photo` | Google Places fotoğraf proxy'si (`?ref=&w=`). API anahtarı sunucuda kalsın diye; görseli tam gövde olarak döner | ✅ | Guide+ |

### Review & Social Endpoints
| Method | Path | Açıklama | Auth | Role |
|---|---|---|---|---|
| GET | `/api/v1/venues/:id/reviews` | Mekan yorumları | - | Public |
| POST | `/api/v1/venues/:id/reviews` | Yorum ekleme | ✅ | Any |
| PUT | `/api/v1/venues/:id/reviews/:reviewId` | Yorum güncelleme | ✅ | Owner/Admin |
| DELETE | `/api/v1/venues/:id/reviews/:reviewId` | Yorum silme | ✅ | Owner/Admin |
| GET | `/api/v1/favorites` | Favori listesi | ✅ | Any |
| POST | `/api/v1/favorites/:venueId` | Favoriye ekleme | ✅ | Any |
| DELETE | `/api/v1/favorites/:venueId` | Favoriden çıkarma | ✅ | Any |

### Guide Endpoints
| Method | Path | Açıklama | Auth | Role |
|---|---|---|---|---|
| POST | `/api/v1/guide/apply` | Guide başvurusu | ✅ | Traveler |
| GET | `/api/v1/guide/my-venues` | Kendi mekanları | ✅ | Guide+ |

### Admin Endpoints
| Method | Path | Açıklama | Auth | Role |
|---|---|---|---|---|
| GET | `/api/v1/admin/venues/pending` | Bekleyen mekanlar | ✅ | Admin |
| PUT | `/api/v1/admin/venues/:id/approve` | Mekan onaylama | ✅ | Admin |
| PUT | `/api/v1/admin/venues/:id/reject` | Mekan reddetme | ✅ | Admin |
| GET | `/api/v1/admin/applications` | Guide başvuruları | ✅ | Admin |
| PUT | `/api/v1/admin/applications/:id/approve` | Başvuru onaylama | ✅ | Admin |
| PUT | `/api/v1/admin/applications/:id/reject` | Başvuru reddetme | ✅ | Admin |
| GET | `/api/v1/admin/audit-logs` | Audit log listesi | ✅ | Admin |
| GET | `/api/v1/admin/users` | Kullanıcı listesi | ✅ | Admin |

### Utility Endpoints
| Method | Path | Açıklama | Auth | Role |
|---|---|---|---|---|
| GET | `/api/v1/criteria` | Güven kriteri listesi | - | Public |
| GET | `/api/v1/food-categories` | Mutfak/yemek kategorileri | - | Public |
| GET/POST/PUT/DELETE | `/api/v1/admin/trust-criteria` | Güven kriteri yönetimi (CRUD) | ✅ | Admin |
| GET | `/health` | Health check | - | Public |

## Flutter Uygulama Yapısı

### Proje Dizin Yapısı
```
lib/
├── main.dart                       # App entry point
├── core/
│   ├── api/                        # API client setup
│   ├── auth/                       # Authentication logic
│   ├── models/                     # Data models
│   ├── router/                     # App routing
│   ├── theme/                      # UI theme
│   └── utils/                      # Utilities
├── features/
│   ├── auth/                       # Authentication screens
│   ├── map/                        # Map and discovery
│   ├── venue/                      # Venue details & management
│   ├── search/                     # Search functionality
│   ├── favorites/                  # Favorites management
│   ├── guide/                      # Guide-specific features
│   ├── admin/                      # Admin panel
│   ├── food_discovery/             # Yemek kategorisine göre mekan keşfi
│   └── profile/                    # User profile
└── shared/
    └── widgets/                    # Reusable widgets
```

### Key Dependencies
```yaml
dependencies:
  flutter: sdk: flutter
  riverpod: ^2.4.0
  flutter_riverpod: ^2.4.0
  dio: ^5.3.0
  go_router: ^10.0.0
  google_maps_flutter: ^2.5.0
  geolocator: ^9.0.0
  image_picker: ^1.0.0
  flutter_secure_storage: ^9.0.0
  google_sign_in: ^6.1.0
  cached_network_image: ^3.3.0
  permission_handler: ^11.0.0
```

## Teknik Kararlar ve Gerekçeler

### 1. Flutter vs Native
**Karar**: Flutter seçildi
**Gerekçe**: 
- Cross-platform development hızı
- Tek codebase ile iOS + Android
- Google Maps entegrasyonu mevcut
- Takım Flutter deneyimi var

### 2. Go + Fiber vs Node.js/Python
**Karar**: Go + Fiber seçildi
**Gerekçe**:
- Yüksek performans ve düşük memory kullanımı
- Concurrent request handling
- Strong typing ve compile-time error checking
- PostGIS ile iyi entegrasyon

### 3. PostgreSQL + PostGIS vs MongoDB
**Karar**: PostgreSQL + PostGIS seçildi
**Gerekçe**:
- Coğrafi sorguların performansı
- ACID compliance
- Complex relational queries
- Mature ecosystem

### 4. JWT vs Session-based Auth
**Karar**: JWT seçildi
**Gerekçe**:
- Stateless authentication
- Mobile app uyumluluğu
- Microservice architecture hazırlığı
- OAuth provider entegrasyonu

### 5. Riverpod vs Bloc/Provider
**Karar**: Riverpod seçildi
**Gerekçe**:
- Type-safe state management
- Compile-time dependency injection
- Better testing support
- Modern Flutter patterns

## Deployment Stratejisi

### Development Environment
```yaml
# docker-compose.yml
version: '3.8'
services:
  postgres:
    image: postgis/postgis:15-3.3
    environment:
      POSTGRES_DB: caizmi_dev
      POSTGRES_USER: dev
      POSTGRES_PASSWORD: dev123
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  backend:
    build: .
    ports:
      - "8080:8080"
    depends_on:
      - postgres
    environment:
      DATABASE_URL: postgres://dev:dev123@postgres:5432/caizmi_dev
```

### Production Considerations
- **Container Orchestration**: Kubernetes/Docker Swarm
- **Database**: Managed PostgreSQL (AWS RDS, Google Cloud SQL)
- **File Storage**: AWS S3, Google Cloud Storage
- **CDN**: CloudFlare for static assets
- **Monitoring**: Prometheus + Grafana
- **Logging**: ELK Stack (Elasticsearch, Logstash, Kibana)

## Güvenlik Yapılandırması

### API Security
```go
// CORS configuration
app.Use(cors.New(cors.Config{
    AllowOrigins: []string{"https://app.caizmi.com"},
    AllowMethods: []string{"GET", "POST", "PUT", "DELETE"},
    AllowHeaders: []string{"Authorization", "Content-Type"},
}))

// Rate limiting
app.Use(limiter.New(limiter.Config{
    Max:        100,
    Expiration: 1 * time.Minute,
}))

// Security headers
app.Use(helmet.New())
```

### Environment Variables
```bash
# Backend (.env)
DATABASE_URL=postgres://user:pass@localhost:5432/caizmi
JWT_SECRET=your-super-secret-key
JWT_EXPIRY=15m
REFRESH_TOKEN_EXPIRY=720h
GOOGLE_CLIENT_ID=your-google-client-id
GOOGLE_MAPS_API_KEY=your-google-maps-api-key
APPLE_TEAM_ID=your-apple-team-id
S3_BUCKET=caizmi-photos
S3_REGION=eu-west-1
S3_ACCESS_KEY=your-access-key
S3_SECRET_KEY=your-secret-key
```

## Performans Hedefleri

### API Performance
- **Response Time**: < 200ms (95th percentile)
- **Throughput**: 1000+ requests/second
- **Availability**: 99.9% uptime

### Mobile App Performance
- **App Launch**: < 3 seconds cold start
- **Map Loading**: < 2 seconds initial load
- **Image Loading**: Progressive loading with placeholders
- **Offline Support**: Cached data for 24 hours

### Database Performance
- **Query Optimization**: All queries < 100ms
- **Index Strategy**: Proper indexing for geo queries
- **Connection Pooling**: Max 100 concurrent connections

## Monitoring ve Logging

### Application Metrics
- **Request/Response Times**: API endpoint performance
- **Error Rates**: 4xx/5xx response tracking
- **User Activity**: Feature usage analytics
- **System Resources**: CPU, memory, disk usage

### Logging Strategy
```go
// Structured logging
log.Info("Venue created",
    zap.String("venue_id", venue.ID.String()),
    zap.String("user_id", user.ID.String()),
    zap.String("city", venue.City),
)
```

---

*Bu belge, projenin teknik implementasyon detaylarını ve teknoloji kararlarını tanımlar.*