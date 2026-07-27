# Mobil Refactor — 3 Madde Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Profili (ad/soyad/telefon) düzenlenebilir yap, yorumlarda gerçek ismi ("Ad S.") göster, demote sonrası takılan rehber başvurusunu çöz.

**Architecture:** Üç bağımsız parça. (1) Mobil-only profil formu genişletme. (2) Backend review sorgusuna `users` join + görünen ad üretimi + mobil metin. (3) Backend'de `cancelled` başvuru durumu + demote hook'u + mobil davranış.

**Tech Stack:** Backend Go + Fiber + pgx (PostgreSQL/PostGIS); mobil Flutter + Riverpod + Freezed + Dio. Integration testler testcontainers (`//go:build integration`).

## Global Constraints

- Backend integration testler `//go:build integration` tag'i ile yazılır; `repository_test` paketinde, `testPool` / `truncate(t)` / `insertTestUser(t)` (guide) / `insertTraveler(t)` (traveler) helper'ları kullanılır.
- Integration test çalıştırma: `cd backend && go test -tags=integration ./internal/repository/ -run <TestAdı> -v` (Docker gerektirir).
- Mobil Freezed modelleri değişince kod üretimi: `cd mobile && dart run build_runner build --delete-conflicting-outputs`.
- Mobil doğrulama: `cd mobile && flutter analyze` (yeni hata eklenmemeli).
- `guide_applications.status` kolonu `VARCHAR(20)`, CHECK constraint yok → yeni `cancelled` değeri migration gerektirmez.
- Görünen ad formatı: `Ad` + (soyad varsa) ` ` + soyadın ilk harfi (Türkçe karakter için `[]rune`, `strings.ToUpper`) + `.` → örn. `Ahmet Y.`. Üretim **backend'de** yapılır.
- Email salt-okunur kalır; değiştirilmez.

---

## Task 1: Mobil profil formuna soyad + telefon ekle

**Files:**
- Modify: `mobile/lib/features/profile/providers/profile_provider.dart` (`EditProfileNotifier.updateProfile`)
- Modify: `mobile/lib/features/profile/screens/edit_profile_screen.dart`
- Modify: `mobile/lib/features/profile/screens/profile_screen.dart` (`_ProfileHeader`)

**Interfaces:**
- Consumes: `User` modeli (zaten `surname`, `phone` alanları var); backend `PUT /auth/profile` (zaten `name`, `surname`, `phone` kabul ediyor — `auth_handler.go:149`).
- Produces: `EditProfileNotifier.updateProfile({required String name, String? surname, String? phone})`.

> Not: Bu task tamamen mobil ve backend zaten hazır olduğundan unit/integration test eklenmez; doğrulama `flutter analyze` + manuel. Adımlar küçük tutuldu.

- [ ] **Step 1: `updateProfile` imzasını genişlet**

`mobile/lib/features/profile/providers/profile_provider.dart` içinde `EditProfileNotifier.updateProfile`'ı değiştir:

```dart
  Future<void> updateProfile({
    required String name,
    String? surname,
    String? phone,
  }) async {
    state = state.copyWith(isLoading: true, error: null, isSuccess: false);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.put(
        ApiEndpoints.updateProfile,
        data: {
          'name': name,
          if (surname != null) 'surname': surname,
          if (phone != null) 'phone': phone,
        },
      );
      final user = User.fromJson(response.data as Map<String, dynamic>);
      ref.read(authProvider.notifier).updateUser(user);
      state = state.copyWith(isLoading: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Profil güncellenemedi. Lütfen tekrar deneyin.',
      );
    }
  }
```

- [ ] **Step 2: Edit ekranına soyad + telefon controller'larını ekle**

`mobile/lib/features/profile/screens/edit_profile_screen.dart` — `_EditProfileScreenState` içinde controller alanlarını ve `initState`/`dispose`'u güncelle:

```dart
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _surnameController;
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _surnameController = TextEditingController(text: user?.surname ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
```

- [ ] **Step 3: `_handleSave`'i yeni alanları gönderecek şekilde güncelle**

Aynı dosyada:

```dart
  void _handleSave() {
    if (!_formKey.currentState!.validate()) return;

    ref.read(editProfileProvider.notifier).updateProfile(
          name: _nameController.text.trim(),
          surname: _surnameController.text.trim().isEmpty
              ? null
              : _surnameController.text.trim(),
          phone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
        );
  }
```

- [ ] **Step 4: Soyad ve telefon alanlarını forma ekle**

