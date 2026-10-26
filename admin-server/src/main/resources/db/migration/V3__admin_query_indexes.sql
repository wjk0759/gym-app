-- Read-model indexes for the admin control plane and shared App queries.
-- Kept additive so existing MySQL installations can roll forward safely.

CREATE INDEX ix_users_status_created ON users (status, created_at);
CREATE INDEX ix_users_created_deleted ON users (created_at, deleted_at);
CREATE INDEX ix_profiles_nickname ON profiles (nickname);
CREATE INDEX ix_goals_user_status_created ON goals (user_id, status, created_at);
CREATE INDEX ix_equipment_scans_created_at ON equipment_scans (created_at);
CREATE INDEX ix_exercise_videos_status_updated ON exercise_videos (status, updated_at);
CREATE INDEX ix_program_days_program_week_weekday ON program_days (program_id, week_index, weekday);
CREATE INDEX ix_plan_exercises_day_order ON plan_exercises (program_day_id, order_index);
CREATE INDEX ix_set_logs_session_exercise_set ON set_logs (session_id, exercise_slug, set_index);
