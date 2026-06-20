-- Rehber-şehir bağlama + referans sistemini kaldırma.

-- 1. guide_applications.city: önce nullable ekle, eski satırları doldur, NOT NULL yap.
ALTER TABLE guide_applications ADD COLUMN city TEXT;
UPDATE guide_applications SET city = 'İstanbul' WHERE city IS NULL;
ALTER TABLE guide_applications ALTER COLUMN city SET NOT NULL;

-- 2. users.guide_city: onaylı rehberin aktif çalışma şehri (nullable).
ALTER TABLE users ADD COLUMN guide_city TEXT;

-- 3. Referans sistemini kaldır.
ALTER TABLE guide_applications DROP COLUMN IF EXISTS referred_by;
DROP TABLE IF EXISTS referral_codes;
