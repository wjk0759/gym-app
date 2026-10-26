package com.fitai.admin.dashboard;

import java.time.LocalDate;
import java.util.List;

public record DashboardSummary(
        long usersTotal,
        long usersNew7d,
        long onboardedUsers,
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
        List<DailyPoint> daily,
        List<KindCount> aiKinds
) {
    public record DailyPoint(String date, long users, long workouts) {
    }

    public record KindCount(String kind, long count) {
    }
}

