package com.fitai.admin.security;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.HexFormat;
import java.util.Map;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseCookie;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.fitai.admin.common.api.ApiException;
import com.fitai.admin.common.audit.AuditService;
import com.fitai.admin.config.JwtProperties;
import com.fitai.admin.config.SecurityProperties;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

@Service
public class AuthService {

    private static final SecureRandom RANDOM = new SecureRandom();

    private final AuthenticationManager authenticationManager;
    private final AdminAccountRepository accounts;
    private final AdminUserDetailsService userDetails;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final JwtProperties jwtProperties;
    private final SecurityProperties securityProperties;
    private final LoginRateLimiter rateLimiter;
    private final AuditService auditService;

    public AuthService(
            AuthenticationManager authenticationManager,
            AdminAccountRepository accounts,
            AdminUserDetailsService userDetails,
            PasswordEncoder passwordEncoder,
            JwtService jwtService,
            JwtProperties jwtProperties,
            SecurityProperties securityProperties,
            LoginRateLimiter rateLimiter,
            AuditService auditService
    ) {
        this.authenticationManager = authenticationManager;
        this.accounts = accounts;
        this.userDetails = userDetails;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
        this.jwtProperties = jwtProperties;
        this.securityProperties = securityProperties;
        this.rateLimiter = rateLimiter;
        this.auditService = auditService;
    }

    public LoginResponse login(LoginRequest request, HttpServletRequest httpRequest, HttpServletResponse response) {
        String username = request.username().trim();
        String rateKey = username + "|" + clientIp(httpRequest);
        rateLimiter.check(rateKey);
        try {
            Authentication authentication = authenticationManager.authenticate(
                    new UsernamePasswordAuthenticationToken(username, request.password())
            );
            AdminPrincipal principal = (AdminPrincipal) authentication.getPrincipal();
            accounts.touchLogin(principal.id());
            rateLimiter.success(rateKey);
            issueSession(principal, httpRequest, response);
            auditService.recordAs(principal.getUsername(), "ADMIN_LOGIN", "admin_session", principal.id(),
                    Map.of("method", "password"));
            return new LoginResponse(jwtService.issue(principal), jwtService.accessTtlSeconds(),
                    AdminUserView.from(principal));
        } catch (AuthenticationException ex) {
            rateLimiter.failure(rateKey);
            auditService.recordAs(username, "ADMIN_LOGIN_FAILED", "admin_session", null,
                    Map.of("reason", "bad_credentials"));
            throw new ApiException(HttpStatus.UNAUTHORIZED, "BAD_CREDENTIALS", "用户名或密码错误");
        }
    }

