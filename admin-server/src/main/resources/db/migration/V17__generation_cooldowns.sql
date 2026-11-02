-- Durable generation guard. The API also rate-limits bursts in memory; this
-- table makes the cooldown, in-flight lock and idempotent replay survive a
-- restart or a second worker. `state` is `running` while the provider call is
-- in progress and `succeeded` after the result has been persisted.
CREATE TABLE feature_generation_state (
    user_id              VARCHAR(36) NOT NULL,
    feature_key          VARCHAR(40) NOT NULL,
    state                VARCHAR(12) NOT NULL DEFAULT 'running',
    last_generated_at    DATETIME    NOT NULL,
    last_result_ref      VARCHAR(80) NULL,
    last_idempotency_key VARCHAR(64) NULL,
    updated_at           DATETIME    NOT NULL,
    PRIMARY KEY (user_id, feature_key),
    CONSTRAINT fk_feature_generation_state_user
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
