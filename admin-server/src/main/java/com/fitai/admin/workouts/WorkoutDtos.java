package com.fitai.admin.workouts;

import java.util.List;

public final class WorkoutDtos {

    private WorkoutDtos() {
    }

    public record WorkoutListItem(
            String id,
            String userId,
            String userLabel,
            String startedAt,
            String finishedAt,
            Integer durationMin,
            Integer feeling,
            int exerciseCount,
            int setCount,
            double volumeKg
    ) {
    }

    public record WorkoutDetail(WorkoutListItem workout, List<WorkoutSetItem> sets) {
    }

    public record WorkoutSetItem(
            String id,
            String slug,
            String nameZh,
            int setIndex,
            Object weightKg,
            Integer reps,
            Object rpe,
            boolean completed,
            String createdAt
    ) {
    }
}