Aynı dosyada, "Ad" `TextFormField`'ından sonra (mevcut `const SizedBox(height: 8)`'den önce) ekle. Ad alanının label'ını `'Ad Soyad'` yerine `'Ad'` yap:

```dart
              const SizedBox(height: 16),

              // Soyad (opsiyonel)
              TextFormField(
                controller: _surnameController,
                decoration: const InputDecoration(
                  labelText: 'Soyad',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isNotEmpty && v.length < 2) {
                    return 'Soyad en az 2 karakter olmalıdır';
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              // Telefon (opsiyonel)
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Telefon',
                  prefixIcon: Icon(Icons.phone_outlined),
                  hintText: '5XX XXX XX XX',
                ),
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return null;
                  final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
                  if (digits.length < 10 || digits.length > 13) {
                    return 'Geçerli bir telefon numarası girin';
                  }
                  return null;
                },
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _handleSave(),
              ),
```

Mevcut "Ad" alanındaki `onFieldSubmitted: (_) => _handleSave()` ve `textInputAction: TextInputAction.done` satırlarını `textInputAction: TextInputAction.next` yap (artık son alan telefon).

- [ ] **Step 5: Profil header'da ad + soyad göster**

`mobile/lib/features/profile/screens/profile_screen.dart` — `_ProfileHeader.build` içindeki isim `Text`'ini değiştir:

```dart
        Text(
          '${user.name}${user.surname != null && user.surname!.isNotEmpty ? ' ${user.surname}' : ''}',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
```

- [ ] **Step 6: Analyze ile doğrula**

Run: `cd mobile && flutter analyze`
Expected: Yeni hata yok (önceden var olan uyarılar kapsam dışı).

- [ ] **Step 7: Commit**

```bash
git add mobile/lib/features/profile/providers/profile_provider.dart \
        mobile/lib/features/profile/screens/edit_profile_screen.dart \
        mobile/lib/features/profile/screens/profile_screen.dart
git commit -m "feat(mobile): profil düzenlemeye soyad + telefon alanları ekle"
```

---

## Task 2: Backend review modeline isim/avatar ekle + görünen ad helper'ı

**Files:**
- Modify: `backend/internal/models/review.go`
- Create: `backend/internal/repository/review_repo_integration_test.go`
- Modify: `backend/internal/repository/review_repo.go` (`ListByVenue`)

**Interfaces:**
- Produces: `models.Review.UserName *string` (`json:"user_name,omitempty"`), `models.Review.UserAvatar *string` (`json:"user_avatar,omitempty"`).
- Produces: `ReviewRepo.ListByVenue(ctx, venueID)` dönen her review'da `UserName` görünen ad (`Ad S.` formatı) ile dolu olur.

- [ ] **Step 1: Review modeline alanları ekle**

`backend/internal/models/review.go` struct'ına ekle (CreatedAt'ten önce):

```go
type Review struct {
	ID         string    `json:"id"`
	VenueID    string    `json:"venue_id"`
	UserID     string    `json:"user_id"`
	Rating     int       `json:"rating"`
	Comment    *string   `json:"comment"`
	UserName   *string   `json:"user_name,omitempty"`
	UserAvatar *string   `json:"user_avatar,omitempty"`
	CreatedAt  time.Time `json:"created_at"`
	UpdatedAt  time.Time `json:"updated_at"`
}
```

- [ ] **Step 2: Görünen ad için failing integration test yaz**

`backend/internal/repository/review_repo_integration_test.go` oluştur:

