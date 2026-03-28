-- Eski boolean kolonu geri ekle
ALTER TABLE venues ADD COLUMN all_food_halal BOOLEAN NOT NULL DEFAULT false;

-- Veriyi geri taşı
UPDATE venues SET all_food_halal = true WHERE food_halal_mode = 'all';

-- Yeni kolon ve constraint'leri kaldır
ALTER TABLE venues DROP CONSTRAINT IF EXISTS chk_food_halal_mode;
ALTER TABLE venues DROP COLUMN excluded_products;
ALTER TABLE venues DROP COLUMN food_halal_mode;
