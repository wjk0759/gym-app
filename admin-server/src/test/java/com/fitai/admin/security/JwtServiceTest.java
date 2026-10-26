package com.fitai.admin.security;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Duration;
import java.util.List;

import org.junit.jupiter.api.Test;

import com.fitai.admin.config.JwtProperties;

import io.jsonwebtoken.JwtException;

class JwtServiceTest {

    private final JwtProperties properties = new JwtProperties(
            "fitai-admin-test",
            "test-secret-with-at-least-thirty-two-bytes-for-hmac-signing",
            Duration.ofMinutes(15),
            Duration.ofDays(7),
            "fitai_admin_refresh",
            false,
            "Strict"
    );

    @Test
    void issuesAndParsesAccessTokenWithoutLeakingPassword() {
        JwtService service = new JwtService(properties);
        AdminPrincipal principal = new AdminPrincipal(
                "admin-1",
                "operator",
                "运营管理员",
                "$2a$12$not-a-real-hash",
                "active",
                List.of("OPERATOR"),
                List.of("dashboard:read", "user:read")
        );

        String token = service.issue(principal);
        AdminPrincipal parsed = service.parse(token);

        assertThat(parsed.id()).isEqualTo("admin-1");
        assertThat(parsed.getUsername()).isEqualTo("operator");
        assertThat(parsed.displayName()).isEqualTo("运营管理员");
        assertThat(parsed.getPassword()).isEmpty();
        assertThat(parsed.roles()).containsExactly("OPERATOR");
        assertThat(parsed.permissions()).containsExactlyInAnyOrder("dashboard:read", "user:read");
        assertThat(service.accessTtlSeconds()).isEqualTo(900);
    }

    @Test
    void rejectsTokenSignedByAnotherSecret() {
        JwtService issuer = new JwtService(properties);
        JwtService verifier = new JwtService(new JwtProperties(
                "fitai-admin-test",
                "another-secret-with-at-least-thirty-two-bytes-for-hmac",
                Duration.ofMinutes(15),
                Duration.ofDays(7),
                "fitai_admin_refresh",
                false,
                "Strict"
        ));
        String token = issuer.issue(new AdminPrincipal(
                "admin-1", "operator", "运营管理员", "", "active", List.of("OPERATOR"), List.of()
        ));

        assertThatThrownBy(() -> verifier.parse(token)).isInstanceOf(JwtException.class);
    }
}
