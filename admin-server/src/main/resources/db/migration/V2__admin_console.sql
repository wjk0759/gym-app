-- FitAI admin control plane: identity, RBAC and refresh sessions.
-- Application tables are defined in V1 because FastAPI and the admin server
-- share the same MySQL database during the migration period.

CREATE TABLE admin_users (
    id              VARCHAR(36)  NOT NULL,
    username        VARCHAR(64)  NOT NULL,
    password_hash   VARCHAR(100) NOT NULL,
    display_name    VARCHAR(80)  NOT NULL,
    status          VARCHAR(20)  NOT NULL DEFAULT 'active',
    last_login_at   DATETIME     NULL,
    password_changed_at DATETIME NULL,
    created_at      DATETIME     NOT NULL,
    updated_at      DATETIME     NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_admin_users_username (username),
    KEY ix_admin_users_status (status),
    CONSTRAINT ck_admin_users_status CHECK (status IN ('active', 'suspended', 'disabled'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE admin_roles (
    id          VARCHAR(36) NOT NULL,
    code        VARCHAR(40) NOT NULL,
    name        VARCHAR(80) NOT NULL,
    description VARCHAR(200) NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_admin_roles_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE admin_permissions (
    id          VARCHAR(36) NOT NULL,
    code        VARCHAR(80) NOT NULL,
    name        VARCHAR(120) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_admin_permissions_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE admin_user_roles (
    admin_user_id VARCHAR(36) NOT NULL,
    role_id       VARCHAR(36) NOT NULL,
    PRIMARY KEY (admin_user_id, role_id),
    CONSTRAINT fk_admin_user_roles_user FOREIGN KEY (admin_user_id) REFERENCES admin_users (id) ON DELETE CASCADE,
    CONSTRAINT fk_admin_user_roles_role FOREIGN KEY (role_id) REFERENCES admin_roles (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE admin_role_permissions (
    role_id       VARCHAR(36) NOT NULL,
    permission_id VARCHAR(36) NOT NULL,
    PRIMARY KEY (role_id, permission_id),
    CONSTRAINT fk_admin_role_permissions_role FOREIGN KEY (role_id) REFERENCES admin_roles (id) ON DELETE CASCADE,
    CONSTRAINT fk_admin_role_permissions_permission FOREIGN KEY (permission_id) REFERENCES admin_permissions (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE admin_refresh_tokens (
    id             VARCHAR(36) NOT NULL,
    admin_user_id  VARCHAR(36) NOT NULL,
    token_hash     CHAR(64)    NOT NULL,
    expires_at     DATETIME    NOT NULL,
    revoked_at     DATETIME    NULL,
    created_at     DATETIME    NOT NULL,
    last_used_at   DATETIME    NULL,
    ip_address     VARCHAR(64) NULL,
    user_agent     VARCHAR(255) NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_admin_refresh_token_hash (token_hash),
    KEY ix_admin_refresh_user (admin_user_id),
    KEY ix_admin_refresh_expiry (expires_at),
    CONSTRAINT fk_admin_refresh_user FOREIGN KEY (admin_user_id) REFERENCES admin_users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE INDEX ix_admin_audit_logs_created_at ON admin_audit_logs (created_at);

INSERT INTO admin_roles (id, code, name, description) VALUES
    (UUID(), 'SUPER_ADMIN', '超级管理员', '拥有全部后台权限'),
    (UUID(), 'OPERATOR', '运营管理员', '日常运营、内容与用户管理'),
    (UUID(), 'AUDITOR', '审计员', '只读与审计权限');

INSERT INTO admin_permissions (id, code, name) VALUES
    (UUID(), 'dashboard:read', '查看仪表盘'),
    (UUID(), 'user:read', '查看用户'),
    (UUID(), 'user:write', '管理用户'),
    (UUID(), 'plan:read', '查看训练计划'),
    (UUID(), 'plan:write', '管理训练计划'),
    (UUID(), 'workout:read', '查看训练记录'),
    (UUID(), 'workout:write', '管理训练记录'),
    (UUID(), 'chat:read', '查看教练对话'),
    (UUID(), 'chat:write', '管理教练对话'),
    (UUID(), 'scan:read', '查看器械识别'),
    (UUID(), 'scan:write', '管理器械识别'),
    (UUID(), 'exercise:read', '查看动作库'),
    (UUID(), 'exercise:write', '编辑动作库'),
    (UUID(), 'video:read', '查看教学视频'),
    (UUID(), 'video:write', '管理教学视频'),
    (UUID(), 'ai:read', '查看 AI 运行指标'),
    (UUID(), 'audit:read', '查看审计日志'),
    (UUID(), 'settings:manage', '管理后台账号与系统设置');

INSERT INTO admin_role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM admin_roles r CROSS JOIN admin_permissions p
WHERE r.code = 'SUPER_ADMIN';

INSERT INTO admin_role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM admin_roles r JOIN admin_permissions p
WHERE r.code = 'OPERATOR'
  AND p.code IN (
    'dashboard:read', 'user:read', 'user:write', 'plan:read', 'plan:write',
    'workout:read', 'workout:write', 'chat:read', 'chat:write', 'scan:read',
    'scan:write', 'exercise:read', 'exercise:write', 'video:read', 'video:write',
    'ai:read'
  );

INSERT INTO admin_role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM admin_roles r JOIN admin_permissions p
WHERE r.code = 'AUDITOR'
  AND p.code IN (
    'dashboard:read', 'user:read', 'plan:read', 'workout:read', 'chat:read',
    'scan:read', 'exercise:read', 'video:read', 'ai:read', 'audit:read'
  );