```go
//go:build integration

package repository_test

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/omerkoc/itimat-mobile/internal/repository"
)

// insertNamedUser — verilen ad/soyad ile traveler ekler, id döner.
func insertNamedUser(t *testing.T, name, surname string) string {
	t.Helper()
	var id string
	err := testPool.QueryRow(context.Background(),
		`INSERT INTO users (email, name, surname, password_hash, role)
		 VALUES ($1, $2, $3, 'hash', 'traveler') RETURNING id`,
		fmt.Sprintf("test-%d@example.com", time.Now().UnixNano()), name, surname,
	).Scan(&id)
	if err != nil {
		t.Fatalf("kullanıcı eklenemedi: %v", err)
	}
	return id
}

func TestListByVenue_ReturnsDisplayName(t *testing.T) {
	truncate(t)
	ctx := context.Background()

	guideID := insertTestUser(t) // mekanı ekleyen guide
	venueID := insertTestVenue(t, guideID, venueOpts{})

	userID := insertNamedUser(t, "Ahmet", "Yılmaz")
	comment := "harika"
	if _, err := testPool.Exec(ctx,
		`INSERT INTO reviews (venue_id, user_id, rating, comment)
		 VALUES ($1, $2, 5, $3)`,
		venueID, userID, comment,
	); err != nil {
		t.Fatalf("yorum eklenemedi: %v", err)
	}

	repo := repository.NewReviewRepo(testPool)
	reviews, err := repo.ListByVenue(ctx, venueID)
	if err != nil {
		t.Fatalf("ListByVenue hatası: %v", err)
	}
	if len(reviews) != 1 {
		t.Fatalf("1 yorum bekleniyordu, %d geldi", len(reviews))
	}
	if reviews[0].UserName == nil || *reviews[0].UserName != "Ahmet Y." {
		t.Fatalf("görünen ad 'Ahmet Y.' bekleniyordu, %v geldi", reviews[0].UserName)
	}
}

func TestListByVenue_NoSurnameShowsNameOnly(t *testing.T) {
	truncate(t)
	ctx := context.Background()

	guideID := insertTestUser(t)
	venueID := insertTestVenue(t, guideID, venueOpts{})

	userID := insertNamedUser(t, "Mehmet", "")
	if _, err := testPool.Exec(ctx,
		`INSERT INTO reviews (venue_id, user_id, rating) VALUES ($1, $2, 4)`,
		venueID, userID,
	); err != nil {
		t.Fatalf("yorum eklenemedi: %v", err)
	}

	repo := repository.NewReviewRepo(testPool)
	reviews, err := repo.ListByVenue(ctx, venueID)
	if err != nil {
		t.Fatalf("ListByVenue hatası: %v", err)
	}
	if reviews[0].UserName == nil || *reviews[0].UserName != "Mehmet" {
		t.Fatalf("görünen ad 'Mehmet' bekleniyordu, %v geldi", reviews[0].UserName)
	}
}
```

> Not: `users` tablosunda `surname` kolonu mevcut (User modeli kullanıyor). Boş soyad için NULL yerine `''` ekleniyor; sorgu ikisini de ele almalı.

- [ ] **Step 3: Testi çalıştır, fail ettiğini gör**

Run: `cd backend && go test -tags=integration ./internal/repository/ -run TestListByVenue -v`
Expected: FAIL — `UserName` nil (sorgu henüz join/ad üretmiyor).

- [ ] **Step 4: `ListByVenue`'ya join + görünen ad üretimini ekle**

`backend/internal/repository/review_repo.go` — `ListByVenue`'yu değiştir. `strings` import'unu ekle:

```go
import (
	"context"
	"errors"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/omerkoc/itimat-mobile/internal/models"
)
```

```go
func (r *ReviewRepo) ListByVenue(ctx context.Context, venueID string) ([]models.Review, error) {
	rows, err := r.db.Query(ctx,
		`SELECT r.id, r.venue_id, r.user_id, r.rating, r.comment, r.created_at, r.updated_at,
		        u.name, u.surname, u.avatar_url
		 FROM reviews r
		 LEFT JOIN users u ON u.id = r.user_id
		 WHERE r.venue_id = $1
		 ORDER BY r.created_at DESC`,
		venueID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []models.Review
	for rows.Next() {
		rv := models.Review{}
		var name, surname, avatar *string
		if err := rows.Scan(&rv.ID, &rv.VenueID, &rv.UserID, &rv.Rating, &rv.Comment,
			&rv.CreatedAt, &rv.UpdatedAt, &name, &surname, &avatar); err != nil {
			return nil, err
		}
		display := displayName(name, surname)
		rv.UserName = &display
		rv.UserAvatar = avatar
		list = append(list, rv)
	}
	if list == nil {
		list = []models.Review{}
	}
	return list, rows.Err()
}

// displayName — "Ad S." formatında görünen ad üretir. Ad boşsa "Kullanıcı" döner.
func displayName(name, surname *string) string {
	n := ""
	if name != nil {
		n = strings.TrimSpace(*name)
	}
	if n == "" {
		return "Kullanıcı"
	}
	s := ""
	if surname != nil {
		s = strings.TrimSpace(*surname)
	}
	if s == "" {
		return n
	}
	initial := []rune(s)[0]
	return n + " " + strings.ToUpper(string(initial)) + "."
}
```

- [ ] **Step 5: Testi çalıştır, geçtiğini gör**

