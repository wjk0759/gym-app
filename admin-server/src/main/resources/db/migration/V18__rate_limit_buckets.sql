-- Distributed token buckets for expensive APIs. A row per
-- (feature, user) means every worker consumes from the same bucket; rows are
-- small and can be removed by a periodic cleanup of old `updated_at` values.
CREATE TABLE rate_limit_buckets (
    bucket_key   VARCHAR(120) NOT NULL,
    tokens_milli INT          NOT NULL,
    updated_at   DATETIME     NOT NULL,
    PRIMARY KEY (bucket_key),
    KEY ix_rate_limit_buckets_updated (updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
