CREATE TABLE venue_reports (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    venue_id    UUID NOT NULL REFERENCES venues(id) ON DELETE CASCADE,
    user_id     UUID NOT NULL REFERENCES users(id),
    reason      TEXT NOT NULL,
    description TEXT,
    status      TEXT NOT NULL DEFAULT 'pending',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_venue_reports_venue_id ON venue_reports(venue_id);
CREATE INDEX idx_venue_reports_status ON venue_reports(status);
