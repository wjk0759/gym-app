-- Server-owned coach cards waiting for confirmation. Persisting the card lets
-- a second device restore the same pending action and lets the backend apply
-- corrections without relying on client-provided app_context.
CREATE TABLE agent_pending_actions (
    id VARCHAR(36) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    session_id VARCHAR(36) NOT NULL,
    run_id VARCHAR(36) NULL,
    actions JSON NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    expires_at DATETIME NOT NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_agent_pending_actions_user
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT fk_agent_pending_actions_session
        FOREIGN KEY (session_id) REFERENCES chat_sessions (id) ON DELETE CASCADE,
    CONSTRAINT fk_agent_pending_actions_run
        FOREIGN KEY (run_id) REFERENCES agent_runs (id) ON DELETE SET NULL,
    INDEX ix_agent_pending_actions_user_status (user_id, status, updated_at),
    INDEX ix_agent_pending_actions_session_status (session_id, status),
    INDEX ix_agent_pending_actions_expires (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
