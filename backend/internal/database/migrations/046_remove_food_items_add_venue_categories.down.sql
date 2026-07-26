-- Best-effort geri alma: tablo şemaları yeniden yaratılır ama SİLİNEN ITEM VERİSİ
-- GERİ GELMEZ (tasarımda kabul edildi — veri taşınmıyor). food_halal_mode'daki
-- 'selected'→'all' dönüşümü de geri alınmaz (hangi kaydın 'selected' olduğu bilgisi
-- kaybolmuştur).

-- food_items — GÜNCEL şema (migration 038 sonrası: label_tr→name, label_en drop).
CREATE TABLE IF NOT EXISTS food_items (
    id          SERIAL PRIMARY KEY,
    category_id INT NOT NULL REFERENCES food_categories(id) ON DELETE CASCADE,
    key         VARCHAR(100) NOT NULL,
    name        VARCHAR(150) NOT NULL,
    is_custom   BOOLEAN NOT NULL DEFAULT false,
    UNIQUE(category_id, key)
);

-- Mekan-yemek ilişki tablosu.
CREATE TABLE IF NOT EXISTS venue_food_items (
    venue_id     UUID NOT NULL REFERENCES venues(id) ON DELETE CASCADE,
    food_item_id INT NOT NULL REFERENCES food_items(id) ON DELETE CASCADE,
    PRIMARY KEY (venue_id, food_item_id)
);

-- Ölü kolonu geri ekle (orijinal tanım: 012).
ALTER TABLE venues ADD COLUMN IF NOT EXISTS all_food_halal BOOLEAN NOT NULL DEFAULT false;

-- CHECK kısıtını 3 moda geri genişlet ('selected' yeniden geçerli olsun).
ALTER TABLE venues DROP CONSTRAINT IF EXISTS chk_food_halal_mode;
ALTER TABLE venues ADD CONSTRAINT chk_food_halal_mode
  CHECK (food_halal_mode IN ('all', 'except', 'selected'));

-- Kolon default'unu orijinaline (015) geri döndür.
ALTER TABLE venues ALTER COLUMN food_halal_mode SET DEFAULT 'selected';

-- Yeni bağı düşür.
DROP TABLE IF EXISTS venue_categories;
