-- Sliding sessions: keep a short grace window for the previous refresh token
-- so a lost response does not force a user to log in again.

ALTER TABLE auth_sessions
    ADD COLUMN last_touched_at DATETIME NULL,
    ADD COLUMN previous_refresh_token_hash VARCHAR(128) NULL,
    ADD COLUMN previous_hash_valid_until DATETIME NULL;
