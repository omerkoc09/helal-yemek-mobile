CREATE UNIQUE INDEX IF NOT EXISTS venues_google_place_id_unique
    ON venues (google_place_id)
    WHERE google_place_id IS NOT NULL AND deleted_at IS NULL;
