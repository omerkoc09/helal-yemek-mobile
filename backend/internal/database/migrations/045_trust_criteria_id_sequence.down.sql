ALTER TABLE trust_criteria ALTER COLUMN id DROP DEFAULT;
DROP SEQUENCE IF EXISTS trust_criteria_id_seq;
