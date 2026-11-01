-- Meal-plan provenance and week metadata.
-- One row per calendar day; week_start lets the read path query a week without
-- parsing the plan JSON or inferring the strategy from meals.

ALTER TABLE meal_plans
    ADD COLUMN week_start DATE NULL AFTER plan_date,
    ADD COLUMN strategy VARCHAR(30) NULL AFTER week_start,
    ADD COLUMN generated_by VARCHAR(20) NULL AFTER strategy,
    ADD COLUMN model_name VARCHAR(80) NULL AFTER generated_by,
    ADD COLUMN updated_at DATETIME NULL AFTER created_at;

UPDATE meal_plans
SET week_start = DATE_SUB(plan_date, INTERVAL WEEKDAY(plan_date) DAY)
WHERE week_start IS NULL;

UPDATE meal_plans
SET strategy = COALESCE(
        NULLIF(JSON_UNQUOTE(JSON_EXTRACT(plan, '$.strategy.id')), 'NULL'),
        'balanced'
    ),
    generated_by = COALESCE(
        NULLIF(JSON_UNQUOTE(JSON_EXTRACT(plan, '$.generated_by')), 'NULL'),
        'template'
    ),
    model_name = NULLIF(JSON_UNQUOTE(JSON_EXTRACT(plan, '$.model')), 'NULL')
WHERE strategy IS NULL OR generated_by IS NULL;

UPDATE meal_plans
SET updated_at = created_at
WHERE updated_at IS NULL;

ALTER TABLE meal_plans
    MODIFY week_start DATE NOT NULL,
    MODIFY strategy VARCHAR(30) NOT NULL DEFAULT 'balanced',
    MODIFY generated_by VARCHAR(20) NOT NULL DEFAULT 'template',
    MODIFY updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP;

CREATE INDEX ix_meal_plans_user_week ON meal_plans (user_id, week_start);
