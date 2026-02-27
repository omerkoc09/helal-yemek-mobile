-- Yemek kategorileri
CREATE TABLE food_categories (
    id       SERIAL PRIMARY KEY,
    key      VARCHAR(50) UNIQUE NOT NULL,
    label_tr VARCHAR(100) NOT NULL,
    label_en VARCHAR(100) NOT NULL
);

INSERT INTO food_categories (key, label_tr, label_en) VALUES
('doner',           'Döner',            'Doner'),
('tost',            'Tost',             'Toast'),
('borek',           'Börek',            'Borek'),
('pide_lahmacun',   'Pide & Lahmacun',  'Pide & Lahmacun'),
('pizza',           'Pizza',            'Pizza'),
('kofte',           'Köfte',            'Meatball'),
('cig_kofte',       'Çiğ Köfte',        'Raw Meatball'),
('tatli',           'Tatlı',            'Dessert'),
('tantuni',         'Tantuni',          'Tantuni'),
('tavuk',           'Tavuk',            'Chicken'),
('corba',           'Çorba',            'Soup'),
('kebap',           'Kebap',            'Kebab'),
('balik',           'Balık',            'Fish'),
('dondurma',        'Dondurma',         'Ice Cream');

-- Her kategorinin alt yemek çeşitleri
CREATE TABLE food_items (
    id          SERIAL PRIMARY KEY,
    category_id INT NOT NULL REFERENCES food_categories(id) ON DELETE CASCADE,
    key         VARCHAR(100) NOT NULL,
    label_tr    VARCHAR(150) NOT NULL,
    label_en    VARCHAR(150) NOT NULL,
    is_custom   BOOLEAN NOT NULL DEFAULT false,
    UNIQUE(category_id, key)
);

-- Döner (category_id = 1)
INSERT INTO food_items (category_id, key, label_tr, label_en) VALUES
(1, 'et_doner',     'Et Döner',     'Meat Doner'),
(1, 'tavuk_doner',  'Tavuk Döner',  'Chicken Doner');

-- Tost (category_id = 2)
INSERT INTO food_items (category_id, key, label_tr, label_en) VALUES
(2, 'ayvalik_tostu',  'Ayvalık Tostu',  'Ayvalik Toast'),
(2, 'sucuklu_tost',   'Sucuklu Tost',   'Sucuk Toast'),
(2, 'kasarli_tost',   'Kaşarlı Tost',   'Cheese Toast');

-- Börek (category_id = 3)
INSERT INTO food_items (category_id, key, label_tr, label_en) VALUES
(3, 'su_boregi',      'Su Böreği',       'Water Borek'),
(3, 'kol_boregi',     'Kol Böreği',      'Arm Borek'),
(3, 'kurt_boregi',    'Kürt Böreği',     'Kurdish Borek'),
(3, 'sigara_boregi',  'Sigara Böreği',   'Cigar Borek'),
(3, 'pacanga_boregi', 'Paçanga Böreği',  'Pacanga Borek');

-- Pide & Lahmacun (category_id = 4)
INSERT INTO food_items (category_id, key, label_tr, label_en) VALUES
(4, 'kiymali',    'Kıymalı',    'Minced Meat'),
(4, 'kasarli',    'Kaşarlı',    'With Cheese'),
(4, 'kusbasili',  'Kuşbaşılı',  'Diced Meat'),
(4, 'sucuklu',    'Sucuklu',    'With Sucuk');

-- Pizza (category_id = 5)
INSERT INTO food_items (category_id, key, label_tr, label_en) VALUES
(5, 'margarita',  'Margarita',          'Margherita'),
(5, 'karisik',    'Karışık (Mista)',    'Mixed (Mista)'),
(5, 'pepperoni',  'Pepperoni',          'Pepperoni');

-- Köfte (category_id = 6)
INSERT INTO food_items (category_id, key, label_tr, label_en) VALUES
(6, 'inegol_kofte',    'İnegöl Köfte',    'Inegol Meatball'),
(6, 'akcaabat_kofte',  'Akçaabat Köfte',  'Akcaabat Meatball'),
(6, 'tekirdag_kofte',  'Tekirdağ Köfte',  'Tekirdag Meatball'),
(6, 'icli_kofte',      'İçli Köfte',      'Stuffed Meatball'),
(6, 'izmir_kofte',     'İzmir Köfte',     'Izmir Meatball');

-- Çiğ Köfte (category_id = 7) — tek kategori, alt çeşit yok

