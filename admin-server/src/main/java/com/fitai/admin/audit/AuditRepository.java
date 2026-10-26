package com.fitai.admin.audit;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import com.fitai.admin.common.api.PageResponse;
import com.fitai.admin.common.persistence.JsonCodec;
import com.fitai.admin.common.persistence.SqlSupport;

@Repository
public class AuditRepository {

    private final JdbcClient jdbc;
    private final JsonCodec jsonCodec;

    public AuditRepository(JdbcClient jdbc, JsonCodec jsonCodec) {
        this.jdbc = jdbc;
        this.jsonCodec = jsonCodec;
    }

    public PageResponse<AuditDtos.AuditItem> list(
            String actor,
            String action,
            String targetType,
            int page,
            int size
    ) {
        int safePage = SqlSupport.page(page);
        int safeSize = SqlSupport.size(size);
        List<String> clauses = new ArrayList<>();
        Map<String, Object> params = new HashMap<>();
        if (actor != null && !actor.isBlank()) {
            clauses.add("actor = :actor");
            params.put("actor", actor);
        }
        if (action != null && !action.isBlank()) {
            clauses.add("action = :action");
            params.put("action", action);
        }
        if (targetType != null && !targetType.isBlank()) {
            clauses.add("target_type = :targetType");
            params.put("targetType", targetType);
        }
        String where = clauses.isEmpty() ? "" : " WHERE " + String.join(" AND ", clauses) + " ";
        long total = jdbc.sql("SELECT COUNT(*) FROM admin_audit_logs" + where)
                .params(params).query(Long.class).optional().orElse(0L);
        List<AuditDtos.AuditItem> items = jdbc.sql("""
                SELECT id, actor, action, target_type, target_id, detail, created_at
                FROM admin_audit_logs
                """ + where + """
                ORDER BY created_at DESC
                LIMIT :limit OFFSET :offset
                """).params(params)
                .param("limit", safeSize)
                .param("offset", SqlSupport.offset(safePage, safeSize))
                .query((rs, rowNum) -> new AuditDtos.AuditItem(
                        rs.getString("id"),
                        rs.getString("actor"),
                        rs.getString("action"),
                        rs.getString("target_type"),
                        rs.getString("target_id"),
                        jsonCodec.parse(rs.getString("detail")),
                        SqlSupport.iso(rs.getTimestamp("created_at"))
                )).list();
        return PageResponse.of(items, safePage, safeSize, total);
    }
}
