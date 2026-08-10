package handlers

import (
	"context"
	"errors"
	"log"

	"github.com/gofiber/fiber/v2"
	"github.com/omerkoc/itimat-mobile/internal/models"
	"github.com/omerkoc/itimat-mobile/internal/repository"
	"github.com/omerkoc/itimat-mobile/internal/services"
	jwtpkg "github.com/omerkoc/itimat-mobile/pkg/jwt"
)

// AuthServiceInterface — AuthService'in handler'ın ihtiyaç duyduğu metotları.
type AuthServiceInterface interface {
	Register(ctx context.Context, email, password, name, surname, phone string) (*jwtpkg.TokenPair, error)
	Login(ctx context.Context, email, password string) (*jwtpkg.TokenPair, error)
	LoginWithGoogle(ctx context.Context, idToken string) (*jwtpkg.TokenPair, error)
	RefreshTokens(ctx context.Context, refreshToken string) (*jwtpkg.TokenPair, error)
	GetUser(ctx context.Context, userID string) (*models.User, error)
	UpdateProfile(ctx context.Context, userID string, name, surname, phone *string) (*models.User, error)
	RequestPasswordReset(ctx context.Context, email string) error
	ResetPassword(ctx context.Context, email, code, newPassword string) error
	DeleteAccount(ctx context.Context, userID string) error
}

type AuthHandler struct {
	authService AuthServiceInterface
}

func NewAuthHandler(authService AuthServiceInterface) *AuthHandler {
	return &AuthHandler{authService: authService}
}

// Register godoc
// POST /api/v1/auth/register
func (h *AuthHandler) Register(c *fiber.Ctx) error {
	var req struct {
		Email    string `json:"email"`
		Password string `json:"password"`
		Name     string `json:"name"`
		Surname  string `json:"surname"`
		Phone    string `json:"phone"`
	}
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "geçersiz istek"})
	}
	if req.Email == "" || req.Password == "" || req.Name == "" || req.Surname == "" || req.Phone == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "email, şifre, ad, soyad ve telefon zorunludur"})
	}

	tokens, err := h.authService.Register(c.Context(), req.Email, req.Password, req.Name, req.Surname, req.Phone)
	if err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": err.Error()})
	}
	return c.Status(fiber.StatusCreated).JSON(tokens)
}

// Login godoc
// POST /api/v1/auth/login
func (h *AuthHandler) Login(c *fiber.Ctx) error {
	var req struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "geçersiz istek"})
	}
	if req.Email == "" || req.Password == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "email ve şifre zorunludur"})
	}

	tokens, err := h.authService.Login(c.Context(), req.Email, req.Password)
	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(tokens)
}

// GoogleLogin godoc
// POST /api/v1/auth/google
func (h *AuthHandler) GoogleLogin(c *fiber.Ctx) error {
	var req struct {
		IDToken string `json:"id_token"`
	}
	if err := c.BodyParser(&req); err != nil || req.IDToken == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "id_token zorunludur"})
	}

	tokens, err := h.authService.LoginWithGoogle(c.Context(), req.IDToken)
	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(tokens)
}

// Refresh godoc
// POST /api/v1/auth/refresh
func (h *AuthHandler) Refresh(c *fiber.Ctx) error {
	var req struct {
		RefreshToken string `json:"refresh_token"`
	}
	if err := c.BodyParser(&req); err != nil || req.RefreshToken == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "refresh_token zorunludur"})
	}

	tokens, err := h.authService.RefreshTokens(c.Context(), req.RefreshToken)
	if err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(tokens)
}

// Me godoc
// GET /api/v1/auth/me
func (h *AuthHandler) Me(c *fiber.Ctx) error {
	userID, err := getUserID(c)
	if err != nil {
		return err
	}
	user, err := h.authService.GetUser(c.Context(), userID)
	if err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "kullanıcı bulunamadı"})
	}
	return c.JSON(user)
}

// DeleteAccount godoc
// DELETE /api/v1/auth/me
//
// Kullanıcının kendi hesabını silmesi. App Store Guideline 5.1.1(v) ve Google Play,
// hesap oluşturmaya izin veren uygulamaların silmeye de izin vermesini zorunlu tutuyor.
//
// Silme anonimleştirmedir: kişisel veri temizlenir, topluluk katkısı (mekan,
// doğrulama, yorum) anonim kalır. Geri alınamaz.
func (h *AuthHandler) DeleteAccount(c *fiber.Ctx) error {
	userID, err := getUserID(c)
	if err != nil {
		return err
	}

	if err := h.authService.DeleteAccount(c.Context(), userID); err != nil {
		if errors.Is(err, services.ErrLastAdmin) {
			return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
				"error": "Sistemdeki son admin hesabı silinemez. Önce başka bir admin atayın.",
			})
		}
		if errors.Is(err, repository.ErrNotFound) {
			return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "kullanıcı bulunamadı"})
		}
		log.Printf("[AUTH] hesap silinemedi (user=%s): %v", userID, err)
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "hesap silinemedi"})
	}

	return c.SendStatus(fiber.StatusNoContent)
}

// UpdateProfile godoc
// PUT /api/v1/auth/profile
func (h *AuthHandler) UpdateProfile(c *fiber.Ctx) error {
	userID, err := getUserID(c)
	if err != nil {
		return err
	}

	var req struct {
		Name    *string `json:"name"`
		Surname *string `json:"surname"`
		Phone   *string `json:"phone"`
	}
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "geçersiz istek"})
	}

	user, err := h.authService.UpdateProfile(c.Context(), userID, req.Name, req.Surname, req.Phone)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "profil güncellenemedi"})
	}
	return c.JSON(user)
}

// ForgotPassword godoc
// POST /api/v1/auth/forgot-password
//
// Enumeration koruması: kullanıcı bulunsun ya da bulunmasın, limit dolsun ya da
// dolmasın HER ZAMAN aynı 200 döner. Servis hatası da yutulur.
func (h *AuthHandler) ForgotPassword(c *fiber.Ctx) error {
	var req struct {
		Email string `json:"email"`
	}
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "geçersiz istek"})
	}
	if req.Email == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "email zorunludur"})
	}

	_ = h.authService.RequestPasswordReset(c.Context(), req.Email)

	return c.JSON(fiber.Map{
		"message": "Eğer bu e-posta kayıtlıysa, sıfırlama kodu gönderildi.",
	})
}

// ResetPassword godoc
// POST /api/v1/auth/reset-password
func (h *AuthHandler) ResetPassword(c *fiber.Ctx) error {
	var req struct {
		Email       string `json:"email"`
		Code        string `json:"code"`
		NewPassword string `json:"new_password"`
	}
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "geçersiz istek"})
	}
	if req.Email == "" || req.Code == "" || req.NewPassword == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{
			"error": "email, kod ve yeni şifre zorunludur",
		})
	}

	if err := h.authService.ResetPassword(c.Context(), req.Email, req.Code, req.NewPassword); err != nil {
		switch {
		case errors.Is(err, services.ErrResetInvalid),
			errors.Is(err, services.ErrPasswordTooShort),
			errors.Is(err, services.ErrPasswordTooLong):
			return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": err.Error()})
		default:
			// Beklenmeyen iç hata (DB, bcrypt) — metni istemciye sızdırma.
			log.Printf("şifre sıfırlama iç hatası: %v", err)
			return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{
				"error": "bir hata oluştu, lütfen tekrar deneyin",
			})
		}
	}
	return c.JSON(fiber.Map{"message": "Şifreniz güncellendi."})
}
