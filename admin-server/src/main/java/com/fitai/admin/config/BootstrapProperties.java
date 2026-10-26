package com.fitai.admin.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "fitai.admin.bootstrap")
public record BootstrapProperties(
        boolean enabled,
        String username,
        String password,
        String displayName
) {
}
