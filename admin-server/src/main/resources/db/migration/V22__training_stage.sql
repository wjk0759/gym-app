ALTER TABLE profiles
    ADD COLUMN training_stage VARCHAR(20) NOT NULL DEFAULT 'beginner' AFTER experience;

-- Promote existing users from their completed training days. A training day is
-- a distinct Asia/Shanghai calendar date with at least one completed set.
UPDATE profiles p
JOIN (
    SELECT ws.user_id,
           COUNT(DISTINCT DATE(DATE_ADD(ws.started_at, INTERVAL 8 HOUR))) AS days
    FROM workout_sessions ws
    WHERE EXISTS (
        SELECT 1
        FROM set_logs sl
        WHERE sl.session_id = ws.id
          AND sl.completed = 1
    )
    GROUP BY ws.user_id
) history ON history.user_id = p.user_id
SET p.training_stage = CASE
    WHEN history.days >= 120 THEN 'advanced'
    WHEN history.days >= 60 THEN 'intermediate'
    ELSE 'beginner'
END;
