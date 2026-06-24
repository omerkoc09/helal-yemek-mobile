package repository

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

type DayCount struct {
	Date  string `json:"date"`
	Count int    `json:"count"`
}

type LoginRepo struct {
	db *pgxpool.Pool
}

func NewLoginRepo(db *pgxpool.Pool) *LoginRepo {
	return &LoginRepo{db: db}
}

// Record — başarılı girişi kaydeder.
func (r *LoginRepo) Record(ctx context.Context, userID string) error {
	_, err := r.db.Exec(ctx,
		`INSERT INTO user_logins (user_id) VALUES ($1) ON CONFLICT DO NOTHING`,
		userID,
	)
	return err
}

// CountByDay — [from, to) aralığında gün bazlı giriş sayılarını döner.
func (r *LoginRepo) CountByDay(ctx context.Context, from, to time.Time) ([]DayCount, error) {
	rows, err := r.db.Query(ctx,
		`SELECT DATE(created_at AT TIME ZONE 'UTC') AS day, COUNT(*)::int
		 FROM user_logins
		 WHERE created_at >= $1 AND created_at < $2
		 GROUP BY day
		 ORDER BY day`,
		from, to,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []DayCount
	for rows.Next() {
		var dc DayCount
		var day time.Time
		if err := rows.Scan(&day, &dc.Count); err != nil {
			return nil, err
		}
		dc.Date = day.Format("2006-01-02")
		list = append(list, dc)
	}
	if list == nil {
		list = []DayCount{}
	}
	return list, rows.Err()
}
