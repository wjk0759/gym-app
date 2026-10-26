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


@Repository
public class DashboardRepository {

    private final JdbcClient jdbc;

    public DashboardRepository(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    public DashboardSummary load() {
        long usersTotal = count("SELECT COUNT(*) FROM users WHERE deleted_at IS NULL");
        long usersNew7d = count("""
                SELECT COUNT(*) FROM users
                WHERE deleted_at IS NULL AND created_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 7 DAY)
                """);
        long onboarded = count("SELECT COUNT(*) FROM profiles WHERE onboarded_at IS NOT NULL");
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

        return new DashboardSummary(
                usersTotal, usersNew7d, onboarded, sessionsTotal, sessions7d,
                programsActive, programsTotal, chatsTotal, messagesTotal, safetyFlags,
                scansTotal, exercisesTotal, videosPublished, mealPlansTotal,
                daily, aiKinds
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

