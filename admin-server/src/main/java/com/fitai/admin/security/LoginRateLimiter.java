package com.fitai.admin.security;

import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

import com.fitai.admin.common.api.ApiException;
import com.fitai.admin.config.SecurityProperties;

/**
 * Small in-process guard for credential stuffing. Multi-instance deployments
 * should replace this with Redis-backed counters or the ingress/WAF policy.
 */
@Component
public class LoginRateLimiter {

    private final SecurityProperties properties;
    private final Map<String, Deque<Long>> attempts = new ConcurrentHashMap<>();

    public LoginRateLimiter(SecurityProperties properties) {
        this.properties = properties;
    }

    public void check(String key) {
        long now = System.currentTimeMillis();
        Deque<Long> window = attempts.computeIfAbsent(key, ignored -> new ArrayDeque<>());
        synchronized (window) {
            while (!window.isEmpty() && now - window.peekFirst() > 60_000) {
                window.removeFirst();
            }
            if (window.size() >= properties.loginRateLimitPerMinute()) {
                throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "RATE_LIMITED", "登录尝试过于频繁，请稍后再试");
            }
        }
        if (attempts.size() > 10_000) {
            attempts.clear();
        }
    }

    public void failure(String key) {
        attempts.computeIfAbsent(key, ignored -> new ArrayDeque<>()).addLast(System.currentTimeMillis());
    }

    public void success(String key) {
        attempts.remove(key);
    }
}
