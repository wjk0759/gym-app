package com.fitai.admin.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "fitai.admin.media")
public record MediaProperties(String root, long maxVideoMb) {
}
