-- Cross-device schedule state. plan_id/day_id are local-plan UUIDs, not
-- foreign keys, so offline/local plans can sync safely.
CREATE TABLE plan_day_states (
    id VARCHAR(36) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    plan_id VARCHAR(36) NOT NULL,
    day_id VARCHAR(36) NOT NULL,
    plan_version INTEGER,
    assigned_date DATE,
    skipped_at DATETIME,
    client_updated_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    created_at DATETIME NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uq_plan_day_states_user_plan_day UNIQUE (user_id, plan_id, day_id),
    FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE,
    INDEX ix_plan_day_states_user_plan (user_id, plan_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
