CREATE TABLE favorites (
    user_id    UUID REFERENCES users(id) ON DELETE CASCADE,
    venue_id   UUID REFERENCES venues(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, venue_id)
);
