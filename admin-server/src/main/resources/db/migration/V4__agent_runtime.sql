-- Agent runs, tool traces, and confirmable plan proposals.
-- The model can only write plans through an explicit proposal application later.

CREATE TABLE agent_runs (
    id VARCHAR(36) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    session_id VARCHAR(36),
    intent VARCHAR(40) NOT NULL,
    status VARCHAR(30) NOT NULL,
    model VARCHAR(80),
    input_text TEXT NOT NULL,
    output_text TEXT,
    step_count INTEGER NOT NULL DEFAULT 0,
    error TEXT,
    created_at DATETIME NOT NULL,
    completed_at DATETIME,
    PRIMARY KEY (id),
    FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE,
    FOREIGN KEY(session_id) REFERENCES chat_sessions (id) ON DELETE SET NULL,
    INDEX ix_agent_runs_user_created (user_id, created_at),
    INDEX ix_agent_runs_status_created (status, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE agent_steps (
    id VARCHAR(36) NOT NULL,
    run_id VARCHAR(36) NOT NULL,
    step_index INTEGER NOT NULL,
    step_type VARCHAR(30) NOT NULL,
    tool_name VARCHAR(40),
    input_json JSON NOT NULL,
    output_json JSON NOT NULL,
    status VARCHAR(20) NOT NULL,
    error TEXT,
    latency_ms INTEGER,
    created_at DATETIME NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_agent_steps_run_step (run_id, step_index),
    FOREIGN KEY(run_id) REFERENCES agent_runs (id) ON DELETE CASCADE,
    INDEX ix_agent_steps_run (run_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE agent_plan_proposals (
    id VARCHAR(36) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    run_id VARCHAR(36) NOT NULL,
    base_program_id VARCHAR(36),
    base_version INTEGER,
    status VARCHAR(20) NOT NULL,
    title VARCHAR(120) NOT NULL,
    plan_data JSON NOT NULL,
    diff_data JSON NOT NULL,
    validation_data JSON NOT NULL,
    created_at DATETIME NOT NULL,
    expires_at DATETIME NOT NULL,
    applied_at DATETIME,
    PRIMARY KEY (id),
    FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE,
    FOREIGN KEY(run_id) REFERENCES agent_runs (id) ON DELETE CASCADE,
    FOREIGN KEY(base_program_id) REFERENCES programs (id) ON DELETE SET NULL,
    INDEX ix_agent_plan_proposals_user_status (user_id, status, created_at),
    INDEX ix_agent_plan_proposals_run (run_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
