package com.fitai.admin.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "fitai.admin.security")
public record SecurityProperties(
        String refreshCookiePath,
        int loginRateLimitPerMinute
) {
}
