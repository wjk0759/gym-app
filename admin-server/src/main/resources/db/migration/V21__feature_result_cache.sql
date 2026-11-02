-- Short-lived sanitized result cache for idempotent photo analysis retries.
-- Deliberately stores only the text/JSON result: never the uploaded image.
-- Rows are keyed by the client-provided Idempotency-Key and expire quickly so
-- body/meal data is not retained longer than needed.
CREATE TABLE feature_result_cache (
    user_id         VARCHAR(36) NOT NULL,
    feature_key     VARCHAR(40) NOT NULL,
    idempotency_key VARCHAR(64) NOT NULL,
    result          JSON        NOT NULL,
    expires_at      DATETIME    NOT NULL,
    created_at      DATETIME    NOT NULL,
    PRIMARY KEY (user_id, feature_key, idempotency_key),
    KEY ix_feature_result_cache_expires (expires_at),
    CONSTRAINT fk_feature_result_cache_user
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
