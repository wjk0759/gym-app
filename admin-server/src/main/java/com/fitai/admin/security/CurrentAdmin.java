package com.fitai.admin.security;

import java.util.Optional;

import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;

public final class CurrentAdmin {

    private CurrentAdmin() {
    }

    public static Optional<AdminPrincipal> find() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null || !(authentication.getPrincipal() instanceof AdminPrincipal principal)) {
            return Optional.empty();
        }
        return Optional.of(principal);
    }

    public static AdminPrincipal require() {
        return find().orElseThrow(() -> new IllegalStateException("当前请求没有管理员身份"));
    }
}
