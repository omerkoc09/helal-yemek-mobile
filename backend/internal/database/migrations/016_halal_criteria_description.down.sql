-- Description kolonlarını kaldır
ALTER TABLE halal_criteria DROP COLUMN IF EXISTS description_tr;
ALTER TABLE halal_criteria DROP COLUMN IF EXISTS description_en;

-- Eski seed data'ya geri dön
DELETE FROM venue_criteria;
DELETE FROM halal_criteria;

INSERT INTO halal_criteria (id, key, label_tr, label_en) VALUES
(1, 'halal_certified', 'Helal Sertifikası', 'Halal Certified'),
(2, 'known_owner', 'İşletme Sahibinden Teyit', 'Known Venue Owner');
