-- Track the origin of a user's personal equipment/action entry so admins can
-- tell whether it was added manually or from a photo-recognition "not found".
ALTER TABLE equipment_library
    ADD COLUMN source VARCHAR(20) NOT NULL DEFAULT 'manual';
