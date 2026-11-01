-- Long-term data model: exact measurements, partial body metrics,
-- integrity constraints, search indexes and retention-friendly indexes.
-- MySQL 8.0+; run after V11.

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------------
-- 1. Exact numeric storage (DECIMAL instead of FLOAT)
-- ---------------------------------------------------------------------------

ALTER TABLE profiles
    MODIFY height_cm DECIMAL(5, 1) NULL,
    MODIFY weight_kg DECIMAL(5, 1) NULL,
    MODIFY body_fat_pct DECIMAL(4, 1) NULL,
    MODIFY chest_cm DECIMAL(5, 1) NULL,
    MODIFY waist_cm DECIMAL(5, 1) NULL,
    MODIFY hip_cm DECIMAL(5, 1) NULL;

ALTER TABLE goals
    MODIFY target_weight_kg DECIMAL(5, 1) NULL,
    MODIFY target_body_fat_pct DECIMAL(4, 1) NULL,
    MODIFY target_waist_cm DECIMAL(5, 1) NULL;

ALTER TABLE plan_exercises
    MODIFY weight_kg DECIMAL(6, 2) NULL,
    MODIFY rpe DECIMAL(3, 1) NULL;

ALTER TABLE set_logs
    MODIFY weight_kg DECIMAL(6, 2) NULL,
    MODIFY rpe DECIMAL(3, 1) NULL;

ALTER TABLE food_logs
    MODIFY grams DECIMAL(7, 1) NOT NULL DEFAULT 0,
    MODIFY kcal DECIMAL(7, 1) NOT NULL DEFAULT 0,
    MODIFY protein DECIMAL(6, 1) NOT NULL DEFAULT 0,
    MODIFY carbs DECIMAL(6, 1) NOT NULL DEFAULT 0,
    MODIFY fat DECIMAL(6, 1) NOT NULL DEFAULT 0,
    MODIFY fiber DECIMAL(6, 1) NOT NULL DEFAULT 0;

ALTER TABLE body_metrics
    MODIFY weight_kg DECIMAL(5, 1) NULL,
    MODIFY body_fat_pct DECIMAL(4, 1) NULL,
    MODIFY waist_cm DECIMAL(5, 1) NULL,
    MODIFY arm_cm DECIMAL(5, 1) NULL,
    MODIFY thigh_cm DECIMAL(5, 1) NULL;

ALTER TABLE meal_plans
    MODIFY target_protein_g DECIMAL(6, 1) NULL,
    MODIFY target_carb_g DECIMAL(6, 1) NULL,
    MODIFY target_fat_g DECIMAL(6, 1) NULL;

-- A body metric may contain any subset of measurements, but not none.
ALTER TABLE body_metrics
    ADD CONSTRAINT ck_body_metrics_any_measure
    CHECK (
        weight_kg IS NOT NULL
        OR body_fat_pct IS NOT NULL
        OR waist_cm IS NOT NULL
        OR arm_cm IS NOT NULL
        OR thigh_cm IS NOT NULL
    );

-- ---------------------------------------------------------------------------
-- 2. Identity columns: case-sensitive opaque identifiers
-- ---------------------------------------------------------------------------

ALTER TABLE users
    MODIFY apple_sub VARCHAR(255) CHARACTER SET ascii COLLATE ascii_bin NULL,
    MODIFY wechat_openid VARCHAR(128) CHARACTER SET ascii COLLATE ascii_bin NULL,
    MODIFY wechat_unionid VARCHAR(128) CHARACTER SET ascii COLLATE ascii_bin NULL,
    MODIFY qq_openid VARCHAR(128) CHARACTER SET ascii COLLATE ascii_bin NULL;

ALTER TABLE auth_sessions
    MODIFY refresh_token_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    MODIFY user_agent VARCHAR(512) NULL;

ALTER TABLE sms_codes
    MODIFY code_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL;

ALTER TABLE admin_refresh_tokens
    MODIFY token_hash CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL;

-- ---------------------------------------------------------------------------
-- 3. De-duplicate before adding uniqueness
-- ---------------------------------------------------------------------------

-- Keep the newest active goal per user; older active rows become replaced.
UPDATE goals g
JOIN (
    SELECT id
    FROM (
        SELECT id,
               ROW_NUMBER() OVER (
                   PARTITION BY user_id
                   ORDER BY created_at DESC, id DESC
               ) AS rn
        FROM goals
        WHERE status = 'active'
    ) ranked
    WHERE ranked.rn > 1
) dup ON dup.id = g.id
SET g.status = 'replaced';

-- Keep the newest active program per user; older active rows become archived.
UPDATE programs p
JOIN (
    SELECT id
    FROM (
        SELECT id,
               ROW_NUMBER() OVER (
                   PARTITION BY user_id
                   ORDER BY created_at DESC, id DESC
               ) AS rn
        FROM programs
        WHERE status = 'active'
    ) ranked
    WHERE ranked.rn > 1
) dup ON dup.id = p.id
SET p.status = 'archived';

