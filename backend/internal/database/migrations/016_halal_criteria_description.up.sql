-- halal_criteria tablosuna description kolonları ekle
ALTER TABLE halal_criteria ADD COLUMN IF NOT EXISTS description_tr TEXT;
ALTER TABLE halal_criteria ADD COLUMN IF NOT EXISTS description_en TEXT;

-- Eski kriterleri temizle ve yeni seed data ekle
DELETE FROM venue_criteria;
DELETE FROM halal_criteria;

INSERT INTO halal_criteria (id, key, label_tr, label_en, description_tr, description_en) VALUES
(1, 'halal_certified',     'Helal Sertifikası',         'Halal Certified',           'İşletme helal sertifikalı ürünler kullanıyor.', 'The venue uses halal certified products.'),
(2, 'known_owner',         'İşletme Sahibinden Teyit',  'Known Venue Owner',         'Yemeklerin caizliği işletme sahibinden teyit edildi.', 'The food is certified by the owner of the venue.'),
(3, 'no_boycott_products', 'Boykot Ürünü Yok',          'No Boycott Products/Used',  'İşletmede boykot listelerinde yer alan markaların ürünleri satılmamakta ve kullanılmamaktadır.', 'The establishment does not sell or use products from global brands on boycott lists.');
