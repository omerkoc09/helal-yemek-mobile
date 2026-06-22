package repository

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/omerkoc/caiz-mi/internal/models"
)

var ErrNotFound = errors.New("kayıt bulunamadı")
var ErrAlreadyExists = errors.New("kayıt zaten mevcut")

type UserRepo struct {
	db *pgxpool.Pool
}

func NewUserRepo(db *pgxpool.Pool) *UserRepo {
	return &UserRepo{db: db}
}

func (r *UserRepo) Create(ctx context.Context, u *models.User) error {
	query := `
		INSERT INTO users (email, password_hash, name, surname, phone, role, provider, provider_id, avatar_url)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
		RETURNING id, created_at, updated_at`
	return r.db.QueryRow(ctx, query,
		u.Email, u.PasswordHash, u.Name, u.Surname, u.Phone, u.Role, u.Provider, u.ProviderID, u.AvatarURL,
	).Scan(&u.ID, &u.CreatedAt, &u.UpdatedAt)
}

func (r *UserRepo) FindByEmail(ctx context.Context, email string) (*models.User, error) {
	u := &models.User{}
	query := `
		SELECT id, email, password_hash, name, surname, phone, avatar_url, role, provider, provider_id, is_active, created_at, updated_at
		FROM users WHERE email = $1`
	err := r.db.QueryRow(ctx, query, email).Scan(
		&u.ID, &u.Email, &u.PasswordHash, &u.Name, &u.Surname, &u.Phone, &u.AvatarURL,
		&u.Role, &u.Provider, &u.ProviderID, &u.IsActive, &u.CreatedAt, &u.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	return u, err
}

func (r *UserRepo) FindByProviderID(ctx context.Context, provider, providerID string) (*models.User, error) {
	u := &models.User{}
	query := `
		SELECT id, email, password_hash, name, surname, phone, avatar_url, role, provider, provider_id, is_active, created_at, updated_at
		FROM users WHERE provider = $1 AND provider_id = $2`
	err := r.db.QueryRow(ctx, query, provider, providerID).Scan(
		&u.ID, &u.Email, &u.PasswordHash, &u.Name, &u.Surname, &u.Phone, &u.AvatarURL,
		&u.Role, &u.Provider, &u.ProviderID, &u.IsActive, &u.CreatedAt, &u.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	return u, err
}

func (r *UserRepo) FindByID(ctx context.Context, id string) (*models.User, error) {
	u := &models.User{}
	query := `
		SELECT id, email, password_hash, name, surname, phone, avatar_url, role, provider, provider_id, is_active, created_at, updated_at
		FROM users WHERE id = $1`
	err := r.db.QueryRow(ctx, query, id).Scan(
		&u.ID, &u.Email, &u.PasswordHash, &u.Name, &u.Surname, &u.Phone, &u.AvatarURL,
		&u.Role, &u.Provider, &u.ProviderID, &u.IsActive, &u.CreatedAt, &u.UpdatedAt,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	return u, err
}

func (r *UserRepo) EmailExists(ctx context.Context, email string) (bool, error) {
	var exists bool
	err := r.db.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM users WHERE email = $1)`, email).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("email kontrol hatası: %w", err)
	}
	return exists, nil
}

// UpdateRole — kullanıcının rolünü günceller.
func (r *UserRepo) UpdateRole(ctx context.Context, id string, role models.Role) error {
	result, err := r.db.Exec(ctx,
		`UPDATE users SET role = $1, updated_at = NOW() WHERE id = $2`,
		role, id,
	)
	if err != nil {
		return fmt.Errorf("rol güncellemesi başarısız: %w", err)
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// Update — kullanıcının temel bilgilerini günceller. nil olan alanlar değiştirilmez.
func (r *UserRepo) Update(ctx context.Context, id string, name, surname, phone, email *string, role *models.Role, isActive *bool) error {
	var roleStr *string
	if role != nil {
		s := string(*role)
		roleStr = &s
	}

	query := `
		UPDATE users SET
			name      = COALESCE($2, name),
			surname   = COALESCE($3, surname),
			phone     = COALESCE($4, phone),
			email     = COALESCE($5, email),
			role      = COALESCE($6, role),
			is_active = COALESCE($7, is_active),
			updated_at = NOW()
		WHERE id = $1`
	result, err := r.db.Exec(ctx, query, id, name, surname, phone, email, roleStr, isActive)
	if err != nil {
		return fmt.Errorf("kullanıcı güncellemesi başarısız: %w", err)
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// Delete — kullanıcıyı veritabanından siler.
func (r *UserRepo) Delete(ctx context.Context, id string) error {
	result, err := r.db.Exec(ctx, `DELETE FROM users WHERE id = $1`, id)
	if err != nil {
		return fmt.Errorf("kullanıcı silme başarısız: %w", err)
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// List — tüm kullanıcıları döndürür (admin kullanımı).
func (r *UserRepo) List(ctx context.Context) ([]models.User, error) {
	rows, err := r.db.Query(ctx,
		`SELECT u.id, u.email, u.name, u.surname, u.phone, u.avatar_url, u.role,
		        u.provider, u.is_active, u.created_at, u.updated_at
		 FROM users u
		 ORDER BY u.created_at DESC`,
	)
	if err != nil {
		return nil, fmt.Errorf("kullanıcı listesi sorgusu başarısız: %w", err)
	}
	defer rows.Close()

	var list []models.User
	for rows.Next() {
		u := models.User{}
		if err := rows.Scan(
			&u.ID, &u.Email, &u.Name, &u.Surname, &u.Phone, &u.AvatarURL,
			&u.Role, &u.Provider, &u.IsActive, &u.CreatedAt, &u.UpdatedAt,
		); err != nil {
			return nil, err
		}
		list = append(list, u)
	}
	if list == nil {
		list = []models.User{}
	}
	return list, rows.Err()
}

// CityGuideCount — şehir bazlı rehber sayımı (admin paneli).
type CityGuideCount struct {
	City  string `json:"city"`
	Count int    `json:"count"`
}

// SetGuideCity — rehberin aktif çalışma şehrini ayarlar (onayda çağrılır).
func (r *UserRepo) SetGuideCity(ctx context.Context, userID, city string) error {
	result, err := r.db.Exec(ctx,
		`UPDATE users SET guide_city = $1, updated_at = NOW() WHERE id = $2`,
		city, userID,
	)
	if err != nil {
		return err
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

// ClearGuideCity — guide_city'yi NULL yapar (demote'ta çağrılır; idempotent).
func (r *UserRepo) ClearGuideCity(ctx context.Context, userID string) error {
	_, err := r.db.Exec(ctx,
		`UPDATE users SET guide_city = NULL, updated_at = NOW() WHERE id = $1`,
		userID,
	)
	return err
}

// GetGuideCity — kullanıcının guide_city'sini döner (NULL ise nil). Kullanıcı yoksa ErrNotFound.
func (r *UserRepo) GetGuideCity(ctx context.Context, userID string) (*string, error) {
	var city *string
	err := r.db.QueryRow(ctx,
		`SELECT guide_city FROM users WHERE id = $1`,
		userID,
	).Scan(&city)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	return city, err
}

// CountGuidesByCity — şehir bazlı aktif rehber sayısını azalan döndürür.
func (r *UserRepo) CountGuidesByCity(ctx context.Context) ([]CityGuideCount, error) {
	rows, err := r.db.Query(ctx,
		`SELECT guide_city, COUNT(*) AS cnt
		 FROM users
		 WHERE role = 'guide' AND guide_city IS NOT NULL
		 GROUP BY guide_city
		 ORDER BY cnt DESC, guide_city`,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []CityGuideCount
	for rows.Next() {
		var c CityGuideCount
		if err := rows.Scan(&c.City, &c.Count); err != nil {
			return nil, err
		}
		list = append(list, c)
	}
	if list == nil {
		list = []CityGuideCount{}
	}
	return list, rows.Err()
}
