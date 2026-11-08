-- Operations role for the production data viewer: read-only application data,
-- plus the two writes needed by the first admin feature batch:
--   * action media management (video:write)
--   * Pro entitlement grant/revoke (user:entitlement:write)
-- It deliberately excludes user:write, exercise:write, plan:write and settings:manage.

INSERT INTO admin_roles (id, code, name, description)
VALUES (UUID(), 'CONTENT_OPERATOR', '内容运营', '只读数据，管理动作媒体与 Pro 权益')
ON DUPLICATE KEY UPDATE name = VALUES(name), description = VALUES(description);

INSERT IGNORE INTO admin_role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM admin_roles r
JOIN admin_permissions p
WHERE r.code = 'CONTENT_OPERATOR'
  AND (p.code LIKE '%:read' OR p.code IN ('video:write', 'user:entitlement:write'));
