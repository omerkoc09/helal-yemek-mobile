package repository

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/omerkoc/itimat-mobile/internal/models"
)

type VenueReportRepo struct {
	db *pgxpool.Pool
}

func NewVenueReportRepo(db *pgxpool.Pool) *VenueReportRepo {
	return &VenueReportRepo{db: db}
}

func (r *VenueReportRepo) Create(ctx context.Context, rp *models.VenueReport) error {
	return r.db.QueryRow(ctx,
		`INSERT INTO venue_reports (venue_id, user_id, reason, description)
		 VALUES ($1, $2, $3, $4)
		 RETURNING id, created_at`,
		rp.VenueID, rp.UserID, rp.Reason, rp.Description,
	).Scan(&rp.ID, &rp.CreatedAt)
}

func (r *VenueReportRepo) List(ctx context.Context) ([]models.VenueReport, error) {
	rows, err := r.db.Query(ctx,
		`SELECT
			vr.id, vr.venue_id, v.name, v.city,
			u1.name, u1.email, v.created_at,
			vr.user_id, u2.name, u2.surname, u2.email, u2.phone, u2.role,
			vr.reason, vr.description, vr.status, vr.created_at
		 FROM venue_reports vr
		 JOIN venues v  ON v.id  = vr.venue_id
		 LEFT JOIN users u1 ON u1.id = v.added_by
		 JOIN users u2  ON u2.id = vr.user_id
		 ORDER BY vr.created_at DESC`,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []models.VenueReport
	for rows.Next() {
		var rp models.VenueReport
		if err := rows.Scan(
			&rp.ID, &rp.VenueID, &rp.VenueName, &rp.VenueCity,
			&rp.AddedByName, &rp.AddedByEmail, &rp.VenueAddedAt,
			&rp.UserID, &rp.ReporterName, &rp.ReporterSurname, &rp.ReporterEmail, &rp.ReporterPhone, &rp.ReporterRole,
			&rp.Reason, &rp.Description, &rp.Status, &rp.CreatedAt,
		); err != nil {
			return nil, err
		}
		list = append(list, rp)
	}
	if list == nil {
		list = []models.VenueReport{}
	}
	return list, rows.Err()
}

func (r *VenueReportRepo) Resolve(ctx context.Context, id string) error {
	result, err := r.db.Exec(ctx,
		`UPDATE venue_reports SET status = 'resolved' WHERE id = $1 AND status != 'resolved'`,
		id,
	)
	if err != nil {
		return err
	}
	if result.RowsAffected() == 0 {
		return ErrNotFound
	}
	return nil
}
