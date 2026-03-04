CREATE TABLE halal_criteria (
    id       SMALLINT PRIMARY KEY,
    key      VARCHAR(50) UNIQUE NOT NULL,
    label_tr VARCHAR(100) NOT NULL,
    label_en VARCHAR(100) NOT NULL,
    description_tr TEXT,
    description_en TEXT
);

INSERT INTO halal_criteria VALUES
(1, 'halal_certified',     'Helal Sertifikası', 'Halal Certified', 'İşletme helal sertifikalı ürünler kullanıyor.', 'The venue uses halal certified products.'),
(2, 'known_owner',        'İşletme Sahibinden Teyit', 'Known Venue Owner', 'Yemeklerin caizliği işletme sahibinden teyit edildi.', 'The food is certified by the owner of the venue.'),
(3, 'no_boycott_products', 'Boykot Ürünü Yok', 'No Boycott Products/Used', 'İşletmede boykot listelerinde yer alan markaların ürünleri satılmamakta ve kullanılmamaktadır.', 'The establishment does not sell or use products from global brands on boycott lists.');

CREATE TABLE venue_criteria (
    venue_id    UUID REFERENCES venues(id) ON DELETE CASCADE,
    criteria_id SMALLINT REFERENCES halal_criteria(id),
    PRIMARY KEY (venue_id, criteria_id)
);
