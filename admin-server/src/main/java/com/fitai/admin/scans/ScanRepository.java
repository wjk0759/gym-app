package com.fitai.admin.scans;

import java.time.LocalDate;
import java.time.ZoneOffset;
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
        boolean hasQuery = query != null && !query.isBlank();
        String from = SqlSupport.userOwnedFrom(
                "equipment_scans", "s", "user_id", hasQuery
        );
        String where = where(status);
        Map<String, Object> params = params(query, status);
        long total = jdbc.sql("""
                SELECT COUNT(*)
                FROM """ + from + """
                JOIN users u ON u.id = s.user_id
                LEFT JOIN profiles p ON p.user_id = s.user_id
                """ + where).params(params).query(Long.class).optional().orElse(0L);
        List<ScanDtos.ScanListItem> items = jdbc.sql("""
                SELECT s.id, s.user_id, s.image_url, s.status, s.model, s.result, s.created_at,
                       COALESCE(NULLIF(p.nickname, ''), u.phone, u.username, s.user_id) AS user_label
                FROM """ + from + """
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

    public ScanDtos.ScanSummary summary() {
        long total = count("SELECT COUNT(*) FROM equipment_scans");
        long last7d = count("""
                SELECT COUNT(*) FROM equipment_scans
                WHERE created_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 7 DAY)
                """);
        long zeroCandidate = count("""
                SELECT COUNT(*) FROM equipment_scans
                WHERE COALESCE(JSON_LENGTH(result), 0) = 0
                """);
        long unavailable = count("""
                SELECT COUNT(*) FROM equipment_scans WHERE status = 'unavailable'
                """);
        double avgCandidates = jdbc.sql("""
                SELECT COALESCE(AVG(COALESCE(JSON_LENGTH(result), 0)), 0)
                FROM equipment_scans
                """).query(Double.class).optional().orElse(0.0);
        List<ScanDtos.ModelCount> models = jdbc.sql("""
                SELECT COALESCE(NULLIF(model, ''), 'unknown') AS model, COUNT(*) AS total
                FROM equipment_scans
                GROUP BY COALESCE(NULLIF(model, ''), 'unknown')
                ORDER BY total DESC
                """).query((rs, rowNum) -> new ScanDtos.ModelCount(
                rs.getString("model"),
                rs.getLong("total")
        )).list();
        List<ScanDtos.StatusCount> statuses = jdbc.sql("""
                SELECT status, COUNT(*) AS total
                FROM equipment_scans
                GROUP BY status
                ORDER BY total DESC
                """).query((rs, rowNum) -> new ScanDtos.StatusCount(
                rs.getString("status"),
                rs.getLong("total")
        )).list();
        Map<LocalDate, Long> raw = new HashMap<>();
        jdbc.sql("""
                SELECT DATE(created_at) AS day, COUNT(*) AS total
                FROM equipment_scans
                WHERE created_at >= DATE_SUB(CURDATE(), INTERVAL 13 DAY)
                GROUP BY DATE(created_at)
                """).query((rs, rowNum) -> {
            raw.put(rs.getDate("day").toLocalDate(), rs.getLong("total"));
            return null;
        }).list();
        LocalDate today = LocalDate.now(ZoneOffset.UTC);
        List<ScanDtos.DailyPoint> daily = new ArrayList<>();
        for (int i = 13; i >= 0; i--) {
            LocalDate day = today.minusDays(i);
            daily.add(new ScanDtos.DailyPoint(
                    day.toString(),
                    raw.getOrDefault(day, 0L)
            ));
        }
        double zeroRate = total == 0 ? 0 : (double) zeroCandidate / total;
        return new ScanDtos.ScanSummary(
                total, last7d, zeroCandidate, zeroRate, avgCandidates,
                unavailable, models, statuses, daily
        );
    }

    private long count(String sql) {
        return jdbc.sql(sql).query(Long.class).optional().orElse(0L);
    }

    private String where(String status) {
        List<String> clauses = new ArrayList<>();
        if (status != null && !status.isBlank()) {
            clauses.add("s.status = :status");
        }
        return clauses.isEmpty() ? "" : " WHERE " + String.join(" AND ", clauses) + " ";
    }

    private Map<String, Object> params(String query, String status) {
        Map<String, Object> params = new HashMap<>();
        if (query != null && !query.isBlank()) {
            SqlSupport.putSearchParams(params, query);
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
