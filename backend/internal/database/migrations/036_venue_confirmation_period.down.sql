ALTER TABLE venue_confirmations DROP COLUMN IF EXISTS period_start;

ALTER TABLE venues
    DROP COLUMN IF EXISTS is_double_verified,
    DROP COLUMN IF EXISTS confirmation_count;
