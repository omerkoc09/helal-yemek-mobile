CREATE TABLE referral_codes (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    guide_id   UUID NOT NULL REFERENCES users(id),
    code       VARCHAR(10) UNIQUE NOT NULL,
    status     VARCHAR(10) NOT NULL DEFAULT 'active',
    used_by    UUID REFERENCES users(id),
    used_at    TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_referral_codes_code ON referral_codes(code);
CREATE INDEX idx_referral_codes_guide_active ON referral_codes(guide_id, status);