Run: `cd backend && go test -tags=integration ./internal/repository/ -run TestListByVenue -v`
Expected: PASS (her iki test).

- [ ] **Step 6: Commit**

```bash
git add backend/internal/models/review.go \
        backend/internal/repository/review_repo.go \
        backend/internal/repository/review_repo_integration_test.go
git commit -m "feat(review): yoruma görünen ad (Ad S.) + avatar döndür (users join)"
```

---

## Task 3: Mobil — yorum kartında 'Anonim' yerine gerçek ismi göster

**Files:**
- Modify: `mobile/lib/features/venue/widgets/review_card.dart`

**Interfaces:**
- Consumes: Task 2'den gelen `review.userName` (artık dolu, `Ad S.` formatında). Mobil `Review` modeli (`mobile/lib/core/models/review.dart`) zaten `user_name`/`user_avatar` json key'lerini parse ediyor — model değişikliği gerekmez.

- [ ] **Step 1: 'Anonim' fallback'ini değiştir**

`mobile/lib/features/venue/widgets/review_card.dart` içinde iki yer var:

İsim `Text`'i (satır ~52):

```dart
                      Text(
                        review.userName ?? 'Kullanıcı',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
```

Avatar baş harfi (satır ~38) zaten `(review.userName ?? '?')[0]` kullanıyor — `'?'` fallback'i kalır (isim normalde dolu gelir), değişiklik gerekmez.

- [ ] **Step 2: Analyze ile doğrula**

Run: `cd mobile && flutter analyze`
Expected: Yeni hata yok.

- [ ] **Step 3: Commit**

```bash
git add mobile/lib/features/venue/widgets/review_card.dart
git commit -m "feat(mobile): yorum kartında 'Anonim' yerine gerçek ad göster"
```

---

## Task 4: Backend — `cancelled` durumu + demote'ta açık başvuruyu kapat

**Files:**
- Modify: `backend/internal/models/guide_application.go`
- Modify: `backend/internal/repository/guide_repo.go` (yeni `CancelOpenByUserID`)
- Create/Modify: `backend/internal/repository/guide_repo_integration_test.go`
- Modify: `backend/internal/handlers/admin_handler.go` (`UpdateUser`)

**Interfaces:**
- Produces: `models.ApplicationStatusCancelled ApplicationStatus = "cancelled"`.
- Produces: `GuideRepo.CancelOpenByUserID(ctx, userID string) error` — `status IN ('pending','approved')` olan kayıtları `cancelled` yapar (idempotent).
- Consumes: `AdminHandler.UpdateUser` mevcut demote bloğu (`admin_handler.go:411`).

- [ ] **Step 1: `cancelled` durumunu modele ekle**

`backend/internal/models/guide_application.go`:

```go
const (
	ApplicationStatusPending   ApplicationStatus = "pending"
	ApplicationStatusApproved  ApplicationStatus = "approved"
	ApplicationStatusRejected  ApplicationStatus = "rejected"
	ApplicationStatusCancelled ApplicationStatus = "cancelled"
)
```

- [ ] **Step 2: `CancelOpenByUserID` için failing integration test yaz**

`backend/internal/repository/guide_repo_integration_test.go` oluştur:

```go
//go:build integration

package repository_test

import (
	"context"
	"testing"

	"github.com/omerkoc/itimat-mobile/internal/repository"
)

func TestCancelOpenByUserID_CancelsPendingAndApproved(t *testing.T) {
	truncate(t)
	ctx := context.Background()
	repo := repository.NewGuideRepo(testPool)

	userID := insertTraveler(t)

	// Açık (pending) ve onaylı (approved) iki kayıt ekle.
	if _, err := testPool.Exec(ctx,
		`INSERT INTO guide_applications (user_id, status) VALUES ($1, 'approved'), ($1, 'pending')`,
		userID,
	); err != nil {
		t.Fatalf("başvuru eklenemedi: %v", err)
	}

	if err := repo.CancelOpenByUserID(ctx, userID); err != nil {
		t.Fatalf("CancelOpenByUserID hatası: %v", err)
	}

	// Artık pending başvuru kalmamalı.
	hasPending, err := repo.HasPendingApplication(ctx, userID)
	if err != nil {
		t.Fatalf("HasPendingApplication hatası: %v", err)
	}
	if hasPending {
		t.Fatalf("pending başvuru kalmamalıydı")
	}

	// İki kayıt da cancelled olmalı.
	var openCount int
	if err := testPool.QueryRow(ctx,
		`SELECT COUNT(*) FROM guide_applications WHERE user_id = $1 AND status IN ('pending','approved')`,
		userID,
	).Scan(&openCount); err != nil {
		t.Fatalf("sayım hatası: %v", err)
	}
	if openCount != 0 {
		t.Fatalf("açık başvuru kalmamalıydı, %d kaldı", openCount)
	}
}

func TestCancelOpenByUserID_NoOpenIsIdempotent(t *testing.T) {
	truncate(t)
	ctx := context.Background()
	repo := repository.NewGuideRepo(testPool)

	userID := insertTraveler(t)
	// Hiç başvuru yok — hata vermemeli.
	if err := repo.CancelOpenByUserID(ctx, userID); err != nil {
		t.Fatalf("açık başvuru yokken hata olmamalıydı: %v", err)
	}
}
```

