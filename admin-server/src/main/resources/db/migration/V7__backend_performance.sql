-- Backend performance and data-consistency indexes.
-- Additive migration for existing MySQL installations.

ALTER TABLE workout_sessions
    ADD COLUMN client_id VARCHAR(36) NULL;

CREATE UNIQUE INDEX uq_workout_sessions_user_client
    ON workout_sessions(user_id, client_id);

CREATE INDEX ix_workout_sessions_program_day
    ON workout_sessions(program_day_id);

CREATE INDEX ix_equipment_scans_user_created
    ON equipment_scans(user_id, created_at);

CREATE INDEX ix_ai_jobs_user_created
    ON ai_jobs(user_id, created_at);

CREATE INDEX ix_ai_jobs_kind_status_created
    ON ai_jobs(kind, status, created_at);

CREATE INDEX ix_chat_messages_safety_created
    ON chat_messages(safety_flag, created_at);

CREATE INDEX ix_chat_messages_session_created
    ON chat_messages(session_id, created_at);

CREATE INDEX ix_set_logs_session_completed
    ON set_logs(session_id, completed);

-- Keep the newest meal plan for each user/day before adding uniqueness.
DELETE older
FROM meal_plans older
JOIN meal_plans newer
  ON older.user_id = newer.user_id
 AND older.plan_date = newer.plan_date
 AND (
      older.created_at < newer.created_at
      OR (older.created_at = newer.created_at AND older.id < newer.id)
 );

ALTER TABLE meal_plans
    ADD CONSTRAINT uq_meal_plans_user_date UNIQUE (user_id, plan_date);
