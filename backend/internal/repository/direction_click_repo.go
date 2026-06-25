package repository

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

type VenueClickCount struct {
	VenueID string `json:"venue_id"`
	Name    string `json:"name"`
	City    string `json:"city"`
	Count   int    `json:"count"`
}

type DirectionClickRepo struct {
	db *pgxpool.Pool
}

func NewDirectionClickRepo(db *pgxpool.Pool) *DirectionClickRepo {
	return &DirectionClickRepo{db: db}
}

// Create — bir yol tarifi tıklamasını kaydeder. userID nil ise anonim.
func (r *DirectionClickRepo) Create(ctx context.Context, venueID string, userID *string) error {
	_, err := r.db.Exec(ctx,
		`INSERT INTO venue_direction_clicks (venue_id, user_id) VALUES ($1, $2)`,
		venueID, userID,
	)
	return err
}

// CountByDay — [from, to) aralığında gün bazlı tıklama sayılarını döner.
func (r *DirectionClickRepo) CountByDay(ctx context.Context, from, to time.Time) ([]DayCount, error) {
	rows, err := r.db.Query(ctx,
		`SELECT DATE(created_at AT TIME ZONE 'UTC') AS day, COUNT(*)::int
		 FROM venue_direction_clicks
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

// TopVenues — [from, to) aralığında en çok yol tarifi alınan mekanları döner.
func (r *DirectionClickRepo) TopVenues(ctx context.Context, from, to time.Time, limit int) ([]VenueClickCount, error) {
	rows, err := r.db.Query(ctx,
		`SELECT v.id::text, v.name, v.city, COUNT(*)::int AS cnt
		 FROM venue_direction_clicks dc
		 JOIN venues v ON v.id = dc.venue_id
		 WHERE dc.created_at >= $1 AND dc.created_at < $2
		   AND v.deleted_at IS NULL
		 GROUP BY v.id, v.name, v.city
		 ORDER BY cnt DESC, v.name ASC
		 LIMIT $3`,
		from, to, limit,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []VenueClickCount
	for rows.Next() {
		var vc VenueClickCount
		if err := rows.Scan(&vc.VenueID, &vc.Name, &vc.City, &vc.Count); err != nil {
			return nil, err
		}
		list = append(list, vc)
	}
	if list == nil {
		list = []VenueClickCount{}
	}
	return list, rows.Err()
}
