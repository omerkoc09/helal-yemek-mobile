DROP INDEX IF EXISTS users_phone_unique;

ALTER TABLE users
    DROP COLUMN IF EXISTS surname,
    DROP COLUMN IF EXISTS phone;
