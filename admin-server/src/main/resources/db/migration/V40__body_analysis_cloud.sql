-- Cloud history for photo-based body analysis.
-- Photo bytes live outside the public /media mount; only metadata is stored.
CREATE TABLE body_analyses (
    id VARCHAR(36) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    client_id VARCHAR(36) NOT NULL,
    summary TEXT NOT NULL,
    focus_areas JSON NOT NULL,
    recommendations JSON NOT NULL,
    confidence FLOAT NULL,
    disclaimer TEXT NOT NULL,
    safety_flag VARCHAR(60) NULL,
    model VARCHAR(80) NULL,
    image_key VARCHAR(255) NULL,
    thumbnail_key VARCHAR(255) NULL,
    applied_to_plan BOOLEAN NOT NULL DEFAULT FALSE,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    deleted_at DATETIME NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_body_analyses_user
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT uq_body_analyses_user_client UNIQUE (user_id, client_id),
    INDEX ix_body_analyses_user_created (user_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
