package com.fitai.admin.security;

import java.time.Instant;

public record AdminAccountRow(
        String id,
        String username,
        String passwordHash,
        String displayName,
        String status
) {
}

record RefreshTokenRow(
        String id,
        String adminUserId,
        Instant expiresAt,
        Instant revokedAt
) {
}
