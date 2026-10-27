package com.fitai.admin.users;

import java.util.List;
import java.util.Map;

public final class UserDtos {

    private UserDtos() {
    }

    public record UserListItem(
            String id,
            String phone,
            String username,
            String nickname,
            String status,
            String sex,
            String createdAt,
            String lastLoginAt,
            Integer weeklyDays,
            String goalType,
            long workoutCount,
            boolean deleted,
            String updatedAt,
            Map<String, Object> authMethods
    ) {
    }

    public record UserDetail(
            UserListItem user,
            Map<String, Object> profile,
            Map<String, Object> goal,
            Map<String, Object> metrics,
            List<Map<String, Object>> goals,
            List<ProgramBrief> programs,
            List<WorkoutBrief> workouts,
            List<ChatBrief> chats,
            List<ScanBrief> scans,
            List<MealBrief> meals,
            List<AiJobBrief> aiJobs
    ) {
    }

    public record ProgramBrief(
            String id,
            String title,
            String status,
            int version,
            String startDate,
            int weeks,
            String createdAt
    ) {
    }

    public record WorkoutBrief(
            String id,
            String startedAt,
            Integer durationMin,
            Integer feeling
    ) {
    }

    public record ChatBrief(
            String id,
            String title,
            String createdAt,
            long messageCount
    ) {
    }

    public record ScanBrief(
            String id,
            String status,
            String model,
            Object result,
            String createdAt
    ) {
    }

    public record MealBrief(
            String id,
            String planDate,
            Integer targetKcal,
            String createdAt
    ) {
    }

    public record AiJobBrief(
            String id,
            String kind,
            String model,
            String status,
            Integer latencyMs,
            String error,
            String createdAt
    ) {
    }
}
