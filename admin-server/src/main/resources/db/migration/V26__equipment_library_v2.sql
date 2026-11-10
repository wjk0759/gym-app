-- V26: equipment library v2 (physical equipment) + personal exercise library.
--
-- equipment_library used to store exercises (slug = exercise slug). It now
-- stores the user's physical equipment: equipment_type is the 94-class catalog
-- slug, category is the broad type derived from it.
--
-- user_exercise_library is the user's personal exercise library: the subset of
-- the global exercise catalog they chose for plan generation.

ALTER TABLE equipment_library
    ADD COLUMN equipment_type VARCHAR(40) NULL AFTER client_id,
    ADD COLUMN category VARCHAR(20) NULL AFTER equipment_type,
    ADD COLUMN photo_url TEXT NULL AFTER notes;

CREATE TABLE IF NOT EXISTS user_exercise_library (
    id VARCHAR(36) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    exercise_slug VARCHAR(80) NOT NULL,
    equipment_type VARCHAR(40) NULL,
    source VARCHAR(20) NOT NULL DEFAULT 'manual',
    created_at DATETIME NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_user_exercise_library (user_id, exercise_slug),
    KEY ix_user_exercise_library_user (user_id),
    CONSTRAINT fk_user_exercise_library_user
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT fk_user_exercise_library_exercise
        FOREIGN KEY (exercise_slug) REFERENCES exercises (slug) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
