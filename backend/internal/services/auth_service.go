package services

import (
	"context"
	"errors"
	"log"
	"strings"
	"time"

	"golang.org/x/crypto/bcrypt"
	"google.golang.org/api/idtoken"

	"github.com/omerkoc/itimat-mobile/internal/models"
	"github.com/omerkoc/itimat-mobile/internal/repository"
	jwtpkg "github.com/omerkoc/itimat-mobile/pkg/jwt"
)

// authUserStore — AuthService'in kullanıcı deposundan ihtiyaç duyduğu metotlar.
// *repository.UserRepo bunu otomatik karşılar; testte sahte uygulama kullanılır.
type authUserStore interface {
	EmailExists(ctx context.Context, email string) (bool, error)
	Create(ctx context.Context, u *models.User) error
	FindByEmail(ctx context.Context, email string) (*models.User, error)
	FindByProviderID(ctx context.Context, provider, providerID string) (*models.User, error)
	FindByID(ctx context.Context, id string) (*models.User, error)
	Update(ctx context.Context, id string, name, surname, phone, email *string, role *models.Role, isActive *bool, guideCity *string) error
	UpdatePassword(ctx context.Context, id, hashedPassword string) error
	AnonymizeUser(ctx context.Context, id string) error
	CountActiveAdmins(ctx context.Context) (int, error)
}

// loginRecorder — giriş kaydını arka planda yazar.
type loginRecorder interface {
	Record(ctx context.Context, userID string) error
}

// passwordResetStore — şifre sıfırlama tokenları.
type passwordResetStore interface {
	Create(ctx context.Context, userID, codeHash string, expiresAt time.Time) error
	ClaimAttempt(ctx context.Context, userID string) (tokenID, codeHash string, err error)
	MarkUsed(ctx context.Context, tokenID string) error
	CountRecentByUserID(ctx context.Context, userID string, since time.Time) (int, error)
	InvalidateActiveByUserID(ctx context.Context, userID string) error
	DeleteExpiredBefore(ctx context.Context, cutoff time.Time) error
}

// googleTokenValidator — Google ID token doğrulaması. Varsayılan uygulama
// idtoken.Validate'i sarar; testte canlı ağ çağrısı yerine sahte verilir.
type googleTokenValidator func(ctx context.Context, idToken, audience string) (*idtoken.Payload, error)

type AuthService struct {
	userRepo        authUserStore
	loginRepo       loginRecorder
	resetRepo       passwordResetStore
	email           EmailService
	jwtSecret       string
	googleClientID  string
	googleValidator googleTokenValidator
	now             func() time.Time // testte sabitlenebilir saat
}

func NewAuthService(
	userRepo *repository.UserRepo,
	loginRepo *repository.LoginRepo,
	resetRepo *repository.PasswordResetRepo,
	email EmailService,
	jwtSecret, googleClientID string,
) *AuthService {
	return &AuthService{
		userRepo:        userRepo,
		loginRepo:       loginRepo,
		resetRepo:       resetRepo,
		email:           email,
		jwtSecret:       jwtSecret,
		googleClientID:  googleClientID,
		googleValidator: idtoken.Validate,
		now:             time.Now,
	}
}

// recordLogin — login kaydını request akışını bloklamadan, arka planda yazar.
// Kendi timeout'lu context'ini kullanır (request iptal olsa bile kayıt sürer ama
// DB takılırsa goroutine sonsuza kadar asılı kalmaz) ve hatayı yutmaz, loglar.
// "go s.recordLogin(userID)" şeklinde çağrılır.
func (s *AuthService) recordLogin(userID string) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := s.loginRepo.Record(ctx, userID); err != nil {
		log.Printf("login kaydı yazılamadı (user=%s): %v", userID, err)
	}
}

// Register — email/şifre ile yeni kullanıcı oluşturur.
func (s *AuthService) Register(ctx context.Context, email, password, name, surname, phone string) (*jwtpkg.TokenPair, error) {
	email = strings.ToLower(strings.TrimSpace(email))

	exists, err := s.userRepo.EmailExists(ctx, email)
	if err != nil {
		return nil, err
	}
	if exists {
		return nil, errors.New("bu email adresi zaten kullanılıyor")
	}

	if len(password) < 6 {
		return nil, errors.New("şifre en az 6 karakter olmalıdır")
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return nil, err
	}
	hashStr := string(hash)
	surnameStr := strings.TrimSpace(surname)
	phoneStr := strings.TrimSpace(phone)

	user := &models.User{
		Email:        email,
		PasswordHash: &hashStr,
		Name:         strings.TrimSpace(name),
		Surname:      &surnameStr,
		Phone:        &phoneStr,
		Role:         models.RoleTraveler,
		Provider:     "email",
	}
	if err := s.userRepo.Create(ctx, user); err != nil {
		return nil, err
	}
	pair, err := jwtpkg.GenerateTokenPair(user.ID, user.Email, string(user.Role), s.jwtSecret)
	if err != nil {
		return nil, err
	}
	if user.Role != models.RoleAdmin {
		go s.recordLogin(user.ID)
	}
	return pair, nil
}

