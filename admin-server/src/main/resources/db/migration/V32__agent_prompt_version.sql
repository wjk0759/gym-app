-- Prompt version is derived from the exact system prompt hash at runtime.
-- Keep it next to the run so feedback and observability can group quality by
-- the prompt that produced the answer.
ALTER TABLE agent_runs
    ADD COLUMN prompt_version VARCHAR(30) NULL AFTER model;
