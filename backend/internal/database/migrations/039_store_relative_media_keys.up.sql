-- Fotoğraf ve kategori görsellerini TAM URL yerine dosya ANAHTARI olarak sakla.
--
-- Neden: tam URL saklandığında ortam her değiştiğinde veri migrasyonu gerekiyor.
-- Android emülatörü için localhost -> LAN IP değişiminde bu bedel bir kez ödendi
-- (ve food_categories o sırada gözden kaçtığı için tutarsız kaldı). Prod'a geçiş
-- ve S3 taşıması aynı bedeli tekrar doğururdu.
--
-- Dönüşüm: son '/' karakterinden sonrasını alır.
--   'http://192.168.1.5:3000/static/abc.jpg'  ->  'abc.jpg'
-- Zaten anahtar olan (eğik çizgi içermeyen) kayıtlar değişmez, bu yüzden
-- migration tekrar çalıştırılsa da güvenlidir (idempotent).

UPDATE venue_photos
SET url = regexp_replace(url, '^.*/', '')
WHERE url LIKE 'http://%' OR url LIKE 'https://%';

UPDATE food_categories
SET image_url = regexp_replace(image_url, '^.*/', '')
WHERE image_url IS NOT NULL
  AND (image_url LIKE 'http://%' OR image_url LIKE 'https://%');
