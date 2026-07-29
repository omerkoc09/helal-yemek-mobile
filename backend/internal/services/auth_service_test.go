package services

import (
	"context"
	"errors"
	"strings"
	"sync"
	"testing"
	"time"

	"golang.org/x/crypto/bcrypt"
	"google.golang.org/api/idtoken"

	"github.com/omerkoc/itimat-mobile/internal/models"
	"github.com/omerkoc/itimat-mobile/internal/repository"
	jwtpkg "github.com/omerkoc/itimat-mobile/pkg/jwt"
)

const testSecret = "test-secret-en-az-32-karakter-uzunlugunda"

// --- fakeAuthUserStore ---

type fakeAuthUserStore struct {
	authUserStore // gömülü: override edilmeyen metot çağrılırsa panic

	exists            bool
	existsErr         error
	createErr         error
	byEmail           *models.User
	byEmailErr        error
	byProvider        *models.User
	byProviderErr     error
	byID              *models.User
	byIDErr           error
	updateErr         error
	updatePasswordErr error

	gotCreated        *models.User
	gotFindEmail      string
	gotPasswordUserID string
	gotPasswordHash   string
}

func (f *fakeAuthUserStore) EmailExists(context.Context, string) (bool, error) {
	return f.exists, f.existsErr
}

func (f *fakeAuthUserStore) Create(_ context.Context, u *models.User) error {
	if f.createErr != nil {
		return f.createErr
	}
	u.ID = "new-user-id"
	f.gotCreated = u
	return nil
}

func (f *fakeAuthUserStore) FindByEmail(_ context.Context, email string) (*models.User, error) {
	f.gotFindEmail = email
	if f.byEmailErr != nil {
		return nil, f.byEmailErr
	}
	return f.byEmail, nil
}

func (f *fakeAuthUserStore) FindByProviderID(context.Context, string, string) (*models.User, error) {
	if f.byProviderErr != nil {
		return nil, f.byProviderErr
	}
	return f.byProvider, nil
}

func (f *fakeAuthUserStore) FindByID(context.Context, string) (*models.User, error) {
	if f.byIDErr != nil {
		return nil, f.byIDErr
	}
	return f.byID, nil
}

func (f *fakeAuthUserStore) Update(context.Context, string, *string, *string, *string, *string,
	*models.Role, *bool, *string) error {
	return f.updateErr
}

func (f *fakeAuthUserStore) UpdatePassword(_ context.Context, id, hashedPassword string) error {
	f.gotPasswordUserID = id
	f.gotPasswordHash = hashedPassword
	return f.updatePasswordErr
}

// fakeLoginRecorder — recordLogin ayrı bir goroutine'de çalıştığı için sayaç
// mutex ile korunuyor; aksi halde -race altında yarış raporlanır.
// Ayrıca ASLA nil bırakılmamalı: goroutine içindeki panic test binary'sini çökertir.
type fakeLoginRecorder struct {
	mu    sync.Mutex
	count int
}

func (f *fakeLoginRecorder) Record(context.Context, string) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.count++
	return nil
}

func newTestAuthService(store authUserStore) *AuthService {
	return &AuthService{
		userRepo:  store,
		loginRepo: &fakeLoginRecorder{},
		resetRepo: &fakePasswordResetStore{},
		email:     &fakeEmailService{},
		jwtSecret: testSecret,
		now:       time.Now,
	}
}

// newResetAuthService — şifre sıfırlama testleri için; reset deposu ve mail
// servisi çağıran tarafından verilir.
func newResetAuthService(store authUserStore, reset passwordResetStore, email EmailService) *AuthService {
	return &AuthService{
		userRepo:  store,
		loginRepo: &fakeLoginRecorder{},
		resetRepo: reset,
		email:     email,
		jwtSecret: testSecret,
		now:       time.Now,
	}
}

func hashOf(t *testing.T, pw string) *string {
	t.Helper()
	h, err := bcrypt.GenerateFromPassword([]byte(pw), bcrypt.MinCost)
	if err != nil {
		t.Fatalf("hash üretilemedi: %v", err)
	}
	s := string(h)
	return &s
}

// --- Register ---

