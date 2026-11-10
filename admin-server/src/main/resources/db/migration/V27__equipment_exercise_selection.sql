-- V27: per-equipment exercise selection + universal equipment checkboxes.
--
-- Replaces the flat user_exercise_library (removed) with:
--   user_equipment_exercise     fixed machine -> enabled exercises
--   user_universal_equipment    universal equipment checkboxes

DROP TABLE IF EXISTS user_exercise_library;

CREATE TABLE IF NOT EXISTS user_equipment_exercise (
    id VARCHAR(36) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    equipment_id VARCHAR(36) NOT NULL,
    exercise_slug VARCHAR(80) NOT NULL,
    created_at DATETIME NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_user_equipment_exercise (user_id, equipment_id, exercise_slug),
    KEY ix_user_equipment_exercise_user (user_id),
    KEY ix_user_equipment_exercise_equipment (equipment_id),
    CONSTRAINT fk_user_equipment_exercise_user
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT fk_user_equipment_exercise_equipment
        FOREIGN KEY (equipment_id) REFERENCES equipment_library (id) ON DELETE CASCADE,
    CONSTRAINT fk_user_equipment_exercise_exercise
        FOREIGN KEY (exercise_slug) REFERENCES exercises (slug) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS user_universal_equipment (
    id VARCHAR(36) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    equipment_slug VARCHAR(40) NOT NULL,
    enabled TINYINT(1) NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_user_universal_equipment (user_id, equipment_slug),
    KEY ix_user_universal_equipment_user (user_id),
    CONSTRAINT fk_user_universal_equipment_user
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
