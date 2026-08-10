-- Hesap silme (KVKK + App Store Guideline 5.1.1(v) / Google Play zorunluluğu).
--
-- Düz DELETE mümkün değil: users'a 15 foreign key var ve 8'i NO ACTION + NOT NULL
-- (venues.added_by, venue_photos.uploaded_by, reviews.user_id,
-- venue_confirmations.guide_id, venue_reports.user_id, guide_applications.user_id,
-- venue_verification_logs.guide_id, audit_logs.admin_id). Silme FK ihlaliyle düşerdi.
--
-- Bu yüzden ANONİMLEŞTİRME uygulanıyor: kullanıcının kişisel verisi temizlenir,
-- topluluk katkısı (mekanlar, doğrulamalar, yorumlar) anonim olarak kalır.
ALTER TABLE users ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- E-posta benzersizliği yalnızca AKTİF hesaplar için geçerli olmalı.
-- Anonimleştirmede e-posta "deleted-<id>@deleted.local" ile değiştiriliyor;
-- mevcut mutlak UNIQUE kısıt bunu teknik olarak kaldırırdı ama silinen kayıtları
-- da benzersizlik havuzunda tutmak gereksiz. Kısmi index, aynı e-postanın
-- silinme sonrası yeniden kaydolmasına da izin verir.
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_email_key;

CREATE UNIQUE INDEX IF NOT EXISTS users_email_active_key
    ON users (email)
    WHERE deleted_at IS NULL;

-- Silinmiş hesapları listelerden ayıklayan sorgular için.
CREATE INDEX IF NOT EXISTS users_deleted_at_idx
    ON users (deleted_at)
    WHERE deleted_at IS NOT NULL;
