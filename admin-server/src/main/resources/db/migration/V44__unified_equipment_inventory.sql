-- Unified equipment availability: category declarations + precise inventory.
CREATE TABLE user_equipment_entries (
    id VARCHAR(36) NOT NULL,
    user_id VARCHAR(36) NOT NULL,
    client_id VARCHAR(80) NOT NULL,
    level VARCHAR(20) NOT NULL DEFAULT 'item',
    equipment_type VARCHAR(30) NOT NULL,
    name VARCHAR(120) NOT NULL DEFAULT '',
    source VARCHAR(20) NOT NULL DEFAULT 'manual',
    enabled TINYINT(1) NOT NULL DEFAULT 1,
    metadata_json JSON NOT NULL,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL,
    deleted_at DATETIME NULL,
    PRIMARY KEY (id),
    CONSTRAINT uq_equipment_entries_user_client UNIQUE (user_id, client_id),
    CONSTRAINT fk_equipment_entries_user
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    INDEX ix_equipment_entries_user_level (user_id, level, enabled)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Backfill declared profile categories.
INSERT INTO user_equipment_entries (
    id, user_id, client_id, level, equipment_type, name, source,
    enabled, metadata_json, created_at, updated_at, deleted_at
)
SELECT
    UUID(),
    p.user_id,
    CONCAT('profile:', jt.equipment_type),
    'category',
    jt.equipment_type,
    jt.equipment_type,
    'profile',
    1,
    JSON_OBJECT(),
    NOW(),
    NOW(),
    NULL
FROM profiles p
JOIN JSON_TABLE(
    CASE
        WHEN JSON_VALID(p.equipment) THEN p.equipment
        ELSE JSON_ARRAY()
    END,
    '$[*]' COLUMNS (equipment_type VARCHAR(30) PATH '$')
) AS jt
WHERE jt.equipment_type IS NOT NULL
ON DUPLICATE KEY UPDATE
    level = VALUES(level),
    equipment_type = VALUES(equipment_type),
    enabled = 1,
    deleted_at = NULL,
    updated_at = NOW();

-- Backfill enabled universal equipment.
INSERT INTO user_equipment_entries (
    id, user_id, client_id, level, equipment_type, name, source,
    enabled, metadata_json, created_at, updated_at, deleted_at
)
SELECT
    UUID(),
    u.user_id,
    CONCAT('universal:', u.equipment_slug),
    'category',
    CASE u.equipment_slug
        WHEN 'bodyweight' THEN 'bodyweight'
        WHEN 'dumbbell' THEN 'dumbbell'
        WHEN 'barbell' THEN 'barbell'
        WHEN 'kettlebell' THEN 'kettlebell'
        WHEN 'band' THEN 'band'
        WHEN 'pullup' THEN 'bodyweight'
        WHEN 'dip' THEN 'bodyweight'
        ELSE 'other'
    END,
    u.equipment_slug,
    'universal',
    1,
    JSON_OBJECT(),
    NOW(),
    NOW(),
    NULL
FROM user_universal_equipment u
WHERE u.enabled = 1
ON DUPLICATE KEY UPDATE
    level = VALUES(level),
    equipment_type = VALUES(equipment_type),
    enabled = 1,
    deleted_at = NULL,
    updated_at = NOW();

-- Backfill precise library items.
INSERT INTO user_equipment_entries (
    id, user_id, client_id, level, equipment_type, name, source,
    enabled, metadata_json, created_at, updated_at, deleted_at
)
SELECT
    UUID(),
    e.user_id,
    e.client_id,
    'item',
    COALESCE(
        NULLIF(e.equipment, ''),
        CASE e.category
            WHEN 'machine' THEN 'machine'
            WHEN 'multi' THEN 'machine'
            WHEN 'cable' THEN 'cable'
            WHEN 'cardio' THEN 'bodyweight'
            WHEN 'bodyweight' THEN 'bodyweight'
            WHEN 'accessory' THEN 'other'
            ELSE NULL
        END,
        CASE e.equipment_type
            WHEN 'dumbbell' THEN 'dumbbell'
            WHEN 'barbell' THEN 'barbell'
            WHEN 'kettlebell' THEN 'kettlebell'
            WHEN 'band' THEN 'band'
            WHEN 'bodyweight' THEN 'bodyweight'
            ELSE NULL
        END,
        'other'
    ),
    e.name,
    'library',
    1,
    JSON_OBJECT(
        'category', e.category,
        'slug', e.slug,
        'muscle', e.muscle,
        'photo_url', e.photo_url,
        'notes', e.notes
    ),
    e.created_at,
    e.updated_at,
    NULL
FROM user_equipment e
ON DUPLICATE KEY UPDATE
    level = VALUES(level),
    equipment_type = VALUES(equipment_type),
    name = VALUES(name),
    enabled = 1,
    deleted_at = NULL,
    updated_at = NOW();
