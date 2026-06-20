-- Geri alma: referans şemasını yeniden oluştur, city kolonlarını düşür.

-- referral_codes tablosunu yeniden oluştur (multiuse hali, 029'a göre).
CREATE TABLE IF NOT EXISTS referral_codes (
	id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
	guide_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
	code       TEXT NOT NULL UNIQUE,
	status     TEXT NOT NULL DEFAULT 'active',
	created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE guide_applications ADD COLUMN IF NOT EXISTS referred_by UUID REFERENCES users(id);

ALTER TABLE users DROP COLUMN IF EXISTS guide_city;
ALTER TABLE guide_applications DROP COLUMN IF EXISTS city;
