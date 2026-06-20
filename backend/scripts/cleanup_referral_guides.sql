-- DEV-ONLY, TEK SEFERLİK. Üretimde ÇALIŞTIRMAYIN.
-- Mevcut veriler test verisidir. Referans sistemiyle gelmiş, şehri olmayan
-- rehberleri traveler'a düşürür (hesap/veri korunur). Migration'a GÖMÜLMEZ
-- (gerçek kullanıcılarda tehlikeli olur).

UPDATE users SET role = 'traveler', guide_city = NULL
WHERE role = 'guide' AND guide_city IS NULL;
