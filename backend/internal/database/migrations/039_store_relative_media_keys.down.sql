-- Bu migration OTOMATİK GERİ ALINAMAZ ve bu bilinçli bir karardır.
--
-- Up migration, tam URL'in ön ekini (şema + host + port + /static) atarak yalnızca
-- dosya anahtarını bırakıyor. Atılan ön ek ortama göre değişiyordu
-- (http://localhost:3000, http://192.168.1.5:3000, ileride S3/CDN adresi) ve
-- veritabanında hiçbir yerde saklanmıyor — dolayısıyla SQL ile geri üretilemez.
-- Buraya sabit bir ön ek yazmak, yanlış ortamın adresini kaydetmek olurdu.
--
-- Geri alma gerekirse:
--   UPDATE venue_photos SET url = '<O_ORTAMIN_STORAGE_URL>/static/' || url
--   WHERE url NOT LIKE 'http%';
-- ve food_categories için aynısı. <O_ORTAMIN_STORAGE_URL> elle verilmelidir.
--
-- Not: Uygulama katmanı (StorageService.PublicURL) hem anahtarı hem tam URL'i
-- kabul ettiği için, bu migration uygulanmış bir veritabanı ESKİ uygulama
-- sürümüyle çalıştırılırsa görseller kırılır — çünkü eski sürüm DB değerini
-- doğrudan URL sanar. Geri alma senaryosunda uygulama da geri alınmalıdır.

SELECT 1;