- [ ] **Step 3: Testi çalıştır, fail ettiğini gör**

Run: `cd backend && go test -tags=integration ./internal/repository/ -run TestCancelOpenByUserID -v`
Expected: FAIL — `repo.CancelOpenByUserID undefined`.

- [ ] **Step 4: `CancelOpenByUserID`'yi implemente et**

`backend/internal/repository/guide_repo.go` — `HasPendingApplication`'dan sonra ekle:

```go
// CancelOpenByUserID — kullanıcının açık (pending/approved) guide başvurularını
// 'cancelled' yapar. Demote sırasında çağrılır; etkilenen kayıt yoksa sessizce geçer.
func (r *GuideRepo) CancelOpenByUserID(ctx context.Context, userID string) error {
	_, err := r.db.Exec(ctx,
		`UPDATE guide_applications
		 SET status = 'cancelled'
		 WHERE user_id = $1 AND status IN ('pending', 'approved')`,
		userID,
	)
	return err
}
```

- [ ] **Step 5: Testi çalıştır, geçtiğini gör**

Run: `cd backend && go test -tags=integration ./internal/repository/ -run TestCancelOpenByUserID -v`
Expected: PASS (her iki test).

- [ ] **Step 6: Demote hook'unu `UpdateUser`'a ekle**

`backend/internal/handlers/admin_handler.go` — mevcut referral revoke bloğunun (`admin_handler.go:411`) içine `CancelOpenByUserID` ekle:

```go
	// Guide'dan başka role düşürülüyorsa aktif referans kodunu iptal et
	// ve açık guide başvurularını kapat (kullanıcı yeniden başvurabilsin).
	if prevRole == models.RoleGuide && req.Role != nil && *req.Role != models.RoleGuide {
		if rerr := h.referralRepo.RevokeByGuideID(c.Context(), id); rerr != nil {
			log.Printf("[ADMIN] referans kodu iptal hatası user=%s: %v", id, rerr)
		}
		if cerr := h.guideRepo.CancelOpenByUserID(c.Context(), id); cerr != nil {
			log.Printf("[ADMIN] başvuru kapatma hatası user=%s: %v", id, cerr)
		}
	}
```

> Not: `AdminHandler`'ın `guideRepo` alanına erişimi olmalı. Yoksa Step 7'de eklenir; varsa Step 7 atlanır.

- [ ] **Step 7: `AdminHandler`'da `guideRepo` bağımlılığını doğrula/ekle**

Run: `grep -n "guideRepo\|GuideRepo\|referralRepo" backend/internal/handlers/admin_handler.go | head`
Eğer `guideRepo` alanı struct'ta yoksa: `AdminHandler` struct'ına `guideRepo *repository.GuideRepo` ekle, `NewAdminHandler` imzasına parametre ekle ve çağrıldığı yerde (`cmd/` veya router setup) `guideRepo` geçir. Eğer zaten varsa bu adım no-op.

Run (derleme doğrulaması): `cd backend && go build ./...`
Expected: Hata yok.

- [ ] **Step 8: Commit**

```bash
git add backend/internal/models/guide_application.go \
        backend/internal/repository/guide_repo.go \
        backend/internal/repository/guide_repo_integration_test.go \
        backend/internal/handlers/admin_handler.go
# (Step 7'de değiştiyse) cmd/router dosyalarını da ekle.
git commit -m "fix(guide): demote'ta açık başvuruyu cancelled yap (yeniden başvuru açılır)"
```

---

## Task 5: Mobil — demote sonrası `cancelled`/`approved` durumunda başvuru formu göster

