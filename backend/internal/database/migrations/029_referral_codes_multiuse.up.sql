-- Çok kullanımlı kod: tek kullanıcıya bağlı used_by/used_at artık geçersiz.
-- Mevcut 'used' kayıtlarını 'active'e taşı (kod kalıcı hale geliyor).
UPDATE referral_codes SET status = 'active' WHERE status = 'used';

ALTER TABLE referral_codes DROP COLUMN IF EXISTS used_by;
ALTER TABLE referral_codes DROP COLUMN IF EXISTS used_at;