func TestAuthServiceRegister(t *testing.T) {
	t.Run("başarılı kayıt token döndürür", func(t *testing.T) {
		store := &fakeAuthUserStore{}
		pair, err := newTestAuthService(store).Register(
			context.Background(), "a@b.com", "sifre123", "Ali", "Veli", "555")
		if err != nil {
			t.Fatalf("hata beklenmiyordu: %v", err)
		}
		if pair == nil || pair.AccessToken == "" || pair.RefreshToken == "" {
			t.Fatal("token çifti üretilmeliydi")
		}
	})

	t.Run("şifre düz metin saklanmaz", func(t *testing.T) {
		// En kritik kontrol: depoya giden kayıtta düz şifre bulunmamalı.
		store := &fakeAuthUserStore{}
		_, err := newTestAuthService(store).Register(
			context.Background(), "a@b.com", "sifre123", "Ali", "Veli", "555")
		if err != nil {
			t.Fatalf("hata: %v", err)
		}
		if store.gotCreated.PasswordHash == nil {
			t.Fatal("PasswordHash boş")
		}
		if *store.gotCreated.PasswordHash == "sifre123" {
			t.Fatal("şifre DÜZ METİN olarak saklandı")
		}
		if err := bcrypt.CompareHashAndPassword([]byte(*store.gotCreated.PasswordHash), []byte("sifre123")); err != nil {
			t.Fatalf("hash şifreyi doğrulamıyor: %v", err)
		}
	})

	t.Run("email küçük harfe çevrilir ve boşlukları kırpılır", func(t *testing.T) {
		// Normalize edilmezse aynı kişi iki hesap açabilir.
		store := &fakeAuthUserStore{}
		_, err := newTestAuthService(store).Register(
			context.Background(), "  A@B.CoM  ", "sifre123", " Ali ", " Veli ", " 555 ")
		if err != nil {
			t.Fatalf("hata: %v", err)
		}
		if store.gotCreated.Email != "a@b.com" {
			t.Fatalf("email normalize edilmedi: %q", store.gotCreated.Email)
		}
		if store.gotCreated.Name != "Ali" {
			t.Fatalf("ad kırpılmadı: %q", store.gotCreated.Name)
		}
	})

	t.Run("yeni kullanıcı traveler rolüyle açılır", func(t *testing.T) {
		// Kayıt akışıyla guide/admin rolü alınamamalı.
		store := &fakeAuthUserStore{}
		_, _ = newTestAuthService(store).Register(
			context.Background(), "a@b.com", "sifre123", "Ali", "Veli", "555")
		if store.gotCreated.Role != models.RoleTraveler {
			t.Fatalf("rol %q, beklenen traveler", store.gotCreated.Role)
		}
		if store.gotCreated.Provider != "email" {
			t.Fatalf("provider %q, beklenen email", store.gotCreated.Provider)
		}
	})

	t.Run("kısa şifre reddedilir", func(t *testing.T) {
		store := &fakeAuthUserStore{}
		_, err := newTestAuthService(store).Register(
			context.Background(), "a@b.com", "12345", "Ali", "Veli", "555")
		if err == nil {
			t.Fatal("6 karakterden kısa şifre reddedilmeliydi")
		}
		if store.gotCreated != nil {
			t.Fatal("geçersiz şifrede kullanıcı oluşturulmamalıydı")
		}
	})

	t.Run("6 karakter sınırda kabul", func(t *testing.T) {
		store := &fakeAuthUserStore{}
		_, err := newTestAuthService(store).Register(
			context.Background(), "a@b.com", "123456", "Ali", "Veli", "555")
		if err != nil {
			t.Fatalf("6 karakter kabul edilmeliydi: %v", err)
		}
	})

	t.Run("mükerrer email reddedilir", func(t *testing.T) {
		store := &fakeAuthUserStore{exists: true}
		_, err := newTestAuthService(store).Register(
			context.Background(), "a@b.com", "sifre123", "Ali", "Veli", "555")
		if err == nil {
			t.Fatal("kayıtlı email reddedilmeliydi")
		}
	})

	t.Run("depo hataları yukarı taşınır", func(t *testing.T) {
		store := &fakeAuthUserStore{existsErr: errors.New("db")}
		if _, err := newTestAuthService(store).Register(
			context.Background(), "a@b.com", "sifre123", "Ali", "Veli", "555"); err == nil {
			t.Fatal("EmailExists hatası dönmeliydi")
		}

		store2 := &fakeAuthUserStore{createErr: errors.New("db")}
		if _, err := newTestAuthService(store2).Register(
			context.Background(), "a@b.com", "sifre123", "Ali", "Veli", "555"); err == nil {
			t.Fatal("Create hatası dönmeliydi")
		}
	})
}

