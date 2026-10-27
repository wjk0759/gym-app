-- Keep historical exercise rows for existing plans/workouts, but let the app
-- serve only the current action library. The two motion URL columns are for
-- the RepDB Free two-frame UI evaluation; they are not video assets.
ALTER TABLE exercises
    ADD COLUMN motion_start_url TEXT NULL,
    ADD COLUMN motion_end_url TEXT NULL,
    ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT TRUE,
    ADD INDEX ix_exercises_is_active (is_active);
