ALTER TABLE referral_codes ADD COLUMN used_by UUID REFERENCES users(id);
ALTER TABLE referral_codes ADD COLUMN used_at TIMESTAMPTZ;
