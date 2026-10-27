package com.fitai.admin.dashboard;

import java.sql.Date;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import com.fitai.admin.common.persistence.JsonCodec;
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
    private final JsonCodec jsonCodec;

    public DashboardRepository(JdbcClient jdbc, JsonCodec jsonCodec) {
        this.jdbc = jdbc;
        this.jsonCodec = jsonCodec;
    }

    public DashboardSummary load() {
        long usersTotal = count("SELECT COUNT(*) FROM users WHERE deleted_at IS NULL");
        long usersNew7d = count("""
                SELECT COUNT(*) FROM users
                WHERE deleted_at IS NULL AND created_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 7 DAY)
                """);
        long onboarded = count("SELECT COUNT(*) FROM profiles WHERE onboarded_at IS NOT NULL");
        long active7d = count("""
                SELECT COUNT(*) FROM (
                    SELECT user_id FROM workout_sessions
                    WHERE started_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 7 DAY)
                    UNION
                    SELECT user_id FROM chat_sessions
                    WHERE created_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 7 DAY)
                ) active_users
                """);
        long active30d = count("""
                SELECT COUNT(*) FROM (
                    SELECT user_id FROM workout_sessions
                    WHERE started_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 30 DAY)
                    UNION
                    SELECT user_id FROM chat_sessions
                    WHERE created_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 30 DAY)
                ) active_users
                """);
        long sessionsTotal = count("SELECT COUNT(*) FROM workout_sessions");
        long sessions7d = count("""
                SELECT COUNT(*) FROM workout_sessions
                WHERE started_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 7 DAY)
                """);
        long programsActive = count("SELECT COUNT(*) FROM programs WHERE status = 'active'");
        long programsTotal = count("SELECT COUNT(*) FROM programs");
        long chatsTotal = count("SELECT COUNT(*) FROM chat_sessions");
        long messagesTotal = count("SELECT COUNT(*) FROM chat_messages");
        long safetyFlags = count("SELECT COUNT(*) FROM chat_messages WHERE safety_flag IS NOT NULL");
        long scansTotal = count("SELECT COUNT(*) FROM equipment_scans");
        long exercisesTotal = count("SELECT COUNT(*) FROM exercises");
        long videosPublished = count("SELECT COUNT(*) FROM exercise_videos WHERE status = 'published'");
        long mealPlansTotal = count("SELECT COUNT(*) FROM meal_plans");
        long aiErrors = count("SELECT COUNT(*) FROM ai_jobs WHERE status <> 'ok'");

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

        Map<String, Long> equipmentCounts = new LinkedHashMap<>();
        jdbc.sql("SELECT equipment FROM profiles")
                .query(String.class)
                .list()
                .forEach(raw -> {
                    Object parsed = jsonCodec.parse(raw);
                    if (parsed instanceof List<?> items) {
                        items.forEach(item -> equipmentCounts.merge(String.valueOf(item), 1L, Long::sum));
                    }
                });
        List<DashboardSummary.EquipmentCount> equipment = equipmentCounts.entrySet().stream()
                .sorted(Map.Entry.<String, Long>comparingByValue(Comparator.reverseOrder()))
                .map(entry -> new DashboardSummary.EquipmentCount(entry.getKey(), entry.getValue()))
                .toList();

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
                FROM workout_sessions ws
                LEFT JOIN users u ON u.id = ws.user_id
                LEFT JOIN profiles p ON p.user_id = ws.user_id
                LEFT JOIN set_logs sl ON sl.session_id = ws.id
                GROUP BY ws.id, ws.user_id, ws.started_at, ws.duration_min,
                         u.phone, u.username, p.nickname
                ORDER BY ws.started_at DESC
                LIMIT 5
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
                usersTotal, usersNew7d, onboarded, active7d, active30d,
                sessionsTotal, sessions7d, programsActive, programsTotal,
                chatsTotal, messagesTotal, safetyFlags, scansTotal, exercisesTotal,
                videosPublished, mealPlansTotal, aiErrors, daily, aiKinds,
                goals, equipment, recentUsers, recentWorkouts, recentSafety
        );
    }

    private long count(String sql) {
        return jdbc.sql(sql).query(Long.class).optional().orElse(0L);
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
