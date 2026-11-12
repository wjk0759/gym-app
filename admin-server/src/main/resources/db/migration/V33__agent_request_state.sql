-- Durable idempotency and task state for /agent/chat. A client may retry the
-- same request_id after a timeout; the server must not call the model twice or
-- create two AgentRuns, even across workers or a restart.
CREATE TABLE agent_request_state (
    user_id VARCHAR(36) NOT NULL,
    request_id VARCHAR(64) NOT NULL,
    status VARCHAR(20) NOT NULL,
    run_id VARCHAR(36) NULL,
    response JSON NULL,
    error VARCHAR(500) NULL,
    attempts INT NOT NULL DEFAULT 1,
    expires_at DATETIME NOT NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    PRIMARY KEY (user_id, request_id),
    CONSTRAINT fk_agent_request_state_user
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT fk_agent_request_state_run
        FOREIGN KEY (run_id) REFERENCES agent_runs (id) ON DELETE SET NULL,
    INDEX ix_agent_request_state_expires (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
