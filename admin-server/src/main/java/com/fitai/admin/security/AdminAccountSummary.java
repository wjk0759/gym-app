package com.fitai.admin.security;

import java.time.Instant;
import java.util.List;

public record AdminAccountSummary(
        String id,
        String username,
        String displayName,
        String status,
        Instant lastLoginAt,
        Instant createdAt,
        List<String> roles
) {
}
