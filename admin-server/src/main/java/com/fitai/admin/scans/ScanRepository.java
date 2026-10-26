package com.fitai.admin.scans;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import com.fitai.admin.common.api.PageResponse;
import com.fitai.admin.common.persistence.JsonCodec;
import com.fitai.admin.common.persistence.SqlSupport;

@Repository
public class ScanRepository {

    private final JdbcClient jdbc;
    private final JsonCodec jsonCodec;

    public ScanRepository(JdbcClient jdbc, JsonCodec jsonCodec) {
        this.jdbc = jdbc;
        this.jsonCodec = jsonCodec;
    }

    public PageResponse<ScanDtos.ScanListItem> list(
            String query,
            String status,
            int page,
            int size
    ) {
        int safePage = SqlSupport.page(page);
        int safeSize = SqlSupport.size(size);
        String where = where(query, status);
        Map<String, Object> params = params(query, status);
        long total = jdbc.sql("""
                SELECT COUNT(*)
                FROM equipment_scans s
                JOIN users u ON u.id = s.user_id
                LEFT JOIN profiles p ON p.user_id = s.user_id
                """ + where).params(params).query(Long.class).optional().orElse(0L);
        List<ScanDtos.ScanListItem> items = jdbc.sql("""
                SELECT s.id, s.user_id, s.image_url, s.status, s.model, s.result, s.created_at,
                       COALESCE(NULLIF(p.nickname, ''), u.phone, u.username, s.user_id) AS user_label
                FROM equipment_scans s
                JOIN users u ON u.id = s.user_id
                LEFT JOIN profiles p ON p.user_id = s.user_id
                """ + where + """
                ORDER BY s.created_at DESC
                LIMIT :limit OFFSET :offset
                """).params(params)
                .param("limit", safeSize)
                .param("offset", SqlSupport.offset(safePage, safeSize))
                .query((rs, rowNum) -> mapScan(rs))
                .list();
        return PageResponse.of(items, safePage, safeSize, total);
    }

    public Optional<ScanDtos.ScanDetail> detail(String id) {
        Optional<ScanDtos.ScanListItem> scan = jdbc.sql("""
                SELECT s.id, s.user_id, s.image_url, s.status, s.model, s.result, s.created_at,
                       COALESCE(NULLIF(p.nickname, ''), u.phone, u.username, s.user_id) AS user_label
                FROM equipment_scans s
                JOIN users u ON u.id = s.user_id
                LEFT JOIN profiles p ON p.user_id = s.user_id
                WHERE s.id = :id
                """).param("id", id).query((rs, rowNum) -> mapScan(rs)).optional();
        if (scan.isEmpty()) {
            return Optional.empty();
        }
        String result = jdbc.sql("SELECT result FROM equipment_scans WHERE id = :id")
                .param("id", id).query(String.class).single();
        return Optional.of(new ScanDtos.ScanDetail(scan.get(), jsonCodec.parse(result)));
    }

    public boolean delete(String id) {
        return jdbc.sql("DELETE FROM equipment_scans WHERE id = :id").param("id", id).update() > 0;
    }

    private String where(String query, String status) {
        List<String> clauses = new ArrayList<>();
        if (status != null && !status.isBlank()) {
            clauses.add("s.status = :status");
        }
        if (query != null && !query.isBlank()) {
            clauses.add("""
                    (COALESCE(u.phone, '') LIKE :q
                     OR LOWER(COALESCE(p.nickname, '')) LIKE :q
                     OR s.user_id = :rawQuery)
                    """);
        }
        return clauses.isEmpty() ? "" : " WHERE " + String.join(" AND ", clauses) + " ";
    }

    private Map<String, Object> params(String query, String status) {
        Map<String, Object> params = new HashMap<>();
        if (query != null && !query.isBlank()) {
            params.put("q", SqlSupport.like(query));
            params.put("rawQuery", query.trim());
        }
        if (status != null && !status.isBlank()) {
            params.put("status", status);
        }
        return params;
    }

    private ScanDtos.ScanListItem mapScan(java.sql.ResultSet rs) throws java.sql.SQLException {
        Object parsed = jsonCodec.parse(rs.getString("result"));
        Object top = null;
        if (parsed instanceof List<?> list && !list.isEmpty()) {
            top = list.getFirst();
        }
        int count = parsed instanceof List<?> list ? list.size() : 0;
        return new ScanDtos.ScanListItem(
                rs.getString("id"),
                rs.getString("user_id"),
                rs.getString("user_label"),
                rs.getString("image_url"),
                rs.getString("status"),
                rs.getString("model"),
                count,
                top,
                SqlSupport.iso(rs.getTimestamp("created_at"))
        );
    }
}
