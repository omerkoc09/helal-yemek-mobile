ALTER TABLE halal_criteria ADD COLUMN description_en TEXT;
ALTER TABLE halal_criteria RENAME COLUMN description TO description_tr;
ALTER TABLE halal_criteria ADD COLUMN label_en VARCHAR(100) NOT NULL DEFAULT '';
ALTER TABLE halal_criteria RENAME COLUMN name TO label_tr;

ALTER TABLE food_items ADD COLUMN label_en VARCHAR(150) NOT NULL DEFAULT '';
ALTER TABLE food_items RENAME COLUMN name TO label_tr;

ALTER TABLE food_categories ADD COLUMN label_en VARCHAR(100) NOT NULL DEFAULT '';
ALTER TABLE food_categories RENAME COLUMN name TO label_tr;
