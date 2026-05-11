DROP INDEX IF EXISTS idx_venues_verification_due_at;
ALTER TABLE venues
    DROP COLUMN IF EXISTS verification_due_at,
    DROP COLUMN IF EXISTS last_notified_at;
