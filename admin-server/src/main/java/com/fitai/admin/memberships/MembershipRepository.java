package com.fitai.admin.memberships;

import java.sql.Timestamp;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import com.fitai.admin.common.api.PageResponse;
import com.fitai.admin.common.persistence.SqlSupport;

@Repository
public class MembershipRepository {

    private static final String FROM = """
            FROM user_entitlements e
            JOIN users u ON u.id = e.user_id
            LEFT JOIN profiles p ON p.user_id = u.id
            """;

    private final JdbcClient jdbc;

    public MembershipRepository(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    public PageResponse<MembershipDtos.MembershipItem> list(
            String query,
            String source,
            String status,
            int page,
            int size
    ) {
        int safePage = SqlSupport.page(page);
        int safeSize = SqlSupport.size(size);
        Map<String, Object> params = new HashMap<>();
        String where = where(query, source, status, params);
        long total = jdbc.sql("SELECT COUNT(*) " + FROM + where)
                .params(params)
                .query(Long.class)
                .optional()
                .orElse(0L);
        List<MembershipDtos.MembershipItem> items = jdbc.sql("""
                SELECT e.id, e.user_id, e.plan_code, e.source, e.source_ref,
                       e.starts_at, e.expires_at, e.revoked_at, e.granted_by,
                       e.reason, e.created_at,
                       u.phone, u.username,
                       p.nickname,
                       COALESCE(NULLIF(p.nickname, ''), NULLIF(u.phone, ''),
                                NULLIF(u.username, ''), e.user_id) AS user_label
                """ + FROM + where + """
                ORDER BY e.expires_at DESC, e.created_at DESC
                LIMIT :limit OFFSET :offset
                """)
                .params(params)
                .param("limit", safeSize)
                .param("offset", SqlSupport.offset(safePage, safeSize))
                .query((rs, rowNum) -> {
                    Timestamp expires = rs.getTimestamp("expires_at");
                    Timestamp revoked = rs.getTimestamp("revoked_at");
                    return new MembershipDtos.MembershipItem(
                            rs.getString("id"),
                            rs.getString("user_id"),
                            rs.getString("user_label"),
                            rs.getString("phone"),
                            rs.getString("nickname"),
                            rs.getString("plan_code"),
                            rs.getString("source"),
                            rs.getString("source_ref"),
                            SqlSupport.iso(rs.getTimestamp("starts_at")),
                            SqlSupport.iso(expires),
                            SqlSupport.iso(revoked),
                            statusOf(expires, revoked),
                            daysLeft(expires, revoked),
                            rs.getString("granted_by"),
                            rs.getString("reason"),
                            SqlSupport.iso(rs.getTimestamp("created_at"))
                    );
                })
                .list();
        return PageResponse.of(items, safePage, safeSize, total);
    }

    public MembershipDtos.MembershipSummary summary() {
        long activeProUsers = count("""
                SELECT COUNT(DISTINCT e.user_id)
                FROM user_entitlements e
                WHERE e.plan_code = 'pro'
                  AND e.revoked_at IS NULL
                  AND e.starts_at <= UTC_TIMESTAMP()
                  AND e.expires_at > UTC_TIMESTAMP()
                """);
        long activeEntitlements = count("""
                SELECT COUNT(*)
                FROM user_entitlements e
                WHERE e.plan_code = 'pro'
                  AND e.revoked_at IS NULL
                  AND e.starts_at <= UTC_TIMESTAMP()
                  AND e.expires_at > UTC_TIMESTAMP()
                """);
        long expiring7d = count("""
                SELECT COUNT(DISTINCT e.user_id)
                FROM user_entitlements e
                WHERE e.plan_code = 'pro'
                  AND e.revoked_at IS NULL
                  AND e.starts_at <= UTC_TIMESTAMP()
                  AND e.expires_at > UTC_TIMESTAMP()
                  AND e.expires_at <= DATE_ADD(UTC_TIMESTAMP(), INTERVAL 7 DAY)
                """);
        long expiring30d = count("""
                SELECT COUNT(DISTINCT e.user_id)
                FROM user_entitlements e
                WHERE e.plan_code = 'pro'
                  AND e.revoked_at IS NULL
                  AND e.starts_at <= UTC_TIMESTAMP()
                  AND e.expires_at > UTC_TIMESTAMP()
                  AND e.expires_at <= DATE_ADD(UTC_TIMESTAMP(), INTERVAL 30 DAY)
                """);
        long newGrants7d = count("""
                SELECT COUNT(*)
                FROM user_entitlements e
                WHERE e.created_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 7 DAY)
                """);
        long revoked30d = count("""
                SELECT COUNT(*)
                FROM user_entitlements e
                WHERE e.revoked_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 30 DAY)
                """);
        List<MembershipDtos.SourceCount> sources = jdbc.sql("""
                SELECT e.source, COUNT(*) AS total
                FROM user_entitlements e
                WHERE e.plan_code = 'pro'
                  AND e.revoked_at IS NULL
                  AND e.starts_at <= UTC_TIMESTAMP()
                  AND e.expires_at > UTC_TIMESTAMP()
                GROUP BY e.source
                ORDER BY total DESC
                """)
                .query((rs, rowNum) -> new MembershipDtos.SourceCount(
                        rs.getString("source"),
                        rs.getLong("total")
                ))
                .list();
        return new MembershipDtos.MembershipSummary(
                activeProUsers, activeEntitlements, expiring7d, expiring30d,
                newGrants7d, revoked30d, sources
        );
    }

    private String where(String query, String source, String status, Map<String, Object> params) {
        List<String> clauses = new ArrayList<>();
        if (query != null && !query.isBlank()) {
            clauses.add("""
                    (e.user_id = :rawQuery
                     OR u.phone LIKE :prefix
                     OR u.username LIKE :prefix
                     OR p.nickname LIKE :prefix)
                    """);
            SqlSupport.putSearchParams(params, query);
        }
        if (source != null && !source.isBlank()) {
            clauses.add("e.source = :source");
            params.put("source", source);
        }
        if (status != null && !status.isBlank()) {
            switch (status) {
                case "active" -> clauses.add("""
                        e.revoked_at IS NULL
                        AND e.starts_at <= UTC_TIMESTAMP()
                        AND e.expires_at > UTC_TIMESTAMP()
                        """);
                case "expiring" -> clauses.add("""
                        e.revoked_at IS NULL
                        AND e.starts_at <= UTC_TIMESTAMP()
                        AND e.expires_at > UTC_TIMESTAMP()
                        AND e.expires_at <= DATE_ADD(UTC_TIMESTAMP(), INTERVAL 7 DAY)
                        """);
                case "expired" -> clauses.add("""
                        e.revoked_at IS NULL
                        AND e.expires_at <= UTC_TIMESTAMP()
                        """);
                case "revoked" -> clauses.add("e.revoked_at IS NOT NULL");
                default -> {
                }
            }
        }
        return clauses.isEmpty() ? " " : " WHERE " + String.join(" AND ", clauses);
    }

    private String statusOf(Timestamp expires, Timestamp revoked) {
        if (revoked != null) {
            return "revoked";
        }
        if (expires == null) {
            return "unknown";
        }
        Instant now = Instant.now();
        if (!expires.toInstant().isAfter(now)) {
            return "expired";
        }
        if (!expires.toInstant().isAfter(now.plus(Duration.ofDays(7)))) {
            return "expiring";
        }
        return "active";
    }

    private Long daysLeft(Timestamp expires, Timestamp revoked) {
        if (expires == null || revoked != null) {
            return null;
        }
        long days = Duration.between(Instant.now(), expires.toInstant()).toDays();
        return Math.max(0, days);
    }

    private long count(String sql) {
        return jdbc.sql(sql).query(Long.class).optional().orElse(0L);
    }
}
