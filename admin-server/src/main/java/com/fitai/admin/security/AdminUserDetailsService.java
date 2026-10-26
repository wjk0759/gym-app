package com.fitai.admin.security;

import java.util.List;
import java.util.Map;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;

@Service
public class AdminUserDetailsService implements UserDetailsService {

    private final JdbcClient jdbc;

    public AdminUserDetailsService(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    @Override
    public UserDetails loadUserByUsername(String username) throws UsernameNotFoundException {
        return findByUsername(username)
                .orElseThrow(() -> new UsernameNotFoundException("管理员不存在"));
    }

    public java.util.Optional<AdminPrincipal> findByUsername(String username) {
        if (username == null || username.isBlank()) {
            return java.util.Optional.empty();
        }
        return load("username = :value", username);
    }

    public java.util.Optional<AdminPrincipal> findById(String id) {
        return load("id = :value", id);
    }

    private java.util.Optional<AdminPrincipal> load(String condition, String value) {
        List<Map<String, Object>> rows = jdbc.sql("""
                SELECT id, username, display_name, password_hash, status
                FROM admin_users
                WHERE %s
                LIMIT 1
                """.formatted(condition))
                .param("value", value)
                .query()
                .listOfRows();
        if (rows.isEmpty()) {
            return java.util.Optional.empty();
        }
        Map<String, Object> row = rows.getFirst();
        String id = String.valueOf(row.get("id"));
        String username = String.valueOf(row.get("username"));
        List<String> roles = jdbc.sql("""
                SELECT r.code
                FROM admin_roles r
                JOIN admin_user_roles ur ON ur.role_id = r.id
                WHERE ur.admin_user_id = :id
                ORDER BY r.code
                """).param("id", id).query(String.class).list();
        List<String> permissions = jdbc.sql("""
                SELECT DISTINCT p.code
                FROM admin_permissions p
                JOIN admin_role_permissions rp ON rp.permission_id = p.id
                JOIN admin_user_roles ur ON ur.role_id = rp.role_id
                WHERE ur.admin_user_id = :id
                ORDER BY p.code
                """).param("id", id).query(String.class).list();
        return java.util.Optional.of(new AdminPrincipal(
                id,
                username,
                asString(row.get("display_name")),
                asString(row.get("password_hash")),
                asString(row.get("status")),
                roles,
                permissions
        ));
    }

    private String asString(Object value) {
        return value == null ? "" : value.toString();
    }
}
