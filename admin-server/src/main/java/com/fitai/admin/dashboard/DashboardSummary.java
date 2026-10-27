package com.fitai.admin.dashboard;

import java.util.List;

public record DashboardSummary(
        long usersTotal,
        long usersNew7d,
        long onboardedUsers,
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
        long aiErrors,
        List<DailyPoint> daily,
        List<KindCount> aiKinds,
        List<GoalCount> goals,
        List<EquipmentCount> equipment,
        List<RecentUser> recentUsers,
        List<RecentWorkout> recentWorkouts,
        List<RecentSafety> recentSafety
) {
    public record DailyPoint(String date, long users, long workouts) {
    }

    public record KindCount(String kind, long count) {
    }

    public record GoalCount(String type, String label, long count) {
    }

    public record EquipmentCount(String type, long count) {
    }

    public record RecentUser(String id, String nickname, String createdAt) {
    }

    public record RecentWorkout(
            String id,
            String userId,
            String nickname,
            String startedAt,
            long setCount,
            double volumeKg,
            Integer durationMin
    ) {
    }

    public record RecentSafety(
            String id,
            String userId,
            String nickname,
            String safetyFlag,
            String content,
            String createdAt
    ) {
    }
}
