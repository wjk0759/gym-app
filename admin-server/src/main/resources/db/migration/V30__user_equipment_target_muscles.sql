-- Custom equipment must declare at least one detailed training target.
-- The client sends Chinese muscle labels from the curated taxonomy, e.g.
-- ["胸大肌", "下胸"]. Standard catalog equipment leaves this empty.
ALTER TABLE user_equipment
    ADD COLUMN target_muscles JSON NULL AFTER muscle;
