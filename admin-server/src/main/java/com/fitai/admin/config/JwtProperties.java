package com.fitai.admin.config;

import java.time.Duration;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "fitai.admin.jwt")
public record JwtProperties(
        String issuer,
        String secret,
        Duration accessTtl,
        Duration refreshTtl,
        String cookieName,
        boolean cookieSecure,
        String cookieSameSite
) {
}
