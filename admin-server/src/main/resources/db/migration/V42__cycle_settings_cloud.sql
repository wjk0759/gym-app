-- Simple cloud storage for cycle dates and training mode.
CREATE TABLE cycle_settings (
    user_id VARCHAR(36) NOT NULL,
    range_start DATE NULL,
    range_end DATE NULL,
    dates JSON NOT NULL,
    training_mode VARCHAR(20) NOT NULL DEFAULT 'light',
    updated_at DATETIME NOT NULL,
    PRIMARY KEY (user_id),
    CONSTRAINT fk_cycle_settings_user
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
