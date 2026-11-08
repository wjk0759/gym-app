package com.fitai.admin.diet;

import java.util.List;

public final class DietDtos {

    private DietDtos() {
    }

    public record DietSummary(
            long mealPlansTotal,
            long mealPlans7d,
            long foodLogsTotal,
            long foodLogs7d,
            long activeUsers7d,
            Double avgTargetKcal,
            List<StrategyCount> strategies,
            List<GeneratedByCount> generatedBy,
            List<RecentPlan> recentPlans,
            List<RecentLog> recentLogs
    ) {
    }

    public record StrategyCount(String strategy, long count) {
    }

    public record GeneratedByCount(String generatedBy, long count) {
    }

    public record RecentPlan(
            String id,
            String userId,
            String userLabel,
            String planDate,
            String weekStart,
            String strategy,
            String generatedBy,
            Integer targetKcal,
            String createdAt
    ) {
    }

    public record RecentLog(
            String id,
            String userId,
            String userLabel,
            String loggedAt,
            String meal,
            String foodName,
            Double grams,
            Double kcal,
            Double protein,
            Double carbs,
            Double fat
    ) {
    }
}
