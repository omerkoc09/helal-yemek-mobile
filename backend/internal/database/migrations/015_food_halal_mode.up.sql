-- Yeni kolonlar: food_halal_mode ('all', 'except', 'selected') ve excluded_products (TEXT[])
ALTER TABLE venues ADD COLUMN food_halal_mode VARCHAR(20) NOT NULL DEFAULT 'selected';
ALTER TABLE venues ADD COLUMN excluded_products TEXT[] NOT NULL DEFAULT '{}';

-- Mevcut verinin migrasyonu
UPDATE venues SET food_halal_mode = 'all' WHERE all_food_halal = true;
UPDATE venues SET food_halal_mode = 'selected' WHERE all_food_halal = false;

-- Eski kolonu kaldır
ALTER TABLE venues DROP COLUMN all_food_halal;

-- Geçerli mod değerleri için constraint
ALTER TABLE venues ADD CONSTRAINT chk_food_halal_mode
  CHECK (food_halal_mode IN ('all', 'except', 'selected'));
