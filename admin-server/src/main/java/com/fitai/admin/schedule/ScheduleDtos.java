package com.fitai.admin.schedule;

public final class ScheduleDtos {

    private ScheduleDtos() {
    }

    public record ScheduleStateItem(
            String id,
            String userId,
            String userLabel,
            String planId,
            Integer planVersion,
            String dayId,
            String assignedDate,
            String skippedAt,
            String clientUpdatedAt,
            String updatedAt
    ) {
    }
}