**Files:**
- Modify: `mobile/lib/features/profile/screens/profile_screen.dart` (`_GuideApplicationCardState.build`)

**Interfaces:**
- Consumes: Task 4'ten sonra `GET /guide/my-application` demote edilen kullanıcı için `status: 'cancelled'` döner (veya eski tamamlanmamış kayıt yoksa 404).

- [ ] **Step 1: "inceleniyor" kartının yalnızca açık pending için göründüğünü doğrula/sıkılaştır**

`mobile/lib/features/profile/screens/profile_screen.dart` — `_GuideApplicationCardState.build` başındaki koşul zaten `appState.currentStatus == 'pending' || appState.isSuccess`. Bu doğru: `cancelled` ve `approved` buraya düşmez, forma düşer. Yorum satırını netleştir:

```dart
    // "inceleniyor" kartı yalnızca gerçek açık (pending) başvuru veya yeni
    // gönderilen kodsuz başvuru (isSuccess) için. cancelled/approved → form.
    if (appState.currentStatus == 'pending' || appState.isSuccess) {
```

- [ ] **Step 2: `rejected` banner koşulunun `cancelled`'ı kapsamadığını doğrula**

Aynı dosyada rejected banner'ı `if (appState.currentStatus == 'rejected')` ile korunuyor — `cancelled` bunu tetiklemez, sade form gösterilir. Ek değişiklik gerekmez. (Bu adım yalnızca doğrulama; kod değişikliği yoksa atla.)

- [ ] **Step 3: Analyze ile doğrula**

Run: `cd mobile && flutter analyze`
Expected: Yeni hata yok.

- [ ] **Step 4: Manuel doğrulama (davranış)**

Senaryo: guide kullanıcıyı admin panelden traveler'a düşür → mobilde profili aç.
Beklenen: "Başvurunuz inceleniyor" yerine **Rehber Ol** formu görünür; kullanıcı kodlu/kodsuz yeniden başvurabilir (409 almaz).

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/profile/screens/profile_screen.dart
git commit -m "fix(mobile): demote sonrası başvuru formu göster (cancelled/approved)"
```

---

## Task 6: progress.md güncelle

**Files:**
- Modify: `docs/progress.md`

- [ ] **Step 1: Tamamlanan işler bölümüne özet ekle**

`docs/progress.md` "Tamamlanan İşler" başlığının altına yeni bölüm ekle (en üste):

```markdown
### Mobil Refactor 3 Madde (Profil + Yorum İsmi + Demote Başvuru) — YENİ

> 2026-06-19'da yapıldı. Tasarım: `docs/superpowers/specs/2026-06-19-mobil-refactor-3-madde-design.md`. Plan: `docs/superpowers/plans/2026-06-19-mobil-refactor-3-madde.md`.

| Değişiklik | Durum | Detay |
|-----------|-------|-------|
| Profil zenginleştirme | ✅ | Edit ekranına soyad + telefon (opsiyonel) eklendi; email salt-okunur; header ad+soyad gösterir |
| Yorum ismi | ✅ | Review sorgusu users join'i + "Ad S." görünen ad; mobil 'Anonim' kaldırıldı |
| Demote başvuru | ✅ | `cancelled` durumu + demote'ta açık başvuru kapatma → kullanıcı yeniden başvurabilir |
```

Ayrıca "Revize Edilecek/mobil" listesindeki ilgili üç satırı (`-profili düzenle...`, `-yorumların anonimliği...`, `-status rehber->seyyah...`) işaretle veya kaldır.

- [ ] **Step 2: Commit**

```bash
git add docs/progress.md
git commit -m "docs(progress): mobil refactor 3 madde tamamlandı"
```

---

## Self-Review Notları

- **Spec kapsamı:** Madde 1 → Task 1; Madde 2 → Task 2+3; Madde 3 → Task 4+5. Hepsi karşılandı.
- **Migration:** `cancelled` için migration gerekmiyor (CHECK yok, VARCHAR(20)) — Global Constraints'te belirtildi.
- **Tip tutarlılığı:** `CancelOpenByUserID`, `displayName`, `updateProfile` imzaları task'lar arası tutarlı kullanıldı.
- **Bağımlılık:** Task 3, Task 2'ye bağlı (backend ad üretimi). Task 5, Task 4'e bağlı. Task 1 ve Task 6 bağımsız.
- **Belirsizlik:** Task 4 Step 7, `AdminHandler.guideRepo` varlığına bağlı — koşullu adım olarak yazıldı (grep ile doğrula).
