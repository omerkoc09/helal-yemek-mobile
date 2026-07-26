-- Güven kriterleri setini genişlet: mekanı çok yönlü anlatan 4 yeni kriter.
-- Guide seçer, admin süzer/onaylar; son kullanıcı görmez (yalnızca rozete dolaylı katkı).
INSERT INTO trust_criteria (id, key, name, description) VALUES
(4, 'no_alcohol',       'Alkolsüz İşletme', 'Mekanda alkollü içecek satılmıyor ve servis edilmiyor.'),
(5, 'clean_maintained', 'Temiz ve Bakımlı', 'Mekan genel olarak temiz ve bakımlı görünüyor.'),
(6, 'visited_by_guide', 'Yerinde Görüldü',  'Bir yerel rehber mekanı bizzat ziyaret edip teyit etti.'),
(7, 'long_standing',    'Köklü İşletme',    'Uzun süredir hizmet veren, bilinen bir işletme.')
ON CONFLICT (id) DO NOTHING;
