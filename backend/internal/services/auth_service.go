package services

import (
	"context"
	"errors"
	"log"
	"strings"
	"time"

	"golang.org/x/crypto/bcrypt"
	"google.golang.org/api/idtoken"

	"github.com/omerkoc/caiz-mi/internal/models"
	"github.com/omerkoc/caiz-mi/internal/repository"
	jwtpkg "github.com/omerkoc/caiz-mi/pkg/jwt"
)

type AuthService struct {
	userRepo       *repository.UserRepo
	loginRepo      *repository.LoginRepo
	jwtSecret      string
	googleClientID string
	appleService   *AppleService
}

func NewAuthService(userRepo *repository.UserRepo, loginRepo *repository.LoginRepo, jwtSecret, googleClientID string) *AuthService {
	return &AuthService{
		userRepo:       userRepo,
		loginRepo:      loginRepo,
		jwtSecret:      jwtSecret,
		googleClientID: googleClientID,
		appleService:   NewAppleService(),
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
	payload, err := idtoken.Validate(ctx, idToken, s.googleClientID)
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
			// Hiç hesap yok, yeni oluştur
			user = &models.User{
				Email:      email,
				Name:       name,
				AvatarURL:  &picture,
				Role:       models.RoleTraveler,
				Provider:   "google",
				ProviderID: &providerID,
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

// LoginWithApple — Apple identity token'ını doğrular, kullanıcı yoksa oluşturur.
func (s *AuthService) LoginWithApple(ctx context.Context, identityToken, name string) (*jwtpkg.TokenPair, error) {
	claims, err := s.appleService.ValidateToken(ctx, identityToken)
	if err != nil {
		return nil, errors.New("geçersiz Apple token")
	}

	providerID := claims.Subject
	email := strings.ToLower(claims.Email)

	// Apple ilk girişte adı gönderir, sonraki girişlerde göndermez
	if name == "" {
		name = "Apple Kullanıcısı"
	}

	user, err := s.userRepo.FindByProviderID(ctx, "apple", providerID)
	if errors.Is(err, repository.ErrNotFound) {
		user = &models.User{
			Email:      email,
			Name:       name,
			Role:       models.RoleTraveler,
			Provider:   "apple",
			ProviderID: &providerID,
		}
		if err := s.userRepo.Create(ctx, user); err != nil {
			return nil, err
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
	go s.recordLogin(user.ID)
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
	if err := s.userRepo.Update(ctx, userID, name, surname, phone, nil, nil, nil); err != nil {
		return nil, err
	}
	return s.userRepo.FindByID(ctx, userID)
}
