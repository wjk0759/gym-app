package com.fitai.admin.users;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.sql.Timestamp;
import java.util.List;
import java.util.Optional;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import com.fitai.admin.common.persistence.SqlSupport;

@Repository
public class UserAccessRepository {

    private static final ZoneOffset BUSINESS_OFFSET = ZoneOffset.ofHours(8);
    private static final int COACH_DAILY_LIMIT = 3;

    private final JdbcClient jdbc;

    public UserAccessRepository(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    public Optional<UserAccessDtos.UserAccess> access(String userId) {
        if (!exists(userId)) {
            return Optional.empty();
        }
        List<UserAccessDtos.EntitlementItem> entitlements = jdbc.sql("""
                SELECT id, plan_code, source, starts_at, expires_at, revoked_at,
                       granted_by, reason, created_at
                FROM user_entitlements
                WHERE user_id = :userId
                ORDER BY created_at DESC
                LIMIT 50
                """).param("userId", userId).query((rs, rowNum) ->
                new UserAccessDtos.EntitlementItem(
                        rs.getString("id"),
                        rs.getString("plan_code"),
                        rs.getString("source"),
                        SqlSupport.iso(rs.getTimestamp("starts_at")),
                        SqlSupport.iso(rs.getTimestamp("expires_at")),
                        SqlSupport.iso(rs.getTimestamp("revoked_at")),
                        rs.getString("granted_by"),
                        rs.getString("reason"),
                        SqlSupport.iso(rs.getTimestamp("created_at"))
                )).list();

        var active = jdbc.sql("""
                SELECT COUNT(*) FROM user_entitlements
                WHERE user_id = :userId
                  AND plan_code = 'pro'
                  AND revoked_at IS NULL
                  AND starts_at <= UTC_TIMESTAMP()
                  AND expires_at > UTC_TIMESTAMP()
                """).param("userId", userId).query(Long.class).optional().orElse(0L);
        boolean pro = active > 0;
        String proExpiresAt = jdbc.sql("""
                SELECT MAX(expires_at)
                FROM user_entitlements
                WHERE user_id = :userId
                  AND plan_code = 'pro'
                  AND revoked_at IS NULL
                  AND expires_at > UTC_TIMESTAMP()
                """).param("userId", userId)
                .query(Timestamp.class)
                .optional()
                .map(SqlSupport::iso)
                .orElse(null);
        List<String> sources = jdbc.sql("""
                SELECT DISTINCT source
                FROM user_entitlements
                WHERE user_id = :userId
                  AND plan_code = 'pro'
                  AND revoked_at IS NULL
                  AND starts_at <= UTC_TIMESTAMP()
                  AND expires_at > UTC_TIMESTAMP()
                ORDER BY source
                """).param("userId", userId).query(String.class).list();

        List<UserAccessDtos.TrialItem> trials = jdbc.sql("""
                SELECT feature_key, source, used_at, valid_until
                FROM feature_trials
                WHERE user_id = :userId
                ORDER BY used_at DESC
                """).param("userId", userId).query((rs, rowNum) ->
                new UserAccessDtos.TrialItem(
                        rs.getString("feature_key"),
                        rs.getString("source"),
                        SqlSupport.iso(rs.getTimestamp("used_at")),
                        SqlSupport.iso(rs.getTimestamp("valid_until"))
                )).list();

        LocalDate periodStart = LocalDate.now(BUSINESS_OFFSET);
        int used = jdbc.sql("""
                SELECT used_count FROM feature_usage
                WHERE user_id = :userId
                  AND feature_key = 'coach_ai'
                  AND period_start = :periodStart
                """)
                .param("userId", userId)
                .param("periodStart", periodStart)
                .query(Integer.class)
                .optional()
                .orElse(0);
        UserAccessDtos.CoachUsage coach = new UserAccessDtos.CoachUsage(
                COACH_DAILY_LIMIT,
                used,
                Math.max(0, COACH_DAILY_LIMIT - used),
                periodStart.toString(),
                periodStart.plusDays(1).toString()
        );

        return Optional.of(new UserAccessDtos.UserAccess(
                pro,
                proExpiresAt,
                sources,
                entitlements,
                trials,
                coach
        ));
    }

    public boolean exists(String userId) {
        return jdbc.sql("SELECT COUNT(*) FROM users WHERE id = :userId")
                .param("userId", userId)
                .query(Long.class)
                .optional()
                .orElse(0L) > 0;
    }

    public void grant(
            String userId,
            int durationDays,
            String reason,
            String adminId
    ) {
        Instant now = Instant.now();
        // Extend from the current active expiry so repeated grants add days
        // instead of shortening a longer membership.
        Timestamp activeExpiry = jdbc.sql("""
                SELECT MAX(expires_at)
                FROM user_entitlements
                WHERE user_id = :userId
                  AND plan_code = 'pro'
                  AND revoked_at IS NULL
                  AND starts_at <= UTC_TIMESTAMP()
                  AND expires_at > UTC_TIMESTAMP()
                """).param("userId", userId)
                .query(Timestamp.class)
                .optional()
                .orElse(null);
        Instant base = activeExpiry == null ? now : activeExpiry.toInstant();
        Timestamp startsAt = Timestamp.from(base);
        Timestamp expiresAt = Timestamp.from(base.plus(durationDays, ChronoUnit.DAYS));
        jdbc.sql("""
                INSERT INTO user_entitlements
                    (id, user_id, plan_code, source, source_ref, starts_at,
                     expires_at, granted_by, reason, created_at, updated_at)
                VALUES
                    (:id, :userId, 'pro', 'admin', :sourceRef, :startsAt,
                     :expiresAt, :adminId, :reason, :startsAt, :startsAt)
                """)
                .param("id", java.util.UUID.randomUUID().toString())
                .param("userId", userId)
                .param("sourceRef", "admin-" + java.util.UUID.randomUUID())
                .param("startsAt", startsAt)
                .param("expiresAt", expiresAt)
                .param("adminId", adminId)
                .param("reason", reason)
                .update();
    }

    public boolean revoke(String userId, String entitlementId, String reason) {
        return jdbc.sql("""
                UPDATE user_entitlements
                SET revoked_at = UTC_TIMESTAMP(), updated_at = UTC_TIMESTAMP(),
                    reason = COALESCE(reason, :reason)
                WHERE id = :id AND user_id = :userId AND revoked_at IS NULL
                """)
                .param("id", entitlementId)
                .param("userId", userId)
                .param("reason", reason)
                .update() > 0;
    }

    public boolean resetTrial(String userId, String featureKey) {
        return jdbc.sql("""
                DELETE FROM feature_trials
                WHERE user_id = :userId AND feature_key = :featureKey
                """)
                .param("userId", userId)
                .param("featureKey", featureKey)
                .update() > 0;
    }
}
