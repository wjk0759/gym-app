package com.fitai.admin.audit;

public final class AuditDtos {

    private AuditDtos() {
    }

    public record AuditItem(
            String id,
            String actor,
            String action,
            String targetType,
            String targetId,
            Object detail,
            String createdAt
    ) {
    }
}
