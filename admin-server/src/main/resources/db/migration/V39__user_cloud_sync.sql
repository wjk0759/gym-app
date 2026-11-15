-- Durable per-user settings and reusable food/exercise preferences.
CREATE TABLE user_preferences (
    user_id VARCHAR(36) NOT NULL,
    strict_equipment_mode BOOLEAN NOT NULL DEFAULT FALSE,
    use_remote_ai BOOLEAN NOT NULL DEFAULT TRUE,
    reminder_hour INT NOT NULL DEFAULT 19,
    reminder_minute INT NOT NULL DEFAULT 0,
    notifications_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    body_checkin_frequency VARCHAR(20) NOT NULL DEFAULT 'off',
    body_checkin_weekday INT NOT NULL DEFAULT 1,
    body_checkin_day INT NOT NULL DEFAULT 1,
    updated_at DATETIME NOT NULL,
    PRIMARY KEY (user_id),
    CONSTRAINT fk_user_preferences_user
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE user_custom_foods (
    id VARCHAR(36) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    client_id VARCHAR(36) NOT NULL,
    name VARCHAR(120) NOT NULL,
    category VARCHAR(40) NOT NULL DEFAULT '自定义',
    kcal DECIMAL(7,1) NOT NULL DEFAULT 0,
    protein DECIMAL(6,1) NOT NULL DEFAULT 0,
    carbs DECIMAL(6,1) NOT NULL DEFAULT 0,
    fat DECIMAL(6,1) NOT NULL DEFAULT 0,
    fiber DECIMAL(6,1) NULL,
    default_grams DECIMAL(7,1) NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    deleted_at DATETIME NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_custom_foods_user
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT uq_custom_foods_user_client UNIQUE (user_id, client_id),
    INDEX ix_custom_foods_user_updated (user_id, updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE user_food_favorites (
    id VARCHAR(36) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    food_key VARCHAR(160) NOT NULL,
    name VARCHAR(120) NOT NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    deleted_at DATETIME NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_food_favorites_user
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT uq_food_favorites_user_key UNIQUE (user_id, food_key),
    INDEX ix_food_favorites_user_updated (user_id, updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE user_exercise_dislikes (
    id VARCHAR(36) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    slug VARCHAR(60) NOT NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    deleted_at DATETIME NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_exercise_dislikes_user
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT uq_exercise_dislikes_user_slug UNIQUE (user_id, slug),
    INDEX ix_exercise_dislikes_user_updated (user_id, updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
