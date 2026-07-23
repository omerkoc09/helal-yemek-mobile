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
		`INSERT INTO guide_applications (user_id, city, terms_accepted_at)
		 VALUES ($1, $2, $3) RETURNING id, created_at`,
		app.UserID, app.City, app.TermsAcceptedAt,
	).Scan(&app.ID, &app.CreatedAt)
}

func (r *GuideRepo) ListPending(ctx context.Context) ([]models.GuideApplication, error) {
	rows, err := r.db.Query(ctx,
		`SELECT ga.id, ga.user_id, ga.city, ga.status, ga.note, ga.reviewed_by, ga.reviewed_at,
		        u.name AS user_name, u.email AS user_email, ga.created_at
		 FROM guide_applications ga
		 JOIN users u ON u.id = ga.user_id
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
			&app.ID, &app.UserID, &app.City, &app.Status, &app.Note, &app.ReviewedBy, &app.ReviewedAt,
			&app.UserName, &app.UserEmail, &app.CreatedAt,
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
		`SELECT id, user_id, city, status, note, reviewed_by, reviewed_at, created_at
		 FROM guide_applications WHERE id = $1`,
		id,
	).Scan(&app.ID, &app.UserID, &app.City, &app.Status, &app.Note, &app.ReviewedBy, &app.ReviewedAt, &app.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	return app, err
}

// FindLatestByUserID — kullanıcının en güncel guide başvurusunu döner (yoksa ErrNotFound).
func (r *GuideRepo) FindLatestByUserID(ctx context.Context, userID string) (*models.GuideApplication, error) {
	app := &models.GuideApplication{}
	err := r.db.QueryRow(ctx,
		`SELECT id, user_id, city, status, note, reviewed_by, reviewed_at, terms_accepted_at, created_at
		 FROM guide_applications
		 WHERE user_id = $1
		 ORDER BY created_at DESC
		 LIMIT 1`,
		userID,
	).Scan(&app.ID, &app.UserID, &app.City, &app.Status, &app.Note, &app.ReviewedBy, &app.ReviewedAt,
		&app.TermsAcceptedAt, &app.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, ErrNotFound
	}
	return app, err
}

// ApproveApplication — başvuruyu ONAYLAR: statüyü approved yapar, kullanıcıya
// guide rolü verir ve şehrini ayarlar. Üçü TEK TRANSACTION içinde yapılır.
//
// Neden atomik: önceden bu üç yazma ayrı ayrı commit'leniyordu ve şehir
// ayarlama başarısız olsa yalnızca loglanıyordu. Sonuç: kullanıcı guide olur
// ama guide_city boş kalır — şehir kısıtına dayanan tüm akışlar (ConfirmVenue,
// venue Create) bozulurdu. Artık herhangi bir adım başarısız olursa hepsi geri
// sarılır; kullanıcı hiç guide olmamış gibi kalır ve işlem yeniden denenebilir.
//
// Başarıda, rol verilen kullanıcının ID'sini döndürür (bildirim/log için).
func (r *GuideRepo) ApproveApplication(ctx context.Context, appID, adminID string) (userID string, err error) {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return "", err
	}
	defer tx.Rollback(ctx) // commit edilirse no-op; edilmezse geri sarar

	// Başvuruyu yükle (FOR UPDATE: eşzamanlı ikinci onayı engelle).
	var appUserID, appCity string
	err = tx.QueryRow(ctx,
		`SELECT user_id, city FROM guide_applications WHERE id = $1 FOR UPDATE`,
		appID,
	).Scan(&appUserID, &appCity)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", ErrNotFound
	}
	if err != nil {
		return "", err
	}

	// Statü: yalnızca pending'ken onaylanabilir. Satır etkilenmezse başvuru
	// zaten incelenmiş demektir (aynı 409 semantiği korunur).
	res, err := tx.Exec(ctx,
		`UPDATE guide_applications
		 SET status = 'approved', reviewed_by = $1, reviewed_at = NOW()
		 WHERE id = $2 AND status = 'pending'`,
		adminID, appID,
	)
	if err != nil {
		return "", err
	}
	if res.RowsAffected() == 0 {
		return "", ErrAlreadyReviewed
	}

	if _, err = tx.Exec(ctx,
		`UPDATE users SET role = 'guide', guide_city = $1, updated_at = NOW() WHERE id = $2`,
		appCity, appUserID,
	); err != nil {
		return "", err
	}

	if err = tx.Commit(ctx); err != nil {
		return "", err
	}
	return appUserID, nil
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
