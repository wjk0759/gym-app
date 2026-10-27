-- User-confirmed App action outcomes. Actions are generated in an AgentRun,
-- executed locally by iOS after explicit confirmation, then reported here for
-- audit and product analytics.

CREATE TABLE agent_action_events (
    id VARCHAR(36) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    run_id VARCHAR(36),
    action_id VARCHAR(64) NOT NULL,
    action_type VARCHAR(40) NOT NULL,
    status VARCHAR(20) NOT NULL,
    message TEXT,
    detail JSON NOT NULL,
    created_at DATETIME NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uq_agent_action_events_user_action UNIQUE (user_id, action_id),
    FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE,
    FOREIGN KEY(run_id) REFERENCES agent_runs (id) ON DELETE SET NULL,
    INDEX ix_agent_action_events_user_created (user_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