// --- Login ---

func TestAuthServiceLogin(t *testing.T) {
	activeUser := func() *models.User {
		return &models.User{
			ID: "u1", Email: "a@b.com", Role: models.RoleTraveler,
			IsActive: true, PasswordHash: hashOf(t, "dogruSifre"),
		}
	}

	t.Run("doğru şifre ile giriş", func(t *testing.T) {
		store := &fakeAuthUserStore{byEmail: activeUser()}
		pair, err := newTestAuthService(store).Login(context.Background(), "a@b.com", "dogruSifre")
		if err != nil {
			t.Fatalf("giriş başarısız: %v", err)
		}
		if pair.AccessToken == "" {
			t.Fatal("access token boş")
		}
	})

	t.Run("yanlış şifre reddedilir", func(t *testing.T) {
		store := &fakeAuthUserStore{byEmail: activeUser()}
		if _, err := newTestAuthService(store).Login(context.Background(), "a@b.com", "yanlis"); err == nil {
			t.Fatal("yanlış şifre kabul edildi")
		}
	})

	t.Run("hesap yoksa ve şifre yanlışsa AYNI mesaj döner", func(t *testing.T) {
		// Email enumeration koruması: saldırgan mesajdan hesabın varlığını
		// çıkaramamalı. İki mesaj ayrışırsa kayıtlı email listesi toplanabilir.
		noUser := &fakeAuthUserStore{byEmailErr: repository.ErrNotFound}
		_, errNoUser := newTestAuthService(noUser).Login(context.Background(), "yok@b.com", "x")

		wrongPw := &fakeAuthUserStore{byEmail: activeUser()}
		_, errWrongPw := newTestAuthService(wrongPw).Login(context.Background(), "a@b.com", "yanlis")

		if errNoUser == nil || errWrongPw == nil {
			t.Fatal("iki durum da hata dönmeliydi")
		}
		if errNoUser.Error() != errWrongPw.Error() {
			t.Fatalf("mesajlar ayrışıyor — hesap varlığı sızıyor:\n  yok: %q\n  yanlış şifre: %q",
				errNoUser.Error(), errWrongPw.Error())
		}
	})

	t.Run("devre dışı hesap reddedilir", func(t *testing.T) {
		u := activeUser()
		u.IsActive = false
		store := &fakeAuthUserStore{byEmail: u}
		_, err := newTestAuthService(store).Login(context.Background(), "a@b.com", "dogruSifre")
		if err == nil {
			t.Fatal("devre dışı hesapla giriş yapılabildi")
		}
		if !strings.Contains(err.Error(), "devre dışı") {
			t.Fatalf("beklenen 'devre dışı' mesajı, alınan: %q", err.Error())
		}
	})

	t.Run("sosyal giriş hesabına şifreyle girilemez", func(t *testing.T) {
		u := activeUser()
		u.PasswordHash = nil // Google/Apple ile açılmış hesap
		store := &fakeAuthUserStore{byEmail: u}
		if _, err := newTestAuthService(store).Login(context.Background(), "a@b.com", "herhangi"); err == nil {
			t.Fatal("şifresiz hesaba şifreyle giriş yapılabildi")
		}
	})

	t.Run("email normalize edilerek aranır", func(t *testing.T) {
		store := &fakeAuthUserStore{byEmail: activeUser()}
		if _, err := newTestAuthService(store).Login(context.Background(), "  A@B.COM ", "dogruSifre"); err != nil {
			t.Fatalf("büyük harfli email ile giriş yapılamadı: %v", err)
		}
	})
}

// --- RefreshTokens ---

