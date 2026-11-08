package com.fitai.admin.diet;

import java.math.BigDecimal;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import com.fitai.admin.common.persistence.SqlSupport;

@Repository
public class DietRepository {

    private final JdbcClient jdbc;

    public DietRepository(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    public DietDtos.DietSummary summary() {
        long mealPlansTotal = count("SELECT COUNT(*) FROM meal_plans");
        long mealPlans7d = count("""
                SELECT COUNT(*) FROM meal_plans
                WHERE created_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 7 DAY)
                """);
        long foodLogsTotal = count("SELECT COUNT(*) FROM food_logs");
        long foodLogs7d = count("""
                SELECT COUNT(*) FROM food_logs
                WHERE logged_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 7 DAY)
                """);
        long activeUsers7d = count("""
                SELECT COUNT(*) FROM (
                    SELECT user_id FROM meal_plans
                    WHERE created_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 7 DAY)
                    UNION
                    SELECT user_id FROM food_logs
                    WHERE logged_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 7 DAY)
                ) active
                """);
        Double avgTargetKcal = jdbc.sql("""
                SELECT AVG(target_kcal) FROM meal_plans
                WHERE target_kcal IS NOT NULL
                  AND created_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 30 DAY)
                """).query(BigDecimal.class).optional()
                .map(BigDecimal::doubleValue)
                .orElse(null);
        var strategies = jdbc.sql("""
                SELECT strategy, COUNT(*) AS total
                FROM meal_plans
                GROUP BY strategy
                ORDER BY total DESC
                """).query((rs, rowNum) -> new DietDtos.StrategyCount(
                rs.getString("strategy"),
                rs.getLong("total")
        )).list();
        var generatedBy = jdbc.sql("""
                SELECT generated_by, COUNT(*) AS total
                FROM meal_plans
                GROUP BY generated_by
                ORDER BY total DESC
                """).query((rs, rowNum) -> new DietDtos.GeneratedByCount(
                rs.getString("generated_by"),
                rs.getLong("total")
        )).list();
        var recentPlans = jdbc.sql("""
                SELECT m.id, m.user_id, m.plan_date, m.week_start, m.strategy,
                       m.generated_by, m.target_kcal, m.created_at,
                       COALESCE(NULLIF(p.nickname, ''), u.phone, u.username, m.user_id) AS user_label
                FROM meal_plans m
                JOIN users u ON u.id = m.user_id
                LEFT JOIN profiles p ON p.user_id = m.user_id
                ORDER BY m.created_at DESC
                LIMIT 20
                """).query((rs, rowNum) -> new DietDtos.RecentPlan(
                rs.getString("id"),
                rs.getString("user_id"),
                rs.getString("user_label"),
                SqlSupport.iso(rs.getDate("plan_date")),
                SqlSupport.iso(rs.getDate("week_start")),
                rs.getString("strategy"),
                rs.getString("generated_by"),
                (Integer) rs.getObject("target_kcal"),
                SqlSupport.iso(rs.getTimestamp("created_at"))
        )).list();
        var recentLogs = jdbc.sql("""
                SELECT f.id, f.user_id, f.logged_at, f.meal, f.food_name, f.grams,
                       f.kcal, f.protein, f.carbs, f.fat,
                       COALESCE(NULLIF(p.nickname, ''), u.phone, u.username, f.user_id) AS user_label
                FROM food_logs f
                JOIN users u ON u.id = f.user_id
                LEFT JOIN profiles p ON p.user_id = f.user_id
                ORDER BY f.logged_at DESC
                LIMIT 20
                """).query((rs, rowNum) -> new DietDtos.RecentLog(
                rs.getString("id"),
                rs.getString("user_id"),
                rs.getString("user_label"),
                SqlSupport.iso(rs.getTimestamp("logged_at")),
                rs.getString("meal"),
                rs.getString("food_name"),
                doubleValue(rs.getObject("grams")),
                doubleValue(rs.getObject("kcal")),
                doubleValue(rs.getObject("protein")),
                doubleValue(rs.getObject("carbs")),
                doubleValue(rs.getObject("fat"))
        )).list();
        return new DietDtos.DietSummary(
                mealPlansTotal, mealPlans7d, foodLogsTotal, foodLogs7d,
                activeUsers7d, avgTargetKcal, strategies, generatedBy, recentPlans, recentLogs
        );
    }

    private long count(String sql) {
        return jdbc.sql(sql).query(Long.class).optional().orElse(0L);
    }

    private Double doubleValue(Object value) {
        if (value instanceof BigDecimal decimal) {
            return decimal.doubleValue();
        }
        return value == null ? null : ((Number) value).doubleValue();
    }
}