// Login — email/şifre ile giriş yapar.
func (s *AuthService) Login(ctx context.Context, email, password string) (*jwtpkg.TokenPair, error) {
	email = strings.ToLower(strings.TrimSpace(email))

	user, err := s.userRepo.FindByEmail(ctx, email)
	if err != nil {
		return nil, errors.New("geçersiz email veya şifre")
	}
	if user.PasswordHash == nil {
		return nil, errors.New("bu hesap sosyal giriş ile oluşturulmuştur")
	}
	if err := bcrypt.CompareHashAndPassword([]byte(*user.PasswordHash), []byte(password)); err != nil {
		return nil, errors.New("geçersiz email veya şifre")
	}
	if !user.IsActive {
		return nil, errors.New("hesabınız devre dışı bırakılmıştır")
	}
	pair, err := jwtpkg.GenerateTokenPair(user.ID, user.Email, string(user.Role), s.jwtSecret)
	if err != nil {
		return nil, err
	}
	if user.Role != models.RoleAdmin {
		go s.recordLogin(user.ID)
	}
	return pair, nil
}

// LoginWithGoogle — Google ID token'ını doğrular, kullanıcı yoksa oluşturur.
func (s *AuthService) LoginWithGoogle(ctx context.Context, idToken string) (*jwtpkg.TokenPair, error) {
	payload, err := s.googleValidator(ctx, idToken, s.googleClientID)
	if err != nil {
		return nil, errors.New("geçersiz Google token")
	}

	providerID := payload.Subject
	email, _ := payload.Claims["email"].(string)
	name, _ := payload.Claims["name"].(string)
	picture, _ := payload.Claims["picture"].(string)

	email = strings.ToLower(email)

	user, err := s.userRepo.FindByProviderID(ctx, "google", providerID)
	if errors.Is(err, repository.ErrNotFound) {
		// Aynı email ile daha önce kaydolmuş hesap var mı kontrol et
		existing, emailErr := s.userRepo.FindByEmail(ctx, email)
		if emailErr == nil {
			// Mevcut hesapla giriş yap
			user = existing
		} else if errors.Is(emailErr, repository.ErrNotFound) {
			// Hiç hesap yok, yeni oluştur.
			// IsActive açıkça true: Create yalnızca id/created_at/updated_at'i
			// geri okuyor, DB'deki "DEFAULT true" struct'a yansımıyor. Yazılmazsa
			// hemen aşağıdaki !user.IsActive kontrolü yeni kullanıcıyı kilitler.
			user = &models.User{
				Email:      email,
				Name:       name,
				AvatarURL:  &picture,
				Role:       models.RoleTraveler,
				Provider:   "google",
				ProviderID: &providerID,
				IsActive:   true,
			}
			if err := s.userRepo.Create(ctx, user); err != nil {
				return nil, err
			}
		} else {
			return nil, emailErr
		}
	} else if err != nil {
		return nil, err
	}

	if !user.IsActive {
		return nil, errors.New("hesabınız devre dışı bırakılmıştır")
	}
	pair, err := jwtpkg.GenerateTokenPair(user.ID, user.Email, string(user.Role), s.jwtSecret)
	if err != nil {
		return nil, err
	}
	if user.Role != models.RoleAdmin {
		go s.recordLogin(user.ID)
	}
	return pair, nil
}

// RefreshTokens — refresh token ile yeni access + refresh token çifti döndürür.
func (s *AuthService) RefreshTokens(ctx context.Context, refreshToken string) (*jwtpkg.TokenPair, error) {
	userID, err := jwtpkg.ParseRefreshToken(refreshToken, s.jwtSecret)
	if err != nil {
		return nil, errors.New("geçersiz veya süresi dolmuş refresh token")
	}

	user, err := s.userRepo.FindByID(ctx, userID)
	if err != nil {
		return nil, errors.New("kullanıcı bulunamadı")
	}
	if !user.IsActive {
		return nil, errors.New("hesabınız devre dışı bırakılmıştır")
	}

	pair, err := jwtpkg.GenerateTokenPair(user.ID, user.Email, string(user.Role), s.jwtSecret)
	if err != nil {
		return nil, err
	}
	if user.Role != models.RoleAdmin {
		go s.recordLogin(user.ID)
	}
	return pair, nil
}