func TestAuthServiceRefreshTokens(t *testing.T) {
	validRefresh := func(t *testing.T, userID string) string {
		t.Helper()
		pair, err := jwtpkg.GenerateTokenPair(userID, "a@b.com", "traveler", testSecret)
		if err != nil {
			t.Fatalf("token üretilemedi: %v", err)
		}
		return pair.RefreshToken
	}

	t.Run("geçerli token yeni çift üretir", func(t *testing.T) {
		store := &fakeAuthUserStore{byID: &models.User{ID: "u1", Email: "a@b.com", IsActive: true, Role: models.RoleTraveler}}
		pair, err := newTestAuthService(store).RefreshTokens(context.Background(), validRefresh(t, "u1"))
		if err != nil {
			t.Fatalf("yenileme başarısız: %v", err)
		}
		if pair.AccessToken == "" || pair.RefreshToken == "" {
			t.Fatal("yeni token çifti boş")
		}
	})

	t.Run("uydurma token reddedilir", func(t *testing.T) {
		store := &fakeAuthUserStore{byID: &models.User{ID: "u1", IsActive: true}}
		if _, err := newTestAuthService(store).RefreshTokens(context.Background(), "uydurma.token.dizesi"); err == nil {
			t.Fatal("geçersiz token kabul edildi")
		}
	})

	t.Run("başka secret ile imzalanmış token reddedilir", func(t *testing.T) {
		// Secret değişince eski token'lar geçersiz olmalı.
		other, err := jwtpkg.GenerateTokenPair("u1", "a@b.com", "traveler", "baska-secret-en-az-32-karakter-olsun")
		if err != nil {
			t.Fatalf("token üretilemedi: %v", err)
		}
		store := &fakeAuthUserStore{byID: &models.User{ID: "u1", IsActive: true}}
		if _, err := newTestAuthService(store).RefreshTokens(context.Background(), other.RefreshToken); err == nil {
			t.Fatal("farklı secret ile imzalanmış token kabul edildi")
		}
	})

	t.Run("access token refresh olarak kullanılamaz", func(t *testing.T) {
		pair, err := jwtpkg.GenerateTokenPair("u1", "a@b.com", "traveler", testSecret)
		if err != nil {
			t.Fatalf("token üretilemedi: %v", err)
		}
		store := &fakeAuthUserStore{byID: &models.User{ID: "u1", IsActive: true}}
		if _, err := newTestAuthService(store).RefreshTokens(context.Background(), pair.AccessToken); err == nil {
			t.Fatal("access token refresh olarak kabul edildi")
		}
	})

	t.Run("kullanıcı silinmişse reddedilir", func(t *testing.T) {
		store := &fakeAuthUserStore{byIDErr: repository.ErrNotFound}
		if _, err := newTestAuthService(store).RefreshTokens(context.Background(), validRefresh(t, "u1")); err == nil {
			t.Fatal("silinmiş kullanıcıya token verildi")
		}
	})

	t.Run("devre dışı hesap yenileyemez", func(t *testing.T) {
		// Hesap kapatıldıktan sonra elindeki refresh token'la devam edememeli.
		store := &fakeAuthUserStore{byID: &models.User{ID: "u1", IsActive: false}}
		if _, err := newTestAuthService(store).RefreshTokens(context.Background(), validRefresh(t, "u1")); err == nil {
			t.Fatal("devre dışı hesap token yeniledi")
		}
	})
}

// --- GetUser / UpdateProfile ---

func TestAuthServiceGetUserAndUpdateProfile(t *testing.T) {
	t.Run("GetUser kullanıcıyı döndürür", func(t *testing.T) {
		store := &fakeAuthUserStore{byID: &models.User{ID: "u1", Email: "a@b.com"}}
		u, err := newTestAuthService(store).GetUser(context.Background(), "u1")
		if err != nil || u.ID != "u1" {
			t.Fatalf("kullanıcı alınamadı: %v", err)
		}
	})

	t.Run("GetUser hatası taşınır", func(t *testing.T) {
		store := &fakeAuthUserStore{byIDErr: repository.ErrNotFound}
		if _, err := newTestAuthService(store).GetUser(context.Background(), "u1"); err == nil {
			t.Fatal("hata dönmeliydi")
		}
	})

	t.Run("UpdateProfile güncelleyip güncel kaydı döndürür", func(t *testing.T) {
		store := &fakeAuthUserStore{byID: &models.User{ID: "u1", Name: "Yeni"}}
		name := "Yeni"
		u, err := newTestAuthService(store).UpdateProfile(context.Background(), "u1", &name, nil, nil)
		if err != nil {
			t.Fatalf("güncelleme başarısız: %v", err)
		}
		if u.Name != "Yeni" {
			t.Fatalf("güncel kayıt dönmedi: %+v", u)
		}
	})

	t.Run("UpdateProfile hatası taşınır", func(t *testing.T) {
		store := &fakeAuthUserStore{updateErr: errors.New("db")}
		if _, err := newTestAuthService(store).UpdateProfile(context.Background(), "u1", nil, nil, nil); err == nil {
			t.Fatal("hata dönmeliydi")
		}
	})
}

