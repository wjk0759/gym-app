-- Foods the user asked the coach to avoid in generated meal plans.
CREATE TABLE user_food_dislikes (
    id VARCHAR(36) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    food_key VARCHAR(160) NOT NULL,
    name VARCHAR(120) NOT NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    deleted_at DATETIME NULL,
    PRIMARY KEY (id),
    CONSTRAINT uq_food_dislikes_user_key UNIQUE (user_id, food_key),
    CONSTRAINT fk_food_dislikes_user
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    INDEX ix_food_dislikes_user_updated (user_id, updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
