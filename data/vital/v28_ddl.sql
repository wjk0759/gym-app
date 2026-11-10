-- V28: exercise taxonomy + equipment catalog normalized into the database.
--
-- 分类 / 动作 / 器械的关系:
--   exercises.{training_type_code, body_part_code, muscle_primary_code,
--              muscle_secondary_codes, movement_pattern_code} -> taxonomy_terms.code
--   equipment_types (95) -> equipment_type_exercises -> exercises
--   user_equipment (renamed from equipment_library) -> user_equipment_exercise

CREATE TABLE IF NOT EXISTS taxonomy_terms (
    id VARCHAR(36) NOT NULL,
    dimension VARCHAR(30) NOT NULL,
    code VARCHAR(40) NOT NULL,
    name_zh VARCHAR(40) NOT NULL,
    parent_code VARCHAR(40) NULL,
    sort_order INT NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    UNIQUE KEY uq_taxonomy_terms (dimension, code),
    KEY ix_taxonomy_terms_dimension (dimension)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS equipment_types (
    id VARCHAR(36) NOT NULL,
    slug VARCHAR(60) NOT NULL,
    name_zh VARCHAR(60) NOT NULL,
    name_en VARCHAR(120) NULL,
    category VARCHAR(20) NOT NULL,
    exercise_group VARCHAR(40) NOT NULL,
    universal TINYINT(1) NOT NULL DEFAULT 0,
    aliases JSON NULL,
    recognition_class INT NULL,
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_equipment_types_slug (slug),
    KEY ix_equipment_types_category (category),
    KEY ix_equipment_types_group (exercise_group)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS equipment_type_exercises (
    equipment_type_slug VARCHAR(60) NOT NULL,
    exercise_slug VARCHAR(60) NOT NULL,
    is_primary TINYINT(1) NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (equipment_type_slug, exercise_slug),
    KEY ix_equipment_type_exercises_exercise (exercise_slug),
    CONSTRAINT fk_ete_type FOREIGN KEY (equipment_type_slug)
        REFERENCES equipment_types (slug) ON DELETE CASCADE,
    CONSTRAINT fk_ete_exercise FOREIGN KEY (exercise_slug)
        REFERENCES exercises (slug) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE exercises
    ADD COLUMN training_type_code VARCHAR(20) NULL AFTER muscle_group,
    ADD COLUMN body_part_code VARCHAR(20) NULL AFTER training_type_code,
    ADD COLUMN muscle_primary_code VARCHAR(30) NULL AFTER body_part_code,
    ADD COLUMN muscle_secondary_codes JSON NULL AFTER muscle_primary_code,
    ADD COLUMN movement_pattern_code VARCHAR(20) NULL AFTER muscle_secondary_codes,
    ADD COLUMN plan_eligible TINYINT(1) NOT NULL DEFAULT 1 AFTER movement_pattern_code,
    ADD COLUMN content_version VARCHAR(20) NULL AFTER plan_eligible,
    ADD KEY ix_exercises_training_type (training_type_code),
    ADD KEY ix_exercises_body_part (body_part_code),
    ADD KEY ix_exercises_plan_eligible (plan_eligible);

DROP TABLE IF EXISTS exercise_videos;

DELETE FROM equipment_library WHERE equipment_type IS NULL AND category IS NULL;

RENAME TABLE equipment_library TO user_equipment;

