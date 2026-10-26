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
            boolean deleted
    ) {
    }

    public record UserDetail(
            UserListItem user,
            Map<String, Object> profile,
            Map<String, Object> goal,
            List<ProgramBrief> programs,
            List<WorkoutBrief> workouts,
            List<ChatBrief> chats
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
}
