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
            boolean test,
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

    public record UserInsights(
            List<BodyMetricItem> bodyMetrics,
            List<MealPlanItem> mealPlans,
            List<FoodLogItem> foodLogs,
            List<ScheduleItem> schedule,
            List<WatchSessionItem> watchSessions,
            List<WatchWorkoutItem> watchWorkouts,
            List<MemoryItem> memories,
            List<EquipmentItem> equipment
    ) {
    }

    public record BodyMetricItem(
            String id,
            String measuredAt,
            Double weightKg,
            Double bodyFatPct,
            Double waistCm,
            Double armCm,
            Double thighCm,
            String createdAt
    ) {
    }

    public record MealPlanItem(
            String id,
            String planDate,
            String weekStart,
            String strategy,
            String generatedBy,
            String modelName,
            Integer targetKcal,
            Double targetProteinG,
            Double targetCarbG,
            Double targetFatG,
            Object plan,
            String createdAt,
            String updatedAt
    ) {
    }

    public record FoodLogItem(
            String id,
            String loggedAt,
            String meal,
            String foodName,
            Double grams,
            Double kcal,
            Double protein,
            Double carbs,
            Double fat,
            Double fiber
    ) {
    }

    public record ScheduleItem(
            String planId,
            String dayId,
            Integer planVersion,
            String assignedDate,
            String skippedAt,
            String clientUpdatedAt,
            String updatedAt
    ) {
    }

    public record WatchSessionItem(
            String id,
            String deviceName,
            String deviceId,
            String createdAt,
            String lastUsedAt,
            String lastTouchedAt,
            String expiresAt,
            String revokedAt
    ) {
    }

    public record WatchWorkoutItem(
            String id,
            String startedAt,
            Integer durationMin,
            Integer feeling,
            String healthkitWorkoutId
    ) {
    }

    public record MemoryItem(
            String id,
            String kind,
            String content,
            String memoryKey,
            String source,
            Double confidence,
            boolean active,
            String createdAt,
            String updatedAt,
            String lastUsedAt
    ) {
    }

    public record EquipmentItem(
            String id,
            String name,
            String slug,
            String muscle,
            String equipment,
            String notes,
            String source,
            String createdAt,
            String updatedAt
    ) {
    }
}