// --- LoginWithGoogle ---
//
// idtoken.Validate canlı Google servisine ağ çağrısı yapar; sahte bir
// googleValidator enjekte ederek doğrulama SONRASI iş kuralları test edilir.

func TestAuthServiceLoginWithGoogle(t *testing.T) {
	// googlePayload — belirtilen sub/email/name ile doğrulanmış sayılan token.
	googlePayload := func(sub, email, name string) googleTokenValidator {
		return func(context.Context, string, string) (*idtoken.Payload, error) {
			return &idtoken.Payload{
				Subject: sub,
				Claims: map[string]interface{}{
					"email":   email,
					"name":    name,
					"picture": "https://pic",
				},
			}, nil
		}
	}

	withGoogle := func(store authUserStore, v googleTokenValidator) *AuthService {
		s := newTestAuthService(store)
		s.googleValidator = v
		return s
	}

	t.Run("geçersiz token reddedilir", func(t *testing.T) {
		failing := func(context.Context, string, string) (*idtoken.Payload, error) {
			return nil, errors.New("doğrulama başarısız")
		}
		store := &fakeAuthUserStore{}
		if _, err := withGoogle(store, failing).LoginWithGoogle(context.Background(), "bad"); err == nil {
			t.Fatal("geçersiz Google token kabul edildi")
		}
		if store.gotCreated != nil {
			t.Fatal("token geçersizken kullanıcı oluşturuldu")
		}
	})

	t.Run("yeni kullanıcı google provider ile oluşturulur", func(t *testing.T) {
		// Hiç hesap yok: hem provider hem email araması ErrNotFound döner.
		store := &fakeAuthUserStore{
			byProviderErr: repository.ErrNotFound,
			byEmailErr:    repository.ErrNotFound,
		}
		pair, err := withGoogle(store, googlePayload("g-sub", "New@Gmail.com", "Yeni Kişi")).
			LoginWithGoogle(context.Background(), "tok")
		if err != nil {
			t.Fatalf("giriş başarısız: %v", err)
		}
		if pair.AccessToken == "" {
			t.Fatal("access token boş")
		}
		if store.gotCreated == nil {
			t.Fatal("yeni kullanıcı oluşturulmadı")
		}
		if store.gotCreated.Provider != "google" {
			t.Fatalf("provider %q, beklenen google", store.gotCreated.Provider)
		}
		if store.gotCreated.ProviderID == nil || *store.gotCreated.ProviderID != "g-sub" {
			t.Fatal("provider ID token'daki sub ile eşleşmiyor")
		}
		if store.gotCreated.Email != "new@gmail.com" {
			t.Fatalf("email normalize edilmedi: %q", store.gotCreated.Email)
		}
		if store.gotCreated.Role != models.RoleTraveler {
			t.Fatalf("yeni sosyal kullanıcı %q rolüyle açıldı, beklenen traveler", store.gotCreated.Role)
		}
		// Regresyon kilidi: yeni kullanıcı aktif oluşturulmalı. Create yalnızca
		// id/tarih'i geri okuduğu için IsActive struct'ta açıkça set edilmezse
		// DB default'u (true) yansımaz ve kullanıcı ilk girişte kilitlenir.
		if !store.gotCreated.IsActive {
			t.Fatal("yeni Google kullanıcısı aktif olmayan (is_active=false) oluşturuldu — ilk girişte kilitlenir")
		}
	})

	t.Run("aynı email'li mevcut hesaba bağlanır, yeni kayıt açılmaz", func(t *testing.T) {
		// Email/şifre ile açılmış hesap Google ile giriş yapınca mükerrer
		// kullanıcı YARATILMAMALI; mevcut hesapla giriş yapılmalı.
		existing := &models.User{ID: "u1", Email: "a@b.com", IsActive: true, Role: models.RoleTraveler}
		store := &fakeAuthUserStore{
			byProviderErr: repository.ErrNotFound,
			byEmail:       existing,
		}
		if _, err := withGoogle(store, googlePayload("g-sub", "a@b.com", "Ali")).
			LoginWithGoogle(context.Background(), "tok"); err != nil {
			t.Fatalf("giriş başarısız: %v", err)
		}
		if store.gotCreated != nil {
			t.Fatal("mevcut email'e rağmen yeni kullanıcı oluşturuldu — mükerrer hesap")
		}
	})

	t.Run("mevcut provider hesabıyla giriş", func(t *testing.T) {
		linked := &models.User{ID: "u1", Email: "a@b.com", IsActive: true, Role: models.RoleTraveler}
		store := &fakeAuthUserStore{byProvider: linked}
		pair, err := withGoogle(store, googlePayload("g-sub", "a@b.com", "Ali")).
			LoginWithGoogle(context.Background(), "tok")
		if err != nil {
			t.Fatalf("giriş başarısız: %v", err)
		}
		if pair.AccessToken == "" {
			t.Fatal("access token boş")
		}
		if store.gotCreated != nil {
			t.Fatal("mevcut provider hesabında yeni kullanıcı oluşturuldu")
		}
	})

	t.Run("devre dışı hesap reddedilir", func(t *testing.T) {
		disabled := &models.User{ID: "u1", Email: "a@b.com", IsActive: false}
		store := &fakeAuthUserStore{byProvider: disabled}
		if _, err := withGoogle(store, googlePayload("g-sub", "a@b.com", "Ali")).
			LoginWithGoogle(context.Background(), "tok"); err == nil {
			t.Fatal("devre dışı hesapla Google girişi yapıldı")
		}
	})

	t.Run("beklenmeyen depo hatası taşınır", func(t *testing.T) {
		// FindByEmail ErrNotFound dışında bir hata dönerse yeni hesap açmaya
		// çalışmadan hatayı yukarı taşımalı.
		store := &fakeAuthUserStore{
			byProviderErr: repository.ErrNotFound,
			byEmailErr:    errors.New("db patladı"),
		}
		if _, err := withGoogle(store, googlePayload("g-sub", "a@b.com", "Ali")).
			LoginWithGoogle(context.Background(), "tok"); err == nil {
			t.Fatal("depo hatası yutuldu")
		}
		if store.gotCreated != nil {
			t.Fatal("depo hatasında kullanıcı oluşturuldu")
		}
	})
}

