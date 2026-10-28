package com.fitai.admin.dashboard;

import java.sql.Date;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import com.fitai.admin.common.persistence.SqlSupport;

@Repository
public class DashboardRepository {

    private static final Map<String, String> GOAL_LABELS = Map.of(
            "lose_fat", "减脂",
            "build_muscle", "增肌",
            "recomp", "重塑",
            "endurance", "耐力"
    );

    private final JdbcClient jdbc;

    public DashboardRepository(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    public DashboardSummary load() {
        Totals totals = jdbc.sql("""
                SELECT
                    (SELECT COUNT(*) FROM users WHERE deleted_at IS NULL) AS users_total,
                    (SELECT COUNT(*) FROM users
                     WHERE deleted_at IS NULL
                       AND created_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 7 DAY)) AS users_new_7d,
                    (SELECT COUNT(*) FROM profiles WHERE onboarded_at IS NOT NULL) AS onboarded,
                    (SELECT COUNT(*) FROM (
                        SELECT user_id FROM workout_sessions
                        WHERE started_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 7 DAY)
                        UNION
                        SELECT user_id FROM chat_sessions
                        WHERE created_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 7 DAY)
                    ) active_users) AS active_7d,
                    (SELECT COUNT(*) FROM (
                        SELECT user_id FROM workout_sessions
                        WHERE started_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 30 DAY)
                        UNION
                        SELECT user_id FROM chat_sessions
                        WHERE created_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 30 DAY)
                    ) active_users) AS active_30d,
                    (SELECT COUNT(*) FROM workout_sessions) AS sessions_total,
                    (SELECT COUNT(*) FROM workout_sessions
                     WHERE started_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 7 DAY)) AS sessions_7d,
                    (SELECT COUNT(*) FROM programs WHERE status = 'active') AS programs_active,
                    (SELECT COUNT(*) FROM programs) AS programs_total,
                    (SELECT COUNT(*) FROM chat_sessions) AS chats_total,
                    (SELECT COUNT(*) FROM chat_messages) AS messages_total,
                    (SELECT COUNT(*) FROM chat_messages WHERE safety_flag IS NOT NULL) AS safety_flags,
                    (SELECT COUNT(*) FROM equipment_scans) AS scans_total,
                    (SELECT COUNT(*) FROM exercises) AS exercises_total,
                    (SELECT COUNT(*) FROM exercise_videos WHERE status = 'published') AS videos_published,
                    (SELECT COUNT(*) FROM meal_plans) AS meal_plans_total,
                    (SELECT COUNT(*) FROM ai_jobs WHERE status <> 'ok') AS ai_errors
                """).query((rs, rowNum) -> new Totals(
                rs.getLong("users_total"),
                rs.getLong("users_new_7d"),
                rs.getLong("onboarded"),
                rs.getLong("active_7d"),
                rs.getLong("active_30d"),
                rs.getLong("sessions_total"),
                rs.getLong("sessions_7d"),
                rs.getLong("programs_active"),
                rs.getLong("programs_total"),
                rs.getLong("chats_total"),
                rs.getLong("messages_total"),
                rs.getLong("safety_flags"),
                rs.getLong("scans_total"),
                rs.getLong("exercises_total"),
                rs.getLong("videos_published"),
                rs.getLong("meal_plans_total"),
                rs.getLong("ai_errors")
        )).list().getFirst();

        Map<LocalDate, Long> userDaily = dailyCounts("""
                SELECT DATE(created_at) AS day, COUNT(*) AS total
                FROM users
                WHERE deleted_at IS NULL AND created_at >= DATE_SUB(CURDATE(), INTERVAL 13 DAY)
                GROUP BY DATE(created_at)
                """);
        Map<LocalDate, Long> workoutDaily = dailyCounts("""
                SELECT DATE(started_at) AS day, COUNT(*) AS total
                FROM workout_sessions
                WHERE started_at >= DATE_SUB(CURDATE(), INTERVAL 13 DAY)
                GROUP BY DATE(started_at)
                """);
        LocalDate today = LocalDate.now(ZoneOffset.UTC);
        List<DashboardSummary.DailyPoint> daily = new ArrayList<>();
        for (int i = 13; i >= 0; i--) {
            LocalDate day = today.minusDays(i);
            daily.add(new DashboardSummary.DailyPoint(
                    day.toString(),
                    userDaily.getOrDefault(day, 0L),
                    workoutDaily.getOrDefault(day, 0L)
            ));
        }

        List<DashboardSummary.KindCount> aiKinds = jdbc.sql("""
                SELECT kind, COUNT(*) AS total
                FROM ai_jobs
                WHERE created_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 30 DAY)
                GROUP BY kind
                ORDER BY total DESC
                """).query((rs, rowNum) -> new DashboardSummary.KindCount(
                rs.getString("kind"),
                rs.getLong("total")
        )).list();

        List<DashboardSummary.GoalCount> goals = jdbc.sql("""
                SELECT type, COUNT(*) AS total
                FROM goals WHERE status = 'active'
                GROUP BY type ORDER BY total DESC
                """).query((rs, rowNum) -> new DashboardSummary.GoalCount(
                rs.getString("type"),
                GOAL_LABELS.getOrDefault(rs.getString("type"), rs.getString("type")),
                rs.getLong("total")
        )).list();

        List<DashboardSummary.EquipmentCount> equipment = jdbc.sql("""
                SELECT jt.equipment AS equipment, COUNT(*) AS total
                FROM profiles p,
                     JSON_TABLE(p.equipment, '$[*]' COLUMNS (
                         equipment VARCHAR(32) PATH '$'
                     )) AS jt
                WHERE jt.equipment IS NOT NULL AND jt.equipment <> ''
                GROUP BY jt.equipment
                ORDER BY total DESC
                """).query((rs, rowNum) -> new DashboardSummary.EquipmentCount(
                rs.getString("equipment"),
                rs.getLong("total")
        )).list();

        List<DashboardSummary.RecentUser> recentUsers = jdbc.sql("""
                SELECT u.id,
                       COALESCE(NULLIF(p.nickname, ''), u.phone, u.username, u.id) AS nickname,
                       u.created_at
                FROM users u
                LEFT JOIN profiles p ON p.user_id = u.id
                WHERE u.deleted_at IS NULL
                ORDER BY u.created_at DESC
                LIMIT 5
                """).query((rs, rowNum) -> new DashboardSummary.RecentUser(
                rs.getString("id"),
                rs.getString("nickname"),
                SqlSupport.iso(rs.getTimestamp("created_at"))
        )).list();

        List<DashboardSummary.RecentWorkout> recentWorkouts = jdbc.sql("""
                SELECT ws.id, ws.user_id, ws.started_at, ws.duration_min,
                       COALESCE(NULLIF(p.nickname, ''), u.phone, u.username, ws.user_id) AS nickname,
                       COUNT(sl.id) AS set_count,
                       COALESCE(SUM(CASE WHEN sl.completed = 1
                                         THEN COALESCE(sl.weight_kg, 0) * COALESCE(sl.reps, 0)
                                         ELSE 0 END), 0) AS volume_kg
                FROM (
                    SELECT id, user_id, started_at, duration_min
                    FROM workout_sessions
                    ORDER BY started_at DESC
                    LIMIT 5
                ) ws
                LEFT JOIN users u ON u.id = ws.user_id
                LEFT JOIN profiles p ON p.user_id = ws.user_id
                LEFT JOIN set_logs sl ON sl.session_id = ws.id
                GROUP BY ws.id, ws.user_id, ws.started_at, ws.duration_min,
                         u.phone, u.username, p.nickname
                ORDER BY ws.started_at DESC
                """).query((rs, rowNum) -> new DashboardSummary.RecentWorkout(
                rs.getString("id"),
                rs.getString("user_id"),
                rs.getString("nickname"),
                SqlSupport.iso(rs.getTimestamp("started_at")),
                rs.getLong("set_count"),
                Math.round(SqlSupport.doubleValue(rs.getObject("volume_kg")) * 10.0) / 10.0,
                (Integer) rs.getObject("duration_min")
        )).list();

        List<DashboardSummary.RecentSafety> recentSafety = jdbc.sql("""
                SELECT m.id, c.user_id, m.safety_flag, LEFT(m.content, 160) AS content,
                       m.created_at,
                       COALESCE(NULLIF(p.nickname, ''), u.phone, u.username, c.user_id) AS nickname
                FROM chat_messages m
                JOIN chat_sessions c ON c.id = m.session_id
                LEFT JOIN users u ON u.id = c.user_id
                LEFT JOIN profiles p ON p.user_id = c.user_id
                WHERE m.safety_flag IS NOT NULL
                ORDER BY m.created_at DESC
                LIMIT 5
                """).query((rs, rowNum) -> new DashboardSummary.RecentSafety(
                rs.getString("id"),
                rs.getString("user_id"),
                rs.getString("nickname"),
                rs.getString("safety_flag"),
                rs.getString("content"),
                SqlSupport.iso(rs.getTimestamp("created_at"))
        )).list();

        return new DashboardSummary(
                totals.usersTotal(), totals.usersNew7d(), totals.onboarded(),
                totals.active7d(), totals.active30d(), totals.sessionsTotal(),
                totals.sessions7d(), totals.programsActive(), totals.programsTotal(),
                totals.chatsTotal(), totals.messagesTotal(), totals.safetyFlags(),
                totals.scansTotal(), totals.exercisesTotal(), totals.videosPublished(),
                totals.mealPlansTotal(), totals.aiErrors(), daily, aiKinds,
                goals, equipment, recentUsers, recentWorkouts, recentSafety
        );
    }

    private record Totals(
            long usersTotal,
            long usersNew7d,
            long onboarded,
            long active7d,
            long active30d,
            long sessionsTotal,
            long sessions7d,
            long programsActive,
            long programsTotal,
            long chatsTotal,
            long messagesTotal,
            long safetyFlags,
            long scansTotal,
            long exercisesTotal,
            long videosPublished,
            long mealPlansTotal,
            long aiErrors
    ) {
    }

    private Map<LocalDate, Long> dailyCounts(String sql) {
        Map<LocalDate, Long> result = new HashMap<>();
        jdbc.sql(sql).query((rs, rowNum) -> {
            Date date = rs.getDate("day");
            result.put(date.toLocalDate(), rs.getLong("total"));
            return null;
        }).list();
        return result;
    }
}