// GetUser — JWT'den alınan userID ile kullanıcıyı döndürür.
func (s *AuthService) GetUser(ctx context.Context, userID string) (*models.User, error) {
	return s.userRepo.FindByID(ctx, userID)
}

// UpdateProfile — kullanıcının kendi profilini günceller.
func (s *AuthService) UpdateProfile(ctx context.Context, userID string, name, surname, phone *string) (*models.User, error) {
	if err := s.userRepo.Update(ctx, userID, name, surname, phone, nil, nil, nil, nil); err != nil {
		return nil, err
	}
	return s.userRepo.FindByID(ctx, userID)
}

// ErrLastAdmin — sistemdeki son admin kendi hesabını silmeye çalıştı.
var ErrLastAdmin = errors.New("sistemdeki son admin hesabı silinemez")

// DeleteAccount — kullanıcının kendi hesabını siler (anonimleştirir).
//
// Kişisel veri temizlenir; mekanlar, doğrulamalar ve yorumlar anonim olarak kalır
// (topluluk verisi — ayrılan bir rehber yüzünden kaybolmamalı). Geri alınamaz.
//
// Son admin engellenir: aksi halde sistem yönetimsiz kalır ve admin paneline
// hiç kimse giremez.
func (s *AuthService) DeleteAccount(ctx context.Context, userID string) error {
	user, err := s.userRepo.FindByID(ctx, userID)
	if err != nil {
		return err
	}

	if user.Role == models.RoleAdmin {
		count, err := s.userRepo.CountActiveAdmins(ctx)
		if err != nil {
			return err
		}
		if count <= 1 {
			return ErrLastAdmin
		}
	}

	return s.userRepo.AnonymizeUser(ctx, userID)
}

// RequestPasswordReset — şifre sıfırlama kodu üretip e-posta ile gönderir.
//
// Enumeration koruması: hangi durumda olursa olsun nil döner. Çağıran handler
// her zaman aynı mesajı basar. Kullanıcının var olup olmadığı, Google hesabı
// olup olmadığı ya da limitin dolduğu istemciye sızmaz.
//
// bcrypt.GenerateFromPassword ~50ms süren CPU-ağır bir işlemdir. SMTP round-trip
// gibi ağ jitter'ına tabi değildir — senkron çalıştırılırsa pozitif/negatif yol
// arasında SMTP'den bile daha kararlı ve ölçülebilir bir zamanlama farkı
// (kullanıcı var: ~50ms, kullanıcı yok: ~20ns) oluşur ve enumeration korumasını
// zamanlama kanalından deler. Bu yüzden kod üretimi + hash'leme + Invalidate +
// Create dahil TÜM ağır iş goroutine'e taşınır; fonksiyon FindByEmail ve ucuz
// CountRecentByUserID (basit COUNT sorgusu, ölçülebilir bir zamanlama sinyali
// oluşturmaz) sonrasında hemen döner.
func (s *AuthService) RequestPasswordReset(ctx context.Context, email string) error {
	email = strings.ToLower(strings.TrimSpace(email))

	user, err := s.userRepo.FindByEmail(ctx, email)
	if err != nil {
		return nil // kullanıcı yok (ya da DB hatası) — sessizce yut
	}
	if !user.IsActive || user.PasswordHash == nil {
		return nil // pasif hesap ya da Google hesabı (şifresiz)
	}

	count, err := s.resetRepo.CountRecentByUserID(ctx, user.ID, s.now().Add(-time.Hour))
	if err != nil || count >= 3 {
		return nil // saatte en fazla 3 talep
	}

	// Kod üretimi, bcrypt hash'leme, eski kodların geçersizleştirilmesi, yeni
	// kaydın oluşturulması ve mail gönderimi ARKA PLANDA yapılır. Fonksiyon
	// burada döner; çağıran için pozitif/negatif yol artık zamanlama açısından
	// ayırt edilemez.
	go s.createResetAndSendEmail(user.ID, user.Email, user.Name)

	// Fırsatçı temizlik — eski satırlar sonsuza dek birikmesin.
	go s.cleanupExpiredResets()

	return nil
}