// --- fakePasswordResetStore ---

type fakePasswordResetStore struct {
	createErr    error
	recentCount  int
	recentErr    error
	claimTokenID string
	claimHash    string
	claimErr     error
	markUsedErr  error

	createCalls     int
	invalidateCalls int
	markUsedCalls   int
	gotCodeHash     string
	gotExpiresAt    time.Time
}

func (f *fakePasswordResetStore) Create(_ context.Context, _, codeHash string, expiresAt time.Time) error {
	f.createCalls++
	f.gotCodeHash = codeHash
	f.gotExpiresAt = expiresAt
	return f.createErr
}

func (f *fakePasswordResetStore) ClaimAttempt(context.Context, string) (string, string, error) {
	if f.claimErr != nil {
		return "", "", f.claimErr
	}
	return f.claimTokenID, f.claimHash, nil
}

func (f *fakePasswordResetStore) MarkUsed(context.Context, string) error {
	f.markUsedCalls++
	return f.markUsedErr
}

func (f *fakePasswordResetStore) CountRecentByUserID(context.Context, string, time.Time) (int, error) {
	return f.recentCount, f.recentErr
}

func (f *fakePasswordResetStore) InvalidateActiveByUserID(context.Context, string) error {
	f.invalidateCalls++
	return nil
}

func (f *fakePasswordResetStore) DeleteExpiredBefore(context.Context, time.Time) error {
	return nil
}

// --- fakeEmailService ---

type fakeEmailService struct {
	mu       sync.Mutex
	err      error
	sends    int
	lastTo   string
	lastBody string

	// release — verilirse Send bu kanaldan bir değer alana kadar bloklanır.
	// Asenkronluğu ispatlamak için kullanılır: Send askıdayken çağıran
	// fonksiyonun ZATEN dönmüş olduğu gösterilebilir. nil ise bloklamaz.
	release chan struct{}
}

func (f *fakeEmailService) Send(to, _, htmlBody string) error {
	if f.release != nil {
		<-f.release
	}
	f.mu.Lock()
	defer f.mu.Unlock()
	f.sends++
	f.lastTo = to
	f.lastBody = htmlBody
	return f.err
}