-- Tatlı (category_id = 8)
INSERT INTO food_items (category_id, key, label_tr, label_en) VALUES
(8, 'baklava',     'Baklava',      'Baklava'),
(8, 'kunefe',      'Künefe',       'Kunefe'),
(8, 'kadayif',     'Kadayıf',      'Kadayif'),
(8, 'sekerpare',   'Şekerpare',    'Sekerpare'),
(8, 'sutlac',      'Sütlaç',       'Rice Pudding'),
(8, 'kazandibi',   'Kazandibi',    'Kazandibi'),
(8, 'keskul',      'Keşkül',       'Keskul'),
(8, 'supangle',    'Supangle',     'Chocolate Pudding'),
(8, 'profiterol',  'Profiterol',   'Profiterole');

-- Tantuni (category_id = 9)
INSERT INTO food_items (category_id, key, label_tr, label_en) VALUES
(9, 'et_tantuni',    'Et Tantuni',    'Meat Tantuni'),
(9, 'tavuk_tantuni', 'Tavuk Tantuni', 'Chicken Tantuni');

-- Tavuk (category_id = 10)
INSERT INTO food_items (category_id, key, label_tr, label_en) VALUES
(10, 'tavuk_sis',      'Tavuk Şiş',      'Chicken Skewer'),
(10, 'kanat',          'Kanat',           'Chicken Wings'),
(10, 'tavuk_pirzola',  'Tavuk Pirzola',   'Chicken Chop');

-- Çorba (category_id = 11)
INSERT INTO food_items (category_id, key, label_tr, label_en) VALUES
(11, 'mercimek',    'Mercimek',       'Lentil Soup'),
(11, 'ezogelin',    'Ezogelin',       'Ezogelin Soup'),
(11, 'domates',     'Domates',        'Tomato Soup'),
(11, 'yayla',       'Yayla',          'Yayla Soup'),
(11, 'kelle_paca',  'Kelle Paça',     'Head Trotter Soup'),
(11, 'iskembe',     'İşkembe',        'Tripe Soup'),
(11, 'tuzlama',     'Tuzlama',        'Salted Meat Soup'),
(11, 'ayak_paca',   'Ayak Paça',      'Foot Trotter Soup');

-- Kebap (category_id = 12)
INSERT INTO food_items (category_id, key, label_tr, label_en) VALUES
(12, 'adana',             'Adana',              'Adana Kebab'),
(12, 'urfa',              'Urfa',               'Urfa Kebab'),
(12, 'patlican_kebabi',   'Patlıcan Kebabı',    'Eggplant Kebab'),
(12, 'beyti_sarmali',     'Beyti Sarmalı',      'Beyti Wrap'),
(12, 'cag_kebabi',        'Cağ Kebabı',         'Cag Kebab'),
(12, 'buryan_kebabi',     'Büryan Kebabı',      'Buryan Kebab'),
(12, 'ali_nazik',         'Ali Nazik',          'Ali Nazik'),
(12, 'kagit_kebabi',      'Kağıt Kebabı',       'Paper Kebab');

-- Balık (category_id = 13)
INSERT INTO food_items (category_id, key, label_tr, label_en) VALUES
(13, 'hamsi_tava',    'Hamsi Tava',      'Fried Anchovy'),
(13, 'istavrit',      'İstavrit',        'Horse Mackerel'),
(13, 'cupra',         'Çupra',           'Sea Bream'),
(13, 'levrek',        'Levrek',          'Sea Bass'),
(13, 'lufer',         'Lüfer',           'Bluefish'),
(13, 'balik_ekmek',   'Balık Ekmek',     'Fish Sandwich');

-- Dondurma (category_id = 14)
INSERT INTO food_items (category_id, key, label_tr, label_en) VALUES
(14, 'maras_dondurma',    'Maraş Dövme Dondurması',  'Maras Ice Cream'),
(14, 'cilekli',           'Çilekli',                  'Strawberry'),
(14, 'limonlu',           'Limonlu',                  'Lemon'),
(14, 'visneli',           'Vişneli',                  'Sour Cherry'),
(14, 'cikolatali',        'Çikolatalı',               'Chocolate'),
(14, 'karamelli',         'Karamelli',                'Caramel'),
(14, 'antep_fistikli',    'Antep Fıstıklı',           'Pistachio'),
(14, 'italyan_gelato',    'İtalyan Gelato',            'Italian Gelato');

-- Mekan-yemek ilişki tablosu
CREATE TABLE venue_food_items (
    venue_id     UUID NOT NULL REFERENCES venues(id) ON DELETE CASCADE,
    food_item_id INT NOT NULL REFERENCES food_items(id) ON DELETE CASCADE,
    PRIMARY KEY (venue_id, food_item_id)
);

-- Mekan tüm yemekler caiz flag (venue başına)
ALTER TABLE venues ADD COLUMN all_food_halal BOOLEAN NOT NULL DEFAULT false;
