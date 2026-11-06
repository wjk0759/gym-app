-- Apple Watch standalone training.
-- Entitlements stay in user_entitlements; media files live in object storage.

ALTER TABLE auth_sessions
    ADD COLUMN client_type VARCHAR(20) NOT NULL DEFAULT 'ios' AFTER device_id;

ALTER TABLE workout_sessions
    ADD COLUMN source VARCHAR(20) NOT NULL DEFAULT 'phone' AFTER program_day_id,
    ADD COLUMN healthkit_workout_id VARCHAR(64) NULL AFTER source,
    ADD COLUMN revision INT NOT NULL DEFAULT 1 AFTER healthkit_workout_id;

CREATE TABLE exercise_media_assets (
    id                 VARCHAR(36)  NOT NULL,
    exercise_slug      VARCHAR(60)  NOT NULL,
    sex                VARCHAR(10)  NOT NULL DEFAULT 'unisex',
    source             VARCHAR(40)  NOT NULL,
    phone_url          TEXT         NOT NULL,
    watch_url          TEXT         NOT NULL,
    poster_url         TEXT         NULL,
    duration_seconds   INT          NULL,
    loop_start_ms      INT          NULL,
    loop_end_ms        INT          NULL,
    watch_sha256       CHAR(64)     NULL,
    version            INT          NOT NULL DEFAULT 1,
    status             VARCHAR(20)  NOT NULL DEFAULT 'draft',
    license_note       VARCHAR(200) NULL,
    license_expires_at DATE         NULL,
    purchase_ref       VARCHAR(120) NULL,
    created_at         DATETIME     NOT NULL,
    updated_at         DATETIME     NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_exercise_media_variant (exercise_slug, sex, version),
    KEY ix_exercise_media_slug_status (exercise_slug, status),
    CONSTRAINT fk_exercise_media_exercise
        FOREIGN KEY (exercise_slug) REFERENCES exercises (slug) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