-- Duplicate program days, plan exercises and set logs: keep the smallest id.
DELETE d1
FROM program_days d1
JOIN program_days d2
  ON d1.program_id = d2.program_id
 AND d1.week_index = d2.week_index
 AND d1.weekday = d2.weekday
 AND d1.id > d2.id;

DELETE e1
FROM plan_exercises e1
JOIN plan_exercises e2
  ON e1.program_day_id = e2.program_day_id
 AND e1.order_index = e2.order_index
 AND e1.id > e2.id;

DELETE s1
FROM set_logs s1
JOIN set_logs s2
  ON s1.session_id = s2.session_id
 AND s1.exercise_slug = s2.exercise_slug
 AND s1.set_index = s2.set_index
 AND s1.id > s2.id;

-- Keep one notification schedule per user/weekday.
DELETE n1
FROM notification_schedules n1
JOIN notification_schedules n2
  ON n1.user_id = n2.user_id
 AND n1.weekday = n2.weekday
 AND n1.id > n2.id;

-- Keep only the newest active memory per user/key.
UPDATE ai_memories m
JOIN (
    SELECT id
    FROM (
        SELECT id,
               ROW_NUMBER() OVER (
                   PARTITION BY user_id, memory_key
                   ORDER BY COALESCE(updated_at, created_at) DESC, id DESC
               ) AS rn
        FROM ai_memories
        WHERE active = TRUE
    ) ranked
    WHERE ranked.rn > 1
) dup ON dup.id = m.id
SET m.active = FALSE;

UPDATE ai_memories
SET updated_at = created_at
WHERE updated_at IS NULL;

ALTER TABLE ai_memories
    MODIFY updated_at DATETIME NOT NULL;

-- ---------------------------------------------------------------------------
-- 4. Integrity constraints
-- ---------------------------------------------------------------------------

ALTER TABLE goals
    ADD COLUMN active_user_id VARCHAR(36)
        GENERATED ALWAYS AS (
            CASE WHEN status = 'active' THEN user_id ELSE NULL END
        ) VIRTUAL,
    ADD UNIQUE KEY uq_goals_active_user (active_user_id);

ALTER TABLE programs
    ADD COLUMN active_user_id VARCHAR(36)
        GENERATED ALWAYS AS (
            CASE WHEN status = 'active' THEN user_id ELSE NULL END
        ) VIRTUAL,
    ADD UNIQUE KEY uq_programs_active_user (active_user_id);

ALTER TABLE program_days
    ADD UNIQUE KEY uq_program_days_program_week_weekday
        (program_id, week_index, weekday);

ALTER TABLE plan_exercises
    ADD UNIQUE KEY uq_plan_exercises_day_order
        (program_day_id, order_index);

ALTER TABLE set_logs
    ADD UNIQUE KEY uq_set_logs_session_exercise_set
        (session_id, exercise_slug, set_index);

ALTER TABLE notification_schedules
    ADD UNIQUE KEY uq_notification_schedules_user_weekday
        (user_id, weekday);

ALTER TABLE ai_memories
    ADD COLUMN active_memory_key VARCHAR(80)
        GENERATED ALWAYS AS (
            CASE WHEN active = TRUE THEN memory_key ELSE NULL END
        ) VIRTUAL,
    ADD UNIQUE KEY uq_ai_memories_user_active_key
        (user_id, active_memory_key);

-- ---------------------------------------------------------------------------
-- 5. Required idempotency and ordering fields
-- ---------------------------------------------------------------------------

UPDATE workout_sessions
SET client_id = UUID()
WHERE client_id IS NULL;

ALTER TABLE workout_sessions
    MODIFY client_id VARCHAR(36) NOT NULL;

ALTER TABLE chat_messages
    MODIFY created_at DATETIME(6) NOT NULL;

-- ---------------------------------------------------------------------------
-- 6. Indexes used by real query patterns
-- ---------------------------------------------------------------------------

ALTER TABLE users
    ADD INDEX ix_users_deleted_created (deleted_at, created_at),
    ADD INDEX ix_users_status_deleted_created (status, deleted_at, created_at),
    DROP INDEX ix_users_created_deleted;

ALTER TABLE sms_codes
    ADD INDEX ix_sms_codes_phone_purpose_created (phone, purpose, created_at),
    ADD INDEX ix_sms_codes_created_at (created_at),
    DROP INDEX ix_sms_codes_phone;

ALTER TABLE auth_sessions
    ADD INDEX ix_auth_sessions_user_last_used (user_id, last_used_at),
    ADD INDEX ix_auth_sessions_user_revoked (user_id, revoked_at),
    ADD INDEX ix_auth_sessions_expires_at (expires_at),
    DROP INDEX ix_auth_sessions_user_id;

