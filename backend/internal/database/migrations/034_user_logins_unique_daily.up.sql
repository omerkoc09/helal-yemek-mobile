-- Remove duplicate rows, keeping only the earliest entry per (user_id, day)
DELETE FROM user_logins
WHERE id NOT IN (
  SELECT DISTINCT ON (user_id, DATE(created_at AT TIME ZONE 'UTC')) id
  FROM user_logins
  ORDER BY user_id, DATE(created_at AT TIME ZONE 'UTC'), created_at
);

CREATE UNIQUE INDEX user_logins_user_day_idx
  ON user_logins (user_id, DATE(created_at AT TIME ZONE 'UTC'));
