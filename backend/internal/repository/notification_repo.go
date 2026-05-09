package repository

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/omerkoc/caiz-mi/internal/models"
)

type NotificationRepo struct {
	db *pgxpool.Pool
}

func NewNotificationRepo(db *pgxpool.Pool) *NotificationRepo {
	return &NotificationRepo{db: db}
}

func (r *NotificationRepo) Create(ctx context.Context, n *models.Notification) error {
	return r.db.QueryRow(ctx,
		`INSERT INTO notifications (user_id, type, title, body, data)
		 VALUES ($1, $2, $3, $4, $5)
		 RETURNING id, created_at`,
		n.UserID, n.Type, n.Title, n.Body, n.Data,
	).Scan(&n.ID, &n.CreatedAt)
}

func (r *NotificationRepo) ListByUserID(ctx context.Context, userID string, limit, offset int) ([]*models.Notification, error) {
	rows, err := r.db.Query(ctx,
		`SELECT id, user_id, type, title, body, data, is_read, created_at
		 FROM notifications
		 WHERE user_id = $1
		 ORDER BY created_at DESC
		 LIMIT $2 OFFSET $3`,
		userID, limit, offset,
	)
	if err != nil {
		return nil, fmt.Errorf("bildirimler listelenemedi: %w", err)
	}
	defer rows.Close()

	var result []*models.Notification
	for rows.Next() {
		n := &models.Notification{}
		if err := rows.Scan(&n.ID, &n.UserID, &n.Type, &n.Title, &n.Body, &n.Data, &n.IsRead, &n.CreatedAt); err != nil {
			return nil, err
		}
		result = append(result, n)
	}
	return result, rows.Err()
}

func (r *NotificationRepo) UnreadCount(ctx context.Context, userID string) (int, error) {
	var count int
	err := r.db.QueryRow(ctx,
		`SELECT COUNT(*) FROM notifications WHERE user_id = $1 AND is_read = false`,
		userID,
	).Scan(&count)
	return count, err
}

func (r *NotificationRepo) MarkRead(ctx context.Context, id, userID string) error {
	result, err := r.db.Exec(ctx,
		`UPDATE notifications SET is_read = true WHERE id = $1 AND user_id = $2`,
		id, userID,
	)
	if err != nil {
		return fmt.Errorf("bildirim güncellenemedi: %w", err)
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}

func (r *NotificationRepo) MarkAllRead(ctx context.Context, userID string) error {
	_, err := r.db.Exec(ctx,
		`UPDATE notifications SET is_read = true WHERE user_id = $1 AND is_read = false`,
		userID,
	)
	return err
}
