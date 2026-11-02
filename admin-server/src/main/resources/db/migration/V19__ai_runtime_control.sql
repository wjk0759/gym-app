-- Global AI runtime switch. When disabled, only users flagged as test accounts
-- may call the model provider; everything else falls back to templates. This is
-- an incident/cost control, not a per-feature entitlement.
CREATE TABLE ai_runtime_control (
    id         TINYINT      NOT NULL,
    enabled    TINYINT(1)   NOT NULL DEFAULT 1,
    reason     VARCHAR(200) NULL,
    updated_by VARCHAR(36)  NULL,
    updated_at DATETIME     NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT ck_ai_runtime_control_single CHECK (id = 1)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO ai_runtime_control (id, enabled, reason, updated_by, updated_at)
VALUES (1, 1, NULL, NULL, UTC_TIMESTAMP());

INSERT INTO admin_permissions (id, code, name)
VALUES (UUID(), 'ai:write', '管理 AI 运行开关');

INSERT INTO admin_role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM admin_roles r
JOIN admin_permissions p ON p.code = 'ai:write'
WHERE r.code = 'SUPER_ADMIN';