ALTER TABLE chat_messages
    ADD INDEX ix_chat_messages_session_safety (session_id, safety_flag),
    DROP INDEX ix_chat_messages_session_id;

ALTER TABLE chat_sessions
    ADD INDEX ix_chat_sessions_title (title),
    DROP INDEX ix_chat_sessions_user_id;

ALTER TABLE goals
    DROP INDEX ix_goals_user_id;

ALTER TABLE programs
    ADD INDEX ix_programs_user_created (user_id, created_at),
    ADD INDEX ix_programs_title (title),
    DROP INDEX ix_programs_user_id;

ALTER TABLE program_days
    DROP INDEX ix_program_days_program_id;

ALTER TABLE plan_exercises
    DROP INDEX ix_plan_exercises_program_day_id;

ALTER TABLE workout_sessions
    DROP INDEX ix_workout_sessions_user_id;

ALTER TABLE set_logs
    ADD INDEX ix_set_logs_session_completed_covering
        (session_id, completed, weight_kg, reps),
    DROP INDEX ix_set_logs_session_id;

ALTER TABLE meal_plans
    DROP INDEX ix_meal_plans_user_id;

ALTER TABLE equipment_scans
    DROP INDEX ix_equipment_scans_user_id;

ALTER TABLE equipment_library
    ADD INDEX ix_equipment_library_created_at (created_at),
    ADD INDEX ix_equipment_library_name (name);

ALTER TABLE notification_schedules
    DROP INDEX ix_notification_schedules_user_id;

ALTER TABLE exercises
    ADD INDEX ix_exercises_active_muscle_equipment
        (is_active, muscle_group, equipment),
    ADD INDEX ix_exercises_name_zh (name_zh);

ALTER TABLE exercise_videos
    ADD INDEX ix_exercise_videos_slug_status_updated
        (exercise_slug, status, updated_at),
    ADD INDEX ix_exercise_videos_title (title),
    DROP INDEX ix_exercise_videos_exercise_slug,
    DROP INDEX ix_exercise_videos_status;

ALTER TABLE agent_runs
    ADD INDEX ix_agent_runs_created_at (created_at),
    ADD INDEX ix_agent_runs_intent_created (intent, created_at);

ALTER TABLE agent_steps
    DROP INDEX ix_agent_steps_run;

ALTER TABLE agent_action_events
    ADD INDEX ix_agent_action_events_created_at (created_at),
    ADD INDEX ix_agent_action_events_status_created (status, created_at),
    ADD INDEX ix_agent_action_events_type_created (action_type, created_at);

ALTER TABLE agent_plan_proposals
    ADD INDEX ix_agent_plan_proposals_expires_at (expires_at),
    ADD INDEX ix_agent_plan_proposals_run_created (run_id, created_at),
    DROP INDEX ix_agent_plan_proposals_run;

ALTER TABLE plan_day_states
    ADD INDEX ix_plan_day_states_updated_at (updated_at),
    ADD INDEX ix_plan_day_states_user_assigned (user_id, assigned_date),
    DROP INDEX ix_plan_day_states_user_plan;

ALTER TABLE ai_jobs
    ADD INDEX ix_ai_jobs_status_created (status, created_at),
    DROP INDEX ix_ai_jobs_user_id;

ALTER TABLE ai_memories
    ADD INDEX ix_ai_memories_user_active_created (user_id, active, created_at),
    DROP INDEX ix_ai_memories_user_id,
    DROP INDEX ix_ai_memories_memory_key;

ALTER TABLE auth_events
    ADD INDEX ix_auth_events_created_at (created_at);

ALTER TABLE admin_audit_logs
    ADD INDEX ix_admin_audit_logs_action_created (action, created_at),
    ADD INDEX ix_admin_audit_logs_actor_created (actor, created_at);

-- ---------------------------------------------------------------------------
-- 7. Chinese full-text search (ngram) + prefix fallback indexes
-- ---------------------------------------------------------------------------

ALTER TABLE profiles
    ADD FULLTEXT KEY ft_profiles_nickname (nickname) WITH PARSER ngram;

ALTER TABLE exercises
    ADD FULLTEXT KEY ft_exercises_name (name_zh, name_en) WITH PARSER ngram;

ALTER TABLE equipment_library
    ADD FULLTEXT KEY ft_equipment_library_search (name, notes) WITH PARSER ngram;

ALTER TABLE chat_sessions
    ADD FULLTEXT KEY ft_chat_sessions_title (title) WITH PARSER ngram;

ALTER TABLE programs
    ADD FULLTEXT KEY ft_programs_title (title) WITH PARSER ngram;

ALTER TABLE exercise_videos
    ADD FULLTEXT KEY ft_exercise_videos_title (title) WITH PARSER ngram;
