package com.fitai.admin.security;

import java.util.Collection;
import java.util.LinkedHashSet;
import java.util.Set;

import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

public class AdminPrincipal implements UserDetails {

    private final String id;
    private final String username;
    private final String displayName;
    private final String passwordHash;
    private final String status;
    private final Set<String> roles;
    private final Set<String> permissions;

    public AdminPrincipal(
            String id,
            String username,
            String displayName,
            String passwordHash,
            String status,
            Collection<String> roles,
            Collection<String> permissions
    ) {
        this.id = id;
        this.username = username;
        this.displayName = displayName;
        this.passwordHash = passwordHash;
        this.status = status;
        this.roles = new LinkedHashSet<>(roles == null ? Set.of() : roles);
        this.permissions = new LinkedHashSet<>(permissions == null ? Set.of() : permissions);
    }

    public String id() {
        return id;
    }

    public String displayName() {
        return displayName;
    }

    public Set<String> roles() {
        return Set.copyOf(roles);
    }

    public Set<String> permissions() {
        return Set.copyOf(permissions);
    }

    public String status() {
        return status;
    }

    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        LinkedHashSet<SimpleGrantedAuthority> authorities = new LinkedHashSet<>();
        roles.forEach(role -> authorities.add(new SimpleGrantedAuthority("ROLE_" + role)));
        permissions.forEach(permission -> authorities.add(new SimpleGrantedAuthority(permission)));
        return authorities;
    }

    @Override
    public String getPassword() {
        return passwordHash;
    }

    @Override
    public String getUsername() {
        return username;
    }

    @Override
    public boolean isAccountNonExpired() {
        return true;
    }

    @Override
    public boolean isAccountNonLocked() {
        return "active".equals(status);
    }

    @Override
    public boolean isCredentialsNonExpired() {
        return true;
    }

    @Override
    public boolean isEnabled() {
        return "active".equals(status);
    }
}
