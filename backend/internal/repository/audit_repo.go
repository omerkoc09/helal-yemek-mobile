package repository

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/omerkoc/itimat-mobile/internal/models"
)

type AuditRepo struct {
	db *pgxpool.Pool
}

func NewAuditRepo(db *pgxpool.Pool) *AuditRepo {
	return &AuditRepo{db: db}
}

// Create — yeni audit log kaydı ekler.
func (r *AuditRepo) Create(ctx context.Context, l *models.AuditLog) error {
	return r.db.QueryRow(ctx,
		`INSERT INTO audit_logs (admin_id, action, target_type, target_id, note)
		 VALUES ($1, $2, $3, $4, $5)
		 RETURNING id, created_at`,
		l.AdminID, l.Action, l.TargetType, l.TargetID, l.Note,
	).Scan(&l.ID, &l.CreatedAt)
}

// List — tüm audit logları yeniden eskiye sıralar.
func (r *AuditRepo) List(ctx context.Context) ([]models.AuditLog, error) {
	rows, err := r.db.Query(ctx,
		`SELECT id, admin_id, action, target_type, target_id, note, created_at
		 FROM audit_logs
		 ORDER BY created_at DESC
		 LIMIT 500`,
	)
	if err != nil {
		return nil, fmt.Errorf("audit log sorgusu başarısız: %w", err)
	}
	defer rows.Close()

	var list []models.AuditLog
	for rows.Next() {
		l := models.AuditLog{}
		if err := rows.Scan(&l.ID, &l.AdminID, &l.Action, &l.TargetType, &l.TargetID, &l.Note, &l.CreatedAt); err != nil {
			return nil, err
		}
		list = append(list, l)
	}
	if list == nil {
		list = []models.AuditLog{}
	}
	return list, rows.Err()
}
