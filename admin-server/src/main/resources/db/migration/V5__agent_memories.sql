-- Durable, deduplicated coach memories. Existing ai_memories rows remain valid.
ALTER TABLE ai_memories
    ADD COLUMN memory_key VARCHAR(80) NOT NULL DEFAULT 'general',
    ADD COLUMN source VARCHAR(40) NOT NULL DEFAULT 'agent',
    ADD COLUMN confidence FLOAT NOT NULL DEFAULT 1.0,
    ADD COLUMN active BOOLEAN NOT NULL DEFAULT TRUE,
    ADD COLUMN updated_at DATETIME,
    ADD COLUMN last_used_at DATETIME;

CREATE INDEX ix_ai_memories_user_active_updated
    ON ai_memories(user_id, active, updated_at);

CREATE INDEX ix_ai_memories_memory_key
    ON ai_memories(memory_key);
