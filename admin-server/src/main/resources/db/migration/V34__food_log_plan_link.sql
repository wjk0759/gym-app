-- Link a food log to a planned meal so "record this meal" is traceable without
-- making the meal plan a hard foreign key. Plans can be regenerated; the log of
-- what the user actually ate must survive.
ALTER TABLE food_logs
    ADD COLUMN plan_date DATE NULL,
    ADD COLUMN plan_meal VARCHAR(20) NULL,
    ADD INDEX ix_food_logs_user_plan (user_id, plan_date);
