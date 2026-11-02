-- Bind sliding sessions to the installation that created them.
ALTER TABLE auth_sessions
    ADD COLUMN device_id VARCHAR(64) NULL;
