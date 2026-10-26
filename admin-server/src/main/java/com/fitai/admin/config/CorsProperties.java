package com.fitai.admin.config;

import java.util.List;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "fitai.admin.cors")
public record CorsProperties(List<String> allowedOrigins) {
}
