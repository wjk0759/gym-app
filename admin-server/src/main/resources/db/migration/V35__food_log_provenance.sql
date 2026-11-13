-- Provenance for coach-authored food logs. `source_action_id` makes an
-- action idempotent and undoable; `source_group_id` groups all items in one
-- meal so the app can undo the entire entry.
ALTER TABLE food_logs
    ADD COLUMN source VARCHAR(20) NOT NULL DEFAULT 'manual',
    ADD COLUMN source_action_id VARCHAR(64) NULL,
    ADD COLUMN source_group_id VARCHAR(36) NULL,
    ADD COLUMN estimate_confidence FLOAT NULL,
    ADD INDEX ix_food_logs_source_action (user_id, source_action_id),
    ADD INDEX ix_food_logs_source_group (user_id, source_group_id);
