-- Multi-turn coach action drafts. A short answer like "250ml" must update the
-- exact food item from the previous turn, not rely on truncated chat history.
CREATE TABLE agent_action_drafts (
    id VARCHAR(36) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    session_id VARCHAR(36) NOT NULL,
    draft_type VARCHAR(30) NOT NULL,
    payload JSON NOT NULL,
    missing_slots JSON NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'collecting',
    expires_at DATETIME NOT NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_agent_action_drafts_user
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT fk_agent_action_drafts_session
        FOREIGN KEY (session_id) REFERENCES chat_sessions (id) ON DELETE CASCADE,
    INDEX ix_agent_action_drafts_session_status (session_id, status),
    INDEX ix_agent_action_drafts_expires (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
