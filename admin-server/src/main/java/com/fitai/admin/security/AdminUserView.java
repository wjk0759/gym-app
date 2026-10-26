package com.fitai.admin.security;

import java.util.List;

public record AdminUserView(
        String id,
        String username,
        String displayName,
        List<String> roles,
        List<String> permissions
) {
    public static AdminUserView from(AdminPrincipal principal) {
        return new AdminUserView(
                principal.id(),
                principal.getUsername(),
                principal.displayName(),
                List.copyOf(principal.roles()),
                List.copyOf(principal.permissions())
        );
    }
}
