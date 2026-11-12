-- User feedback on one assistant coach message. One row per user/message;
-- re-submitting updates the rating instead of creating duplicates.
CREATE TABLE coach_feedback (
    id VARCHAR(36) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    message_id VARCHAR(36) NOT NULL,
    run_id VARCHAR(36) NULL,
    rating VARCHAR(10) NOT NULL,
    reason VARCHAR(40) NULL,
    comment TEXT NULL,
    prompt_version VARCHAR(30) NULL,
    model VARCHAR(80) NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NULL,
    PRIMARY KEY (id),
    CONSTRAINT uq_coach_feedback_user_message UNIQUE (user_id, message_id),
    FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE,
    FOREIGN KEY(message_id) REFERENCES chat_messages (id) ON DELETE CASCADE,
    FOREIGN KEY(run_id) REFERENCES agent_runs (id) ON DELETE SET NULL,
    INDEX ix_coach_feedback_user_created (user_id, created_at),
    INDEX ix_coach_feedback_rating_created (rating, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