    @Transactional
    public LoginResponse refresh(
            String refreshToken,
            HttpServletRequest request,
            HttpServletResponse response
    ) {
        if (refreshToken == null || refreshToken.isBlank()) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "REFRESH_TOKEN_MISSING", "登录会话已失效");
        }
        String hash = hash(refreshToken);
        RefreshTokenRow current = accounts.findActiveRefreshToken(hash)
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "REFRESH_TOKEN_INVALID",
                        "登录会话已失效，请重新登录"));
        AdminPrincipal principal = userDetails.findById(current.adminUserId())
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "ACCOUNT_NOT_FOUND", "管理员账号不存在"));
        if (!principal.isEnabled()) {
            accounts.revokeRefreshToken(current.id());
            clearCookie(response);
            throw new ApiException(HttpStatus.FORBIDDEN, "ACCOUNT_DISABLED", "管理员账号已停用");
        }
        if (!accounts.revokeRefreshToken(current.id())) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "REFRESH_TOKEN_REUSED", "登录会话已失效，请重新登录");
        }
        issueSession(principal, request, response);
        auditService.recordAs(principal.getUsername(), "ADMIN_TOKEN_REFRESH", "admin_session", principal.id(),
                Map.of("method", "refresh_rotation"));
        return new LoginResponse(jwtService.issue(principal), jwtService.accessTtlSeconds(),
                AdminUserView.from(principal));
    }

    public void logout(String refreshToken, HttpServletResponse response) {
        if (refreshToken != null && !refreshToken.isBlank()) {
            accounts.findActiveRefreshToken(hash(refreshToken))
                    .ifPresent(token -> accounts.revokeRefreshToken(token.id()));
        }
        clearCookie(response);
    }

    public AdminUserView me() {
        AdminPrincipal principal = CurrentAdmin.require();
        return AdminUserView.from(principal);
    }

    @Transactional
    public void changePassword(ChangePasswordRequest request) {
        AdminPrincipal principal = CurrentAdmin.require();
        AdminAccountRow account = accounts.findById(principal.id())
                .orElseThrow(() -> ApiException.notFound("ACCOUNT_NOT_FOUND", "管理员账号不存在"));
        if (!passwordEncoder.matches(request.currentPassword(), account.passwordHash())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "PASSWORD_MISMATCH", "当前密码错误");
        }
        PasswordPolicy.validate(request.newPassword());
        if (passwordEncoder.matches(request.newPassword(), account.passwordHash())) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "PASSWORD_REUSED", "新密码不能与当前密码相同");
        }
        accounts.updatePassword(principal.id(), passwordEncoder.encode(request.newPassword()));
        accounts.revokeAllRefreshTokens(principal.id());
        auditService.recordAs(principal.getUsername(), "ADMIN_PASSWORD_CHANGED", "admin_user", principal.id(),
                Map.of("sessionsRevoked", true));
    }

    private void issueSession(AdminPrincipal principal, HttpServletRequest request, HttpServletResponse response) {
        String token = newRefreshToken();
        Instant expiresAt = Instant.now().plus(jwtProperties.refreshTtl());
        accounts.insertRefreshToken(
                UUID.randomUUID().toString(),
                principal.id(),
                hash(token),
                expiresAt,
                clientIp(request),
                limit(request.getHeader("User-Agent"), 255)
        );
        setCookie(response, token);
    }

    private void setCookie(HttpServletResponse response, String token) {
        ResponseCookie cookie = ResponseCookie.from(jwtProperties.cookieName(), token)
                .httpOnly(true)
                .secure(jwtProperties.cookieSecure())
                .sameSite(jwtProperties.cookieSameSite())
                .path(securityProperties.refreshCookiePath())
                .maxAge(jwtProperties.refreshTtl())
                .build();
        response.addHeader("Set-Cookie", cookie.toString());
    }

    private void clearCookie(HttpServletResponse response) {
        ResponseCookie cookie = ResponseCookie.from(jwtProperties.cookieName(), "")
                .httpOnly(true)
                .secure(jwtProperties.cookieSecure())
                .sameSite(jwtProperties.cookieSameSite())
                .path(securityProperties.refreshCookiePath())
                .maxAge(Duration.ZERO)
                .build();
        response.addHeader("Set-Cookie", cookie.toString());
    }

    private String newRefreshToken() {
        byte[] bytes = new byte[32];
        RANDOM.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    private String hash(String token) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(digest.digest(token.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException ex) {
            throw new IllegalStateException("SHA-256 unavailable", ex);
        }
    }

    private String clientIp(HttpServletRequest request) {
        String realIp = request.getHeader("X-Real-IP");
        if (realIp != null && !realIp.isBlank()) {
            return realIp.trim();
        }
        String forwarded = request.getHeader("X-Forwarded-For");
        if (forwarded != null && !forwarded.isBlank()) {
            // Nginx appends the immediate client address. Use the right-most
            // value instead of trusting a spoofable left-most entry.
            String[] parts = forwarded.split(",");
            return parts[parts.length - 1].trim();
        }
        return request.getRemoteAddr();
    }

    private String limit(String value, int max) {
        if (value == null) {
            return null;
        }
        return value.length() <= max ? value : value.substring(0, max);
    }
}
