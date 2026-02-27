-- Admin kullanıcısı
INSERT INTO users (email, password_hash, name, role, provider, is_active)
VALUES (
    'admin@caizmi.com',
    '$2a$10$EdBVw1.N9cp40N84NwqiJO1mvpLs43TzHf5pezgJGm2vNK5cQh1fK',
    'Admin',
    'admin',
    'email',
    true
) ON CONFLICT (email) DO UPDATE SET
    password_hash = EXCLUDED.password_hash,
    role = EXCLUDED.role;

-- Rehber (Guide) kullanıcısı
INSERT INTO users (email, password_hash, name, role, provider, is_active)
VALUES (
    'rehber@caizmi.com',
    '$2a$10$QZ85tdctzhB2y5l9j3S.pOSbgHzFUKkxtAUvhF755xFuzyPL32XIa',
    'Rehber',
    'guide',
    'email',
    true
) ON CONFLICT (email) DO UPDATE SET
    password_hash = EXCLUDED.password_hash,
    role = EXCLUDED.role;
