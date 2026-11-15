-- One active in-progress workout per user for cross-device recovery.
CREATE TABLE workout_drafts (
    user_id VARCHAR(36) NOT NULL,
    day_id VARCHAR(36) NOT NULL,
    payload JSON NOT NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    PRIMARY KEY (user_id),
    CONSTRAINT fk_workout_drafts_user
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
