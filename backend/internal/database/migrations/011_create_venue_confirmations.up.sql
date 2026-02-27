CREATE TABLE venue_confirmations (
    venue_id UUID NOT NULL REFERENCES venues(id) ON DELETE CASCADE,
    guide_id UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (venue_id, guide_id)
);
