CREATE TABLE venue_verification_logs (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    venue_id   UUID NOT NULL REFERENCES venues(id) ON DELETE CASCADE,
    guide_id   UUID NOT NULL REFERENCES users(id),
    action     TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_vvl_venue_id   ON venue_verification_logs(venue_id);
CREATE INDEX idx_vvl_guide_id   ON venue_verification_logs(guide_id);
CREATE INDEX idx_vvl_created_at ON venue_verification_logs(created_at DESC);
