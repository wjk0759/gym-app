-- Photo/video analysis needs a much shorter cooldown than plans. Store the
-- per-row cooldown so plan rows keep 60s while vision rows can use 5s.
ALTER TABLE feature_generation_state
    ADD COLUMN cooldown_seconds INT NOT NULL DEFAULT 60 AFTER state;
