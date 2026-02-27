package handlers

import (
	"context"

	"github.com/gofiber/fiber/v2"
	"github.com/omerkoc/caiz-mi/internal/models"
	jwtpkg "github.com/omerkoc/caiz-mi/pkg/jwt"
)

// AuthServiceInterface — AuthService'in handler'ın ihtiyaç duyduğu metotları.
type AuthServiceInterface interface {
	Register(ctx context.Context, email, password, name string) (*jwtpkg.TokenPair, error)
	Login(ctx context.Context, email, password string) (*jwtpkg.TokenPair, error)
	LoginWithGoogle(ctx context.Context, idToken string) (*jwtpkg.TokenPair, error)
	LoginWithApple(ctx context.Context, identityToken, name string) (*jwtpkg.TokenPair, error)
	RefreshTokens(ctx context.Context, refreshToken string) (*jwtpkg.TokenPair, error)
	GetUser(ctx context.Context, userID string) (*models.User, error)
	UpdateProfile(ctx context.Context, userID string, name *string) (*models.User, error)
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
	}
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "geçersiz istek"})
	}
	if req.Email == "" || req.Password == "" || req.Name == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "email, şifre ve ad zorunludur"})
	}

	tokens, err := h.authService.Register(c.Context(), req.Email, req.Password, req.Name)
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

// AppleLogin godoc
// POST /api/v1/auth/apple
func (h *AuthHandler) AppleLogin(c *fiber.Ctx) error {
	var req struct {
		IdentityToken string `json:"identity_token"`
		Name          string `json:"name"` // Sadece ilk girişte Apple gönderir
	}
	if err := c.BodyParser(&req); err != nil || req.IdentityToken == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "identity_token zorunludur"})
	}

	tokens, err := h.authService.LoginWithApple(c.Context(), req.IdentityToken, req.Name)
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
	userID := c.Locals("userID").(string)
	user, err := h.authService.GetUser(c.Context(), userID)
	if err != nil {
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "kullanıcı bulunamadı"})
	}
	return c.JSON(user)
}

// UpdateProfile godoc
// PUT /api/v1/auth/profile
func (h *AuthHandler) UpdateProfile(c *fiber.Ctx) error {
	userID := c.Locals("userID").(string)

	var req struct {
		Name string `json:"name"`
	}
	if err := c.BodyParser(&req); err != nil {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "geçersiz istek"})
	}
	if req.Name == "" {
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "ad zorunludur"})
	}

	user, err := h.authService.UpdateProfile(c.Context(), userID, &req.Name)
	if err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "profil güncellenemedi"})
	}
	return c.JSON(user)
}
