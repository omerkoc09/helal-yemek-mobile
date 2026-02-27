CREATE TABLE venues (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name               VARCHAR(255) NOT NULL,
    address            TEXT NOT NULL,
    city               VARCHAR(100) NOT NULL,
    country            VARCHAR(100) NOT NULL,
    location           GEOGRAPHY(POINT, 4326) NOT NULL,
    working_hours      JSONB,
    notes              TEXT,
    status             VARCHAR(20) NOT NULL DEFAULT 'pending',
    rejection_note     TEXT,
    added_by           UUID NOT NULL REFERENCES users(id),
    approved_by        UUID REFERENCES users(id),
    verified_at        TIMESTAMPTZ,
    confirmation_count INT NOT NULL DEFAULT 0,
    is_double_verified BOOLEAN NOT NULL DEFAULT false,
    deleted_at         TIMESTAMPTZ,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX venues_location_idx ON venues USING GIST (location);
CREATE INDEX venues_city_idx ON venues (city);
CREATE INDEX venues_status_idx ON venues (status);
CREATE INDEX venues_deleted_at_idx ON venues (deleted_at) WHERE deleted_at IS NULL;
