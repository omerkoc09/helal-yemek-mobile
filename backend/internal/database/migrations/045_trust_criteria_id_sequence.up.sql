-- trust_criteria.id manuel SMALLINT (1..7) olarak yönetiliyordu; admin panelinden
-- yeni kriter eklenebilmesi için otomatik artan bir sequence bağlanıyor.
-- Kolon tipi SMALLINT olarak kalıyor (venue_criteria.criteria_id FK uyumluluğu bozulmasın diye).
CREATE SEQUENCE IF NOT EXISTS trust_criteria_id_seq AS smallint OWNED BY trust_criteria.id;
SELECT setval('trust_criteria_id_seq', COALESCE((SELECT MAX(id) FROM trust_criteria), 0));
ALTER TABLE trust_criteria ALTER COLUMN id SET DEFAULT nextval('trust_criteria_id_seq');
