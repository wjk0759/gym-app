package com.fitai.admin.users;

import java.util.List;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public final class UserAccessDtos {

    private UserAccessDtos() {
    }

    public record UserAccess(
            boolean pro,
            String proExpiresAt,
            List<String> sources,
            List<EntitlementItem> entitlements,
            List<TrialItem> trials,
            CoachUsage coach
    ) {
    }

    public record EntitlementItem(
            String id,
            String planCode,
            String source,
            String startsAt,
            String expiresAt,
            String revokedAt,
            String grantedBy,
            String reason,
            String createdAt
    ) {
    }

    public record TrialItem(
            String featureKey,
            String source,
            String usedAt,
            String validUntil
    ) {
    }

    public record CoachUsage(
            int weeklyLimit,
            int used,
            int remaining,
            String periodStart,
            String resetAt
    ) {
    }

    public record GrantRequest(
            @Min(value = 1, message = "会员时长至少 1 天")
            @Max(value = 3650, message = "会员时长最多 3650 天")
            Integer durationDays,
            @NotBlank(message = "请填写操作原因")
            @Size(max = 200, message = "操作原因最多 200 字")
            String reason
    ) {
    }

    public record RevokeRequest(
            @NotBlank(message = "请填写撤销原因")
            @Size(max = 200, message = "撤销原因最多 200 字")
            String reason
    ) {
    }
}
