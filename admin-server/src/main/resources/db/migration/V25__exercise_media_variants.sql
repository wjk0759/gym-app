-- Exercise media variants: support multiple demo videos per exercise
-- (different models/visual styles), each with a stable variant key.
-- Phone shows all variants sorted by visual_priority; Watch downloads the
-- single primary (lowest visual_priority).

ALTER TABLE exercise_media_assets
    ADD COLUMN variant_key      VARCHAR(80) NULL AFTER sex,
    ADD COLUMN source_pack      VARCHAR(20) NULL AFTER variant_key,
    ADD COLUMN visual_style     VARCHAR(30) NULL AFTER source_pack,
    ADD COLUMN visual_priority  INT NOT NULL DEFAULT 1 AFTER visual_style;

-- Backfill legacy rows so the new unique key is well-defined.
UPDATE exercise_media_assets
   SET variant_key = CONCAT(exercise_slug, '-', sex)
 WHERE variant_key IS NULL OR variant_key = '';

-- Replace the (exercise_slug, sex, version) unique key with
-- (exercise_slug, variant_key, version). MySQL treats NULL variant_key as
-- distinct, so legacy rows without a real variant key remain permissive.
ALTER TABLE exercise_media_assets
    DROP INDEX uq_exercise_media_variant,
    ADD UNIQUE KEY uq_exercise_media_variant (exercise_slug, variant_key, version);
