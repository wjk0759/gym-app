package com.fitai.admin.security;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.Optional;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

@Repository
public class AdminAccountRepository {

    private final JdbcClient jdbc;

    public AdminAccountRepository(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    public boolean hasUsers() {
        Long count = jdbc.sql("SELECT COUNT(*) FROM admin_users").query(Long.class).single();
        return count != null && count > 0;
    }

    public Optional<AdminAccountRow> findByUsername(String username) {
        return jdbc.sql("""
                SELECT id, username, password_hash, display_name, status
                FROM admin_users
                WHERE username = :username
                LIMIT 1
                """)
                .param("username", username)
                .query((rs, rowNum) -> new AdminAccountRow(
                        rs.getString("id"),
                        rs.getString("username"),
                        rs.getString("password_hash"),
                        rs.getString("display_name"),
                        rs.getString("status")
                ))
                .optional();
    }

    public Optional<AdminAccountRow> findById(String id) {
        return jdbc.sql("""
                SELECT id, username, password_hash, display_name, status
                FROM admin_users
                WHERE id = :id
                LIMIT 1
                """)
                .param("id", id)
                .query((rs, rowNum) -> new AdminAccountRow(
                        rs.getString("id"),
                        rs.getString("username"),
                        rs.getString("password_hash"),
                        rs.getString("display_name"),
                        rs.getString("status")
                ))
                .optional();
    }

    public void touchLogin(String id) {
        jdbc.sql("UPDATE admin_users SET last_login_at = :now, updated_at = :now WHERE id = :id")
                .param("now", Timestamp.from(Instant.now()))
                .param("id", id)
                .update();
    }

    public void updatePassword(String id, String passwordHash) {
        jdbc.sql("UPDATE admin_users SET password_hash = :hash, updated_at = :now WHERE id = :id")
                .param("hash", passwordHash)
                .param("now", Timestamp.from(Instant.now()))
                .param("id", id)
                .update();
    }

    public void insertAdminUser(String id, String username, String passwordHash, String displayName) {
        Timestamp now = Timestamp.from(Instant.now());
        jdbc.sql("""
                INSERT INTO admin_users
                    (id, username, password_hash, display_name, status, created_at, updated_at)
                VALUES
                    (:id, :username, :passwordHash, :displayName, 'active', :now, :now)
                """)
                .param("id", id)
                .param("username", username)
                .param("passwordHash", passwordHash)
                .param("displayName", displayName)
                .param("now", now)
                .update();
    }

    public Optional<String> roleIdByCode(String code) {
        return jdbc.sql("SELECT id FROM admin_roles WHERE code = :code LIMIT 1")
                .param("code", code)
                .query(String.class)
                .optional();
    }

    public void assignRole(String adminUserId, String roleId) {
        jdbc.sql("""
                INSERT IGNORE INTO admin_user_roles (admin_user_id, role_id)
                VALUES (:adminUserId, :roleId)
                """).param("adminUserId", adminUserId).param("roleId", roleId).update();
    }

    public void insertRefreshToken(
            String id,
            String adminUserId,
            String tokenHash,
            Instant expiresAt,
            String ipAddress,
            String userAgent
    ) {
        Timestamp now = Timestamp.from(Instant.now());
        jdbc.sql("""
                INSERT INTO admin_refresh_tokens
                    (id, admin_user_id, token_hash, expires_at, created_at, last_used_at, ip_address, user_agent)
                VALUES
                    (:id, :adminUserId, :tokenHash, :expiresAt, :now, :now, :ipAddress, :userAgent)
                """)
                .param("id", id)
                .param("adminUserId", adminUserId)
                .param("tokenHash", tokenHash)
                .param("expiresAt", Timestamp.from(expiresAt))
                .param("now", now)
                .param("ipAddress", ipAddress)
                .param("userAgent", userAgent)
                .update();
    }

    public Optional<RefreshTokenRow> findActiveRefreshToken(String tokenHash) {
        return jdbc.sql("""
                SELECT id, admin_user_id, expires_at, revoked_at
                FROM admin_refresh_tokens
                WHERE token_hash = :tokenHash
                  AND revoked_at IS NULL
                  AND expires_at > :now
                LIMIT 1
                """)
                .param("tokenHash", tokenHash)
                .param("now", Timestamp.from(Instant.now()))
                .query((rs, rowNum) -> new RefreshTokenRow(
                        rs.getString("id"),
                        rs.getString("admin_user_id"),
                        rs.getTimestamp("expires_at").toInstant(),
                        rs.getTimestamp("revoked_at") == null ? null : rs.getTimestamp("revoked_at").toInstant()
                ))
                .optional();
    }

    public boolean revokeRefreshToken(String id) {
        return jdbc.sql("""
                UPDATE admin_refresh_tokens
                SET revoked_at = :now, last_used_at = :now
                WHERE id = :id AND revoked_at IS NULL
                """)
                .param("now", Timestamp.from(Instant.now()))
                .param("id", id)
                .update() > 0;
    }

    public void revokeAllRefreshTokens(String adminUserId) {
        jdbc.sql("""
                UPDATE admin_refresh_tokens
                SET revoked_at = :now
                WHERE admin_user_id = :adminUserId AND revoked_at IS NULL
                """)
                .param("now", Timestamp.from(Instant.now()))
                .param("adminUserId", adminUserId)
                .update();
    }

    public List<AdminAccountRow> listAccounts() {
        return jdbc.sql("""
                SELECT id, username, password_hash, display_name, status
                FROM admin_users
                ORDER BY created_at DESC
                """)
                .query((rs, rowNum) -> new AdminAccountRow(
                        rs.getString("id"),
                        rs.getString("username"),
                        rs.getString("password_hash"),
                        rs.getString("display_name"),
                        rs.getString("status")
                ))
                .list();
    }

    public List<AdminAccountSummary> listSummaries() {
        return jdbc.sql("""
                SELECT id, username, display_name, status, last_login_at, created_at
                FROM admin_users
                ORDER BY created_at DESC
                """).query((rs, rowNum) -> new AdminAccountSummary(
                        rs.getString("id"),
                        rs.getString("username"),
                        rs.getString("display_name"),
                        rs.getString("status"),
                        rs.getTimestamp("last_login_at") == null ? null : rs.getTimestamp("last_login_at").toInstant(),
                        rs.getTimestamp("created_at").toInstant(),
                        rolesOf(rs.getString("id"))
                )).list();
    }

    public boolean existsUsername(String username) {
        return jdbc.sql("SELECT COUNT(*) FROM admin_users WHERE username = :username")
                .param("username", username).query(Long.class).optional().orElse(0L) > 0;
    }

    public void updateProfile(String id, String displayName, String status) {
        jdbc.sql("""
                UPDATE admin_users
                SET display_name = COALESCE(:displayName, display_name),
                    status = COALESCE(:status, status),
                    updated_at = :now
                WHERE id = :id
                """)
                .param("displayName", displayName)
                .param("status", status)
                .param("now", Timestamp.from(Instant.now()))
                .param("id", id)
                .update();
    }

    public void replaceRoles(String adminUserId, List<String> roleIds) {
        jdbc.sql("DELETE FROM admin_user_roles WHERE admin_user_id = :id")
                .param("id", adminUserId).update();
        for (String roleId : roleIds) {
            assignRole(adminUserId, roleId);
        }
    }

    public List<String> roleIdsByCodes(List<String> codes) {
        if (codes == null || codes.isEmpty()) {
            return List.of();
        }
        return jdbc.sql("SELECT id FROM admin_roles WHERE code IN (:codes)")
                .param("codes", codes)
                .query(String.class)
                .list();
    }

    public long countSuperAdmins() {
        return jdbc.sql("""
                SELECT COUNT(DISTINCT ur.admin_user_id)
                FROM admin_user_roles ur
                JOIN admin_roles r ON r.id = ur.role_id
                JOIN admin_users u ON u.id = ur.admin_user_id
                WHERE r.code = 'SUPER_ADMIN' AND u.status = 'active'
                """).query(Long.class).optional().orElse(0L);
    }

    public boolean isSuperAdmin(String adminUserId) {
        return jdbc.sql("""
                SELECT COUNT(*)
                FROM admin_user_roles ur
                JOIN admin_roles r ON r.id = ur.role_id
                WHERE ur.admin_user_id = :id AND r.code = 'SUPER_ADMIN'
                """).param("id", adminUserId).query(Long.class).optional().orElse(0L) > 0;
    }

    public List<AdminAccountDtos.RoleOption> roleOptions() {
        return jdbc.sql("SELECT code, name, description FROM admin_roles ORDER BY code")
                .query((rs, rowNum) -> new AdminAccountDtos.RoleOption(
                        rs.getString("code"),
                        rs.getString("name"),
                        rs.getString("description")
                )).list();
    }

    public void resetPassword(String id, String passwordHash) {
        jdbc.sql("""
                UPDATE admin_users
                SET password_hash = :hash, password_changed_at = :now, updated_at = :now
                WHERE id = :id
                """)
                .param("hash", passwordHash)
                .param("now", Timestamp.from(Instant.now()))
                .param("id", id)
                .update();
    }


    public List<String> rolesOf(String adminUserId) {
        return jdbc.sql("""
                SELECT r.code
                FROM admin_roles r
                JOIN admin_user_roles ur ON ur.role_id = r.id
                WHERE ur.admin_user_id = :id
                ORDER BY r.code
                """).param("id", adminUserId).query(String.class).list();
    }
}
