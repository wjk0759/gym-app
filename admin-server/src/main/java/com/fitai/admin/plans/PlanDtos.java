package com.fitai.admin.plans;

import java.util.List;

public final class PlanDtos {

    private PlanDtos() {
    }

    public record PlanListItem(
            String id,
            String userId,
            String userLabel,
            String title,
            String goalType,
            int version,
            String status,
            String startDate,
            int weeks,
            int dayCount,
            int exerciseCount,
            String createdAt
    ) {
    }

    public record PlanDetail(PlanListItem plan, List<PlanDay> days) {
    }

    public record PlanDay(
            String id,
            int weekIndex,
            int weekday,
            String title,
            Object focus,
            List<PlanExerciseItem> exercises
    ) {
    }

    public record PlanExerciseItem(
            String id,
            String slug,
            String nameZh,
            String muscleGroup,
            String equipment,
            int sets,
            String reps,
            Object weightKg,
            int restSec,
            Object rpe,
            String notes
    ) {
    }
}
