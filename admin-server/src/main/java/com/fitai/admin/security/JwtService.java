package com.fitai.admin.security;

import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.Date;
import java.util.List;
import java.util.UUID;

import javax.crypto.SecretKey;

import org.springframework.stereotype.Service;

import com.fitai.admin.config.JwtProperties;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jws;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;

@Service
public class JwtService {

    private static final String TOKEN_TYPE = "access";

    private final JwtProperties properties;
    private final SecretKey key;

    public JwtService(JwtProperties properties) {
        this.properties = properties;
        String secret = properties.secret();
        if (secret == null || secret.getBytes(StandardCharsets.UTF_8).length < 32) {
            throw new IllegalStateException("fitai.admin.jwt.secret 必须至少 32 字节");
        }
        this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
    }

    public String issue(AdminPrincipal principal) {
        Instant now = Instant.now();
        Instant expiresAt = now.plus(properties.accessTtl());
        return Jwts.builder()
                .issuer(properties.issuer())
                .subject(principal.id())
                .id(UUID.randomUUID().toString())
                .issuedAt(Date.from(now))
                .expiration(Date.from(expiresAt))
                .claim("typ", TOKEN_TYPE)
                .claim("username", principal.getUsername())
                .claim("name", principal.displayName())
                .claim("roles", List.copyOf(principal.roles()))
                .claim("perms", List.copyOf(principal.permissions()))
                .signWith(key)
                .compact();
    }

    public AdminPrincipal parse(String token) {
        Jws<Claims> jws = Jwts.parser()
                .verifyWith(key)
                .requireIssuer(properties.issuer())
                .build()
                .parseSignedClaims(token);
        Claims claims = jws.getPayload();
        if (!TOKEN_TYPE.equals(claims.get("typ", String.class))) {
            throw new IllegalArgumentException("不支持的令牌类型");
        }
        List<String> roles = stringList(claims.get("roles"));
        List<String> permissions = stringList(claims.get("perms"));
        return new AdminPrincipal(
                claims.getSubject(),
                claims.get("username", String.class),
                claims.get("name", String.class),
                "",
                "active",
                roles,
                permissions
        );
    }

    public long accessTtlSeconds() {
        return properties.accessTtl().toSeconds();
    }

    public Duration accessTtl() {
        return properties.accessTtl();
    }

    @SuppressWarnings("unchecked")
    private List<String> stringList(Object value) {
        if (value instanceof List<?> list) {
            return list.stream().filter(String.class::isInstance).map(String.class::cast).toList();
        }
        return List.of();
    }
}
