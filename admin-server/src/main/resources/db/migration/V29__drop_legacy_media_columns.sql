-- V29: drop legacy media columns superseded by the variant model.
-- `sex` and `source` are kept: sex is used by Watch media ranking; source is
-- still populated by the import pipeline.

DROP VIEW IF EXISTS equipment_library;

ALTER TABLE exercise_media_assets
    DROP COLUMN license_expires_at,
    DROP COLUMN purchase_ref;
