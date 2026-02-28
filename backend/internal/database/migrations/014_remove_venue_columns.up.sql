ALTER TABLE venues
    DROP COLUMN IF EXISTS country,
    DROP COLUMN IF EXISTS working_hours,
    DROP COLUMN IF EXISTS confirmation_count,
    DROP COLUMN IF EXISTS is_double_verified;
