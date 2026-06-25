CREATE TABLE venue_direction_clicks (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  venue_id   UUID        NOT NULL REFERENCES venues(id) ON DELETE CASCADE,
  user_id    UUID        REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX venue_direction_clicks_venue_idx   ON venue_direction_clicks (venue_id);
CREATE INDEX venue_direction_clicks_created_idx ON venue_direction_clicks (created_at);
