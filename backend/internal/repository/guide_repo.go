package repository

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/omerkoc/caiz-mi/internal/models"
)

type GuideRepo struct {
	db *pgxpool.Pool
}

func NewGuideRepo(db *pgxpool.Pool) *GuideRepo {
	return &GuideRepo{db: db}
}

// HasPendingApplication — kullanıcının bekleyen başvurusu var mı kontrol eder.
func (r *GuideRepo) HasPendingApplication(ctx context.Context, userID string) (bool, error) {
	var exists bool
	err := r.db.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM guide_applications WHERE user_id = $1 AND status = 'pending')`,
		userID,
	).Scan(&exists)
	return exists, err
}

func (r *GuideRepo) Create(ctx context.Context, app *models.GuideApplication) error {
	return r.db.QueryRow(ctx,
		`INSERT INTO guide_applications (user_id, referred_by) VALUES ($1, $2) RETURNING id, created_at`,
		app.UserID, app.ReferredBy,
	).Scan(&app.ID, &app.CreatedAt)
}

func (r *GuideRepo) ListPending(ctx context.Context) ([]models.GuideApplication, error) {
	rows, err := r.db.Query(ctx,
		`SELECT ga.id, ga.user_id, ga.status, ga.note, ga.reviewed_by, ga.reviewed_at,
		        ga.referred_by, r.name AS referrer_name, u.name AS user_name, u.email AS user_email,
		        ga.created_at
		 FROM guide_applications ga
		 JOIN users u ON u.id = ga.user_id
		 LEFT JOIN users r ON r.id = ga.referred_by
		 WHERE ga.status = 'pending'
		 ORDER BY ga.created_at`,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []models.GuideApplication
	for rows.Next() {
		app := models.GuideApplication{}
		if err := rows.Scan(
			&app.ID, &app.UserID, &app.Status, &app.Note, &app.ReviewedBy, &app.ReviewedAt,
			&app.ReferredBy, &app.ReferrerName, &app.UserName, &app.UserEmail,
			&app.CreatedAt,
		); err != nil {
			return nil, err
		}
		list = append(list, app)
	}
	if list == nil {
		list = []models.GuideApplication{}
	}
	return list, rows.Err()
}

func (r *GuideRepo) FindByID(ctx context.Context, id string) (*models.GuideApplication, error) {
	app := &models.GuideApplication{}
	err := r.db.QueryRow(ctx,
		`SELECT id, user_id, status, note, reviewed_by, reviewed_at, referred_by, created_at
		 FROM guide_applications WHERE id = $1`,
		id,
	).Scan(&app.ID, &app.UserID, &app.Status, &app.Note, &app.ReviewedBy, &app.ReviewedAt, &app.ReferredBy, &app.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	return app, err
}

// UpdateStatus — başvurunun durumunu günceller (admin işlemi).
func (r *GuideRepo) UpdateStatus(ctx context.Context, id, adminID string, status models.ApplicationStatus, note *string) error {
	result, err := r.db.Exec(ctx,
		`UPDATE guide_applications
		 SET status = $1, reviewed_by = $2, reviewed_at = NOW(), note = $3
		 WHERE id = $4 AND status = 'pending'`,
		status, adminID, note, id,
	)
	if err != nil {
		return err
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func scanApplicationRows(rows pgx.Rows) ([]models.GuideApplication, error) {
	var list []models.GuideApplication
	for rows.Next() {
		app := models.GuideApplication{}
		if err := rows.Scan(
			&app.ID, &app.UserID, &app.Status, &app.Note, &app.ReviewedBy, &app.ReviewedAt, &app.ReferredBy, &app.CreatedAt,
		); err != nil {
			return nil, err
		}
		list = append(list, app)
	}
	if list == nil {
		list = []models.GuideApplication{}
	}
	return list, rows.Err()
}