func (f *fakeEmailService) sendCount() int {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.sends
}

func (f *fakeEmailService) body() string {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.lastBody
}

// --- RequestPasswordReset ---

func TestAuthServiceRequestPasswordReset(t *testing.T) {
	emailUser := func() *models.User {
		return &models.User{
			ID: "u1", Email: "a@b.com", Name: "Ayşe",
			Role: models.RoleTraveler, IsActive: true,
			PasswordHash: hashOf(t, "eskiSifre"),
		}
	}

	// waitForSends — mail arka planda gönderildiği için kısa süre bekler.
	waitForSends := func(t *testing.T, mail *fakeEmailService, want int) {
		t.Helper()
		for i := 0; i < 100; i++ {
			if mail.sendCount() == want {
				return
			}
			time.Sleep(5 * time.Millisecond)
		}
		t.Fatalf("beklenen mail sayısı %d, gerçekleşen %d", want, mail.sendCount())
	}

	t.Run("geçerli kullanıcı: token oluşur ve mail gider", func(t *testing.T) {
		store := &fakeAuthUserStore{byEmail: emailUser()}
		reset := &fakePasswordResetStore{}
		mail := &fakeEmailService{}

		if err := newResetAuthService(store, reset, mail).
			RequestPasswordReset(context.Background(), "a@b.com"); err != nil {
			t.Fatalf("hata döndü: %v", err)
		}
		waitForSends(t, mail, 1)

		if reset.createCalls != 1 {
			t.Fatalf("token oluşturulmadı: %d çağrı", reset.createCalls)
		}
		if reset.invalidateCalls != 1 {
			t.Error("eski tokenlar geçersizleştirilmedi")
		}
	})

	t.Run("ağır iş (hash+DB+mail) askıdayken fonksiyon zaten dönmüş olmalı", func(t *testing.T) {
		// Bu test asenkronluğun KENDİSİNİ doğrular — mail sonunda gitti mi
		// değil, RequestPasswordReset DÖNERKEN henüz gitmemiş miydi. "go"
		// anahtar kelimesi kaldırılırsa Send() içindeki <-release bloklaması
		// RequestPasswordReset'i de bloklar ve bu test timeout ile kırılır.
		store := &fakeAuthUserStore{byEmail: emailUser()}
		reset := &fakePasswordResetStore{}
		mail := &fakeEmailService{release: make(chan struct{})}

		done := make(chan error, 1)
		go func() {
			done <- newResetAuthService(store, reset, mail).
				RequestPasswordReset(context.Background(), "a@b.com")
		}()

		select {
		case err := <-done:
			if err != nil {
				t.Fatalf("hata döndü: %v", err)
			}
		case <-time.After(2 * time.Second):
			t.Fatal("RequestPasswordReset, mail Send askıdayken dönmedi — arka plan işi senkrona kaçmış olabilir")
		}

		// Fonksiyon döndü ama mail hâlâ göndermedi (release henüz verilmedi).
		if mail.sendCount() != 0 {
			t.Fatal("mail, release verilmeden gönderilmiş görünüyor — test kurulumu bozuk")
		}

		close(mail.release)
		waitForSends(t, mail, 1)
	})

	t.Run("kod DB'ye ham değil hash'li yazılır", func(t *testing.T) {
		// Güvenlik iddiasının testle bağlanması: ham kod saklanırsa DB'yi
		// okuyan biri doğrudan kullanabilir.
		store := &fakeAuthUserStore{byEmail: emailUser()}
		reset := &fakePasswordResetStore{}
		mail := &fakeEmailService{}

		if err := newResetAuthService(store, reset, mail).
			RequestPasswordReset(context.Background(), "a@b.com"); err != nil {
			t.Fatalf("hata döndü: %v", err)
		}
		waitForSends(t, mail, 1)

		if len(reset.gotCodeHash) == 6 {
			t.Fatal("kod ham olarak saklanmış")
		}
		// Mailde giden kod, saklanan hash ile eşleşmeli.
		var sentCode string
		for _, line := range strings.Split(mail.body(), "\n") {
			if strings.Contains(line, "letter-spacing") {
				start := strings.Index(line, ">") + 1
				end := strings.LastIndex(line, "<")
				sentCode = line[start:end]
			}
		}
		if sentCode == "" {
			t.Fatal("mail gövdesinden kod okunamadı")
		}
		if err := bcrypt.CompareHashAndPassword([]byte(reset.gotCodeHash), []byte(sentCode)); err != nil {
			t.Fatalf("saklanan hash, gönderilen kodla eşleşmiyor: %v", err)
		}
	})

	t.Run("geçerlilik süresi 15 dakika", func(t *testing.T) {
		store := &fakeAuthUserStore{byEmail: emailUser()}
		reset := &fakePasswordResetStore{}
		mail := &fakeEmailService{}

		before := time.Now()
		if err := newResetAuthService(store, reset, mail).
			RequestPasswordReset(context.Background(), "a@b.com"); err != nil {
			t.Fatalf("hata döndü: %v", err)
		}
		waitForSends(t, mail, 1)

		want := before.Add(15 * time.Minute)
		diff := reset.gotExpiresAt.Sub(want)
		if diff < -time.Second || diff > 5*time.Second {
			t.Fatalf("expires_at 15 dk değil: %v", reset.gotExpiresAt)
		}
	})

	// Negatif senaryolar: HEPSİ nil hata döner (enumeration koruması), bu yüzden
	// ayırt edici sinyal mailin GİTMEMESİ ve token OLUŞMAMASI.
	negatives := []struct {
		name  string
		store *fakeAuthUserStore
		reset *fakePasswordResetStore
	}{
		{
			name:  "kullanıcı yok",
			store: &fakeAuthUserStore{byEmailErr: repository.ErrNotFound},
			reset: &fakePasswordResetStore{},
		},
		{
			name: "google hesabı (şifresiz)",
			store: &fakeAuthUserStore{byEmail: &models.User{
				ID: "u2", Email: "g@b.com", Role: models.RoleTraveler,
				IsActive: true, Provider: "google", PasswordHash: nil,
			}},
			reset: &fakePasswordResetStore{},
		},
		{
			name: "pasif hesap",
			store: &fakeAuthUserStore{byEmail: &models.User{
				ID: "u3", Email: "p@b.com", Role: models.RoleTraveler,
				IsActive: false, PasswordHash: hashOf(t, "x"),
			}},
			reset: &fakePasswordResetStore{},
		},
		{
			name:  "saatlik limit dolu",
			store: &fakeAuthUserStore{byEmail: emailUser()},
			reset: &fakePasswordResetStore{recentCount: 3},
		},
	}

	for _, tc := range negatives {
		t.Run(tc.name+": mail gitmez, hata dönmez", func(t *testing.T) {
			mail := &fakeEmailService{}
			err := newResetAuthService(tc.store, tc.reset, mail).
				RequestPasswordReset(context.Background(), "a@b.com")
			if err != nil {
				t.Fatalf("hata sızdı: %v", err)
			}
			// Asenkron mail'e fırsat tanı; yine de gitmemeli.
			time.Sleep(50 * time.Millisecond)
			if mail.sendCount() != 0 {
				t.Error("mail gönderildi, gönderilmemeliydi")
			}
			if tc.reset.createCalls != 0 {
				t.Error("token oluşturuldu, oluşturulmamalıydı")
			}
		})
	}

	t.Run("SMTP hatası kullanıcıya sızmaz", func(t *testing.T) {
		store := &fakeAuthUserStore{byEmail: emailUser()}
		mail := &fakeEmailService{err: errors.New("smtp patladı")}

		if err := newResetAuthService(store, &fakePasswordResetStore{}, mail).
			RequestPasswordReset(context.Background(), "a@b.com"); err != nil {
			t.Fatalf("SMTP hatası sızdı: %v", err)
		}
	})

	t.Run("email normalize edilir", func(t *testing.T) {
		// Login/Register ToLower+TrimSpace yapıyor, FindByEmail birebir eşleşme
		// arıyor. Normalize edilmezse boşluklu/büyük harfli girişte mail gitmez.
		store := &fakeAuthUserStore{byEmail: emailUser()}
		mail := &fakeEmailService{}

		if err := newResetAuthService(store, &fakePasswordResetStore{}, mail).
			RequestPasswordReset(context.Background(), "  A@B.CoM  "); err != nil {
			t.Fatalf("hata döndü: %v", err)
		}
		if store.gotFindEmail != "a@b.com" {
			t.Fatalf("email normalize edilmedi: %q", store.gotFindEmail)
		}
	})
}
