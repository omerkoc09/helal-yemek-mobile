CREATE TABLE correction_suggestions (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    venue_id     UUID NOT NULL REFERENCES venues(id),
    suggested_by UUID NOT NULL REFERENCES users(id),
    field_name   VARCHAR(100) NOT NULL,
    old_value    TEXT,
    new_value    TEXT NOT NULL,
    status       VARCHAR(20) NOT NULL DEFAULT 'pending',
    reviewed_by  UUID REFERENCES users(id),
    reviewed_at  TIMESTAMPTZ,
    note         TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
