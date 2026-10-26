package com.fitai.admin.common.audit;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

import org.slf4j.MDC;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import com.fitai.admin.common.persistence.JsonCodec;
import com.fitai.admin.common.web.RequestIdFilter;
import com.fitai.admin.security.AdminPrincipal;
import com.fitai.admin.security.CurrentAdmin;

import jakarta.servlet.http.HttpServletRequest;

@Service
public class AuditService {

    private final JdbcClient jdbc;
    private final JsonCodec jsonCodec;

    public AuditService(JdbcClient jdbc, JsonCodec jsonCodec) {
        this.jdbc = jdbc;
        this.jsonCodec = jsonCodec;
    }

    public void record(String action, String targetType, String targetId, Map<String, Object> detail) {
        String actor = CurrentAdmin.find().map(AdminPrincipal::getUsername).orElse("system");
        recordAs(actor, action, targetType, targetId, detail);
    }

    public void recordAs(
            String actor,
            String action,
            String targetType,
            String targetId,
            Map<String, Object> detail
    ) {
        Map<String, Object> payload = new LinkedHashMap<>();
        if (detail != null) {
            payload.putAll(detail);
        }
        payload.put("requestId", MDC.get(RequestIdFilter.MDC_KEY));
        HttpServletRequest request = currentRequest();
        if (request != null) {
            payload.put("ip", clientIp(request));
            payload.put("userAgent", request.getHeader("User-Agent"));
        }
        jdbc.sql("""
                INSERT INTO admin_audit_logs
                    (id, actor, action, target_type, target_id, detail, created_at)
                VALUES
                    (:id, :actor, :action, :targetType, :targetId, :detail, :createdAt)
                """)
                .param("id", UUID.randomUUID().toString())
                .param("actor", actor == null ? "system" : actor)
                .param("action", action)
                .param("targetType", targetType)
                .param("targetId", targetId)
                .param("detail", jsonCodec.write(payload))
                .param("createdAt", Timestamp.from(Instant.now()))
                .update();
    }

    private HttpServletRequest currentRequest() {
        if (RequestContextHolder.getRequestAttributes() instanceof ServletRequestAttributes attributes) {
            return attributes.getRequest();
        }
        return null;
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
}
