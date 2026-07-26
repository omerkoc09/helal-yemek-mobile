-- Tekil yemekleri kaldır, mekanı doğrudan mutfak kategorilerine bağla.
-- food_items + venue_food_items tabloları kalkar; yeni venue_categories bağı
-- mekanı food_categories'e doğrudan bağlar. food_categories DOKUNULMAZ.

-- Yeni mekan-kategori bağı (mekan doğrudan mutfak seçer).
CREATE TABLE venue_categories (
    venue_id    UUID NOT NULL REFERENCES venues(id) ON DELETE CASCADE,
    category_id INT  NOT NULL REFERENCES food_categories(id) ON DELETE CASCADE,
    PRIMARY KEY (venue_id, category_id)
);

-- food_halal_mode 3 moddan 2'ye düşer: 'selected' kayıtları 'all'a çekilir.
UPDATE venues SET food_halal_mode = 'all' WHERE food_halal_mode = 'selected';

-- Kolon default'u 'selected'idi (015); artık geçersiz → 'all'a çek.
ALTER TABLE venues ALTER COLUMN food_halal_mode SET DEFAULT 'all';

-- CHECK kısıtını 2 moda sıkılaştır ('selected' artık DB seviyesinde de geçersiz).
ALTER TABLE venues DROP CONSTRAINT IF EXISTS chk_food_halal_mode;
ALTER TABLE venues ADD CONSTRAINT chk_food_halal_mode
  CHECK (food_halal_mode IN ('all', 'except'));

-- Ölü kolon (hiçbir yerde kullanılmıyordu).
ALTER TABLE venues DROP COLUMN IF EXISTS all_food_halal;

-- İlişki tablosunu önce düşür (food_items'a FK bağlı).
DROP TABLE IF EXISTS venue_food_items;
DROP TABLE IF EXISTS food_items;