// createResetAndSendEmail — kod üretimi, hash'leme, eski tokenların
// geçersizleştirilmesi, yeni kaydın oluşturulması ve mail gönderimini arka
// planda yürütür. Kendi context'ini kurar (request context'i request dönünce
// iptal olur, ama bu iş request'ten bağımsız sürmeli).
func (s *AuthService) createResetAndSendEmail(userID, toEmail, name string) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	code, err := generateResetCode()
	if err != nil {
		log.Printf("şifre sıfırlama kodu üretilemedi (user=%s): %v", userID, err)
		return
	}
	codeHash, err := bcrypt.GenerateFromPassword([]byte(code), bcrypt.DefaultCost)
	if err != nil {
		log.Printf("şifre sıfırlama kodu hash'lenemedi (user=%s): %v", userID, err)
		return
	}

	// Yeni kod üretildiğinde eski kodlar geçersizleşir.
	if err := s.resetRepo.InvalidateActiveByUserID(ctx, userID); err != nil {
		log.Printf("eski şifre sıfırlama tokenları geçersizleştirilemedi (user=%s): %v", userID, err)
		return
	}
	if err := s.resetRepo.Create(ctx, userID, string(codeHash), s.now().Add(15*time.Minute)); err != nil {
		log.Printf("şifre sıfırlama tokenı oluşturulamadı (user=%s): %v", userID, err)
		return
	}

	s.sendResetEmail(toEmail, name, code)
}

func (s *AuthService) sendResetEmail(to, name, code string) {
	if err := s.email.Send(to, "Şifre sıfırlama kodunuz", passwordResetEmailHTML(name, code)); err != nil {
		log.Printf("şifre sıfırlama maili gönderilemedi: %v", err)
	}
}

func (s *AuthService) cleanupExpiredResets() {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := s.resetRepo.DeleteExpiredBefore(ctx, s.now().Add(-24*time.Hour)); err != nil {
		log.Printf("şifre sıfırlama temizliği başarısız: %v", err)
	}
}

// ErrResetInvalid — kod doğrulamasının TÜM kırılma sebepleri için tek mesaj.
// Sebepleri ayırmak ("süresi dolmuş" vs "yanlış kod") saldırgana kodu
// doğruladığını söyler.
//
// Bu üçü export edilir çünkü handler, kullanıcıya gösterilebilir hatalarla
// beklenmeyen iç hataları (DB/bcrypt) errors.Is ile ayırt eder; iç hata
// metinleri istemciye sızmamalıdır.
var (
	ErrResetInvalid     = errors.New("kod geçersiz veya süresi dolmuş")
	ErrPasswordTooShort = errors.New("şifre en az 6 karakter olmalıdır")
	ErrPasswordTooLong  = errors.New("şifre en fazla 72 karakter olabilir")
)

// ResetPassword — sıfırlama kodunu doğrulayıp yeni şifreyi yazar.
func (s *AuthService) ResetPassword(ctx context.Context, email, code, newPassword string) error {
	email = strings.ToLower(strings.TrimSpace(email))

	if len(newPassword) < 6 {
		return ErrPasswordTooShort
	}
	// bcrypt 72 byte'tan sonrasını sessizce kırpar.
	if len(newPassword) > 72 {
		return ErrPasswordTooLong
	}

	user, err := s.userRepo.FindByEmail(ctx, email)
	if err != nil {
		return ErrResetInvalid
	}
	if !user.IsActive || user.PasswordHash == nil {
		return ErrResetInvalid
	}

	// ClaimAttempt ATOMİK: deneme sayacını artırır ve token hâlâ geçerliyse
	// hash'i döner. Sayaç artışı kod yanlış olsa da kalıcıdır, aksi hâlde
	// saldırgan limitsiz deneyebilirdi.
	tokenID, codeHash, err := s.resetRepo.ClaimAttempt(ctx, user.ID)
	if err != nil {
		return ErrResetInvalid
	}

	// bcrypt.CompareHashAndPassword sabit zamanlıdır.
	if err := bcrypt.CompareHashAndPassword([]byte(codeHash), []byte(code)); err != nil {
		return ErrResetInvalid
	}

	newHash, err := bcrypt.GenerateFromPassword([]byte(newPassword), bcrypt.DefaultCost)
	if err != nil {
		return err
	}

	// Tokenı tüket: MarkUsed yalnızca henüz kullanılmamışsa yazar, böylece
	// aynı kodla iki paralel istek şifreyi iki kez değiştiremez.
	if err := s.resetRepo.MarkUsed(ctx, tokenID); err != nil {
		return ErrResetInvalid
	}
	if err := s.userRepo.UpdatePassword(ctx, user.ID, string(newHash)); err != nil {
		return err
	}
	// Şifre değişti: kullanıcının diğer açık kodları da geçersizleşsin.
	if err := s.resetRepo.InvalidateActiveByUserID(ctx, user.ID); err != nil {
		log.Printf("şifre sonrası token temizliği başarısız: %v", err)
	}
	return nil
}
