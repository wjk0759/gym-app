package com.fitai.admin.security;

public record LoginResponse(
        String accessToken,
        long expiresIn,
        AdminUserView user
) {
}
