-- Kodsuz guide başvurusunda kullanıcının "okudum-onaylıyorum" kabulü.
-- Null = kodlu/otomatik onaylı veya eski kayıtlar.
ALTER TABLE guide_applications ADD COLUMN terms_accepted_at TIMESTAMPTZ;
