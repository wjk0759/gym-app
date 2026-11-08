package com.fitai.admin.memberships;

import java.util.List;

public final class MembershipDtos {

    private MembershipDtos() {
    }

    public record MembershipItem(
            String entitlementId,
            String userId,
            String userLabel,
            String phone,
            String nickname,
            String planCode,
            String source,
            String sourceRef,
            String startsAt,
            String expiresAt,
            String revokedAt,
            String status,
            Long daysLeft,
            String grantedBy,
            String reason,
            String createdAt
    ) {
    }

    public record MembershipSummary(
            long activeProUsers,
            long activeEntitlements,
            long expiring7d,
            long expiring30d,
            long newGrants7d,
            long revoked30d,
            List<SourceCount> sources
    ) {
    }

    public record SourceCount(
            String source,
            long count
    ) {
    }
}
