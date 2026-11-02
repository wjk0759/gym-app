-- Pro entitlements, one-time feature trials and metered weekly usage.
-- All timestamps are stored in UTC; business periods use Asia/Shanghai in code.

ALTER TABLE users
    ADD COLUMN is_test TINYINT(1) NOT NULL DEFAULT 0;

CREATE TABLE user_entitlements (
    id           VARCHAR(36)  NOT NULL,
    user_id      VARCHAR(36)  NOT NULL,
    plan_code    VARCHAR(20)  NOT NULL DEFAULT 'pro',
    source       VARCHAR(20)  NOT NULL,
    source_ref   VARCHAR(128) NULL,
    starts_at    DATETIME     NOT NULL,
    expires_at   DATETIME     NOT NULL,
    revoked_at   DATETIME     NULL,
    granted_by   VARCHAR(36)  NULL,
    reason       VARCHAR(200) NULL,
    metadata     JSON         NULL,
    created_at   DATETIME     NOT NULL,
    updated_at   DATETIME     NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_user_entitlements_source_ref (source, source_ref),
    KEY ix_user_entitlements_user_expiry (user_id, expires_at),
    CONSTRAINT fk_user_entitlements_user
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT fk_user_entitlements_admin
        FOREIGN KEY (granted_by) REFERENCES admin_users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE feature_trials (
    user_id      VARCHAR(36) NOT NULL,
    feature_key  VARCHAR(40) NOT NULL,
    source       VARCHAR(20) NOT NULL,
    used_at      DATETIME    NOT NULL,
    valid_until  DATETIME    NULL,
    result_ref   VARCHAR(80) NULL,
    created_at   DATETIME    NOT NULL,
    PRIMARY KEY (user_id, feature_key),
    CONSTRAINT fk_feature_trials_user
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE feature_usage (
    user_id      VARCHAR(36) NOT NULL,
    feature_key  VARCHAR(40) NOT NULL,
    period_start DATE        NOT NULL,
    used_count   INT         NOT NULL DEFAULT 0,
    updated_at   DATETIME    NOT NULL,
    PRIMARY KEY (user_id, feature_key, period_start),
    CONSTRAINT fk_feature_usage_user
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Existing accounts already received their onboarding training plan. Mark the
-- one-time trial as used so the new access rules cannot grant a second plan.
INSERT IGNORE INTO feature_trials
    (user_id, feature_key, source, used_at, valid_until, result_ref, created_at)
SELECT
    p.user_id,
    'training_plan',
    'onboarding',
    COALESCE(p.onboarded_at, NOW()),
    NULL,
    NULL,
    NOW()
FROM profiles p
WHERE p.onboarded_at IS NOT NULL;

-- A saved week also proves the account already used its one free meal plan.
INSERT IGNORE INTO feature_trials
    (user_id, feature_key, source, used_at, valid_until, result_ref, created_at)
SELECT
    m.user_id,
    'meal_plan',
    'first_generation',
    MIN(m.created_at),
    NULL,
    NULL,
    NOW()
FROM meal_plans m
GROUP BY m.user_id;

INSERT INTO admin_permissions (id, code, name)
VALUES (UUID(), 'user:entitlement:write', '管理用户会员权益')
ON DUPLICATE KEY UPDATE name = VALUES(name);

INSERT IGNORE INTO admin_role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM admin_roles r
JOIN admin_permissions p ON p.code = 'user:entitlement:write'
WHERE r.code IN ('SUPER_ADMIN', 'OPERATOR');


