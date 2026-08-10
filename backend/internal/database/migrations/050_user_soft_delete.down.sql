-- Geri alma: kısmi index'ler kaldırılır ve mutlak UNIQUE kısıt geri gelir.
--
-- UYARI: Anonimleştirilmiş kayıtlar geride kalırsa (deleted-<id>@deleted.local)
-- bunlar benzersiz olduğu için kısıt yine kurulabilir; ancak aynı e-postayla
-- yeniden kaydolmuş bir kullanıcı varsa çakışma oluşur ve migration düşer.
DROP INDEX IF EXISTS users_deleted_at_idx;
DROP INDEX IF EXISTS users_email_active_key;

ALTER TABLE users ADD CONSTRAINT users_email_key UNIQUE (email);

ALTER TABLE users DROP COLUMN IF EXISTS deleted_at;
