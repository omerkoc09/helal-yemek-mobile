ALTER TABLE venues
    ADD COLUMN IF NOT EXISTS verification_due_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS last_notified_at    TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_venues_verification_due_at ON venues(verification_due_at)
    WHERE status = 'approved';
