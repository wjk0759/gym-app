-- Server-owned coach session state, action ledger and event loop.
CREATE TABLE coach_sessions (
    id VARCHAR(36) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'idle',
    active_topic VARCHAR(40) NULL,
    pending_id VARCHAR(36) NULL,
    last_turn_at DATETIME NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_coach_sessions_user
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    INDEX ix_coach_sessions_user_status (user_id, status, updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE coach_turns (
    id VARCHAR(36) NOT NULL,
    session_id VARCHAR(36) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    input_text TEXT NOT NULL,
    intent VARCHAR(40) NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'completed',
    reply TEXT NULL,
    error TEXT NULL,
    latency_ms INT NULL,
    created_at DATETIME NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_coach_turns_session
        FOREIGN KEY (session_id) REFERENCES coach_sessions (id) ON DELETE CASCADE,
    CONSTRAINT fk_coach_turns_user
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    INDEX ix_coach_turns_session_created (session_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE coach_pending (
    id VARCHAR(36) NOT NULL,
    session_id VARCHAR(36) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    kind VARCHAR(20) NOT NULL,
    capability_id VARCHAR(60) NOT NULL,
    payload JSON NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    action_id VARCHAR(64) NULL,
    expires_at DATETIME NOT NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_coach_pending_session
        FOREIGN KEY (session_id) REFERENCES coach_sessions (id) ON DELETE CASCADE,
    CONSTRAINT fk_coach_pending_user
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    INDEX ix_coach_pending_session_status (session_id, status),
    INDEX ix_coach_pending_expires (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE coach_actions (
    id VARCHAR(36) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    session_id VARCHAR(36) NULL,
    capability_id VARCHAR(60) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'executed',
    payload JSON NOT NULL,
    before JSON NOT NULL,
    after JSON NOT NULL,
    receipt JSON NOT NULL,
    undo_token VARCHAR(64) NULL,
    idempotency_key VARCHAR(64) NOT NULL,
    error TEXT NULL,
    created_at DATETIME NOT NULL,
    executed_at DATETIME NULL,
    undone_at DATETIME NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_coach_actions_user
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT fk_coach_actions_session
        FOREIGN KEY (session_id) REFERENCES coach_sessions (id) ON DELETE SET NULL,
    CONSTRAINT uq_coach_actions_user_idempotency UNIQUE (user_id, idempotency_key),
    INDEX ix_coach_actions_user_created (user_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE domain_events (
    id VARCHAR(36) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    type VARCHAR(60) NOT NULL,
    entity_type VARCHAR(40) NULL,
    entity_id VARCHAR(64) NULL,
    payload JSON NOT NULL,
    occurred_at DATETIME NOT NULL,
    consumed_at DATETIME NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_domain_events_user
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    INDEX ix_domain_events_user_created (user_id, occurred_at),
    INDEX ix_domain_events_type_consumed (type, consumed_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE coach_inbox (
    id VARCHAR(36) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    kind VARCHAR(30) NOT NULL,
    title VARCHAR(120) NOT NULL,
    body TEXT NOT NULL,
    capability_id VARCHAR(60) NULL,
    payload JSON NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'unread',
    created_at DATETIME NOT NULL,
    read_at DATETIME NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_coach_inbox_user
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    INDEX ix_coach_inbox_user_status (user_id, status, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
