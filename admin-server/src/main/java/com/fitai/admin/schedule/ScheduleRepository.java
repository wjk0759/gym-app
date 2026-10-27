package com.fitai.admin.schedule;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import com.fitai.admin.common.api.PageResponse;
import com.fitai.admin.common.persistence.SqlSupport;

@Repository
public class ScheduleRepository {

    private final JdbcClient jdbc;

    public ScheduleRepository(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    public PageResponse<ScheduleDtos.ScheduleStateItem> list(
            String query,
            String planId,
            int page,
            int size
    ) {
        int safePage = SqlSupport.page(page);
        int safeSize = SqlSupport.size(size);
        List<String> clauses = new ArrayList<>();
        Map<String, Object> params = new HashMap<>();
        if (planId != null && !planId.isBlank()) {
            clauses.add("s.plan_id = :planId");
            params.put("planId", planId.trim());
        }
        if (query != null && !query.isBlank()) {
            clauses.add("""
                    (LOWER(COALESCE(p.nickname, '')) LIKE :q
                     OR COALESCE(u.phone, '') LIKE :q
                     OR COALESCE(u.username, '') LIKE :q
                     OR s.user_id = :rawQuery
                     OR s.plan_id = :rawQuery
                     OR s.day_id = :rawQuery)
                    """);
            params.put("q", SqlSupport.like(query));
            params.put("rawQuery", query.trim());
        }
        String where = clauses.isEmpty() ? "" : " WHERE " + String.join(" AND ", clauses) + " ";
        long total = jdbc.sql("""
                SELECT COUNT(*) FROM plan_day_states s
                LEFT JOIN users u ON u.id = s.user_id
                LEFT JOIN profiles p ON p.user_id = s.user_id
                """ + where).params(params).query(Long.class).optional().orElse(0L);
        List<ScheduleDtos.ScheduleStateItem> items = jdbc.sql("""
                SELECT s.id, s.user_id, s.plan_id, s.plan_version, s.day_id,
                       s.assigned_date, s.skipped_at, s.client_updated_at, s.updated_at,
                       COALESCE(NULLIF(p.nickname, ''), u.phone, u.username, s.user_id) AS user_label
                FROM plan_day_states s
                LEFT JOIN users u ON u.id = s.user_id
                LEFT JOIN profiles p ON p.user_id = s.user_id
                """ + where + """
                ORDER BY s.updated_at DESC
                LIMIT :limit OFFSET :offset
                """).params(params)
                .param("limit", safeSize)
                .param("offset", SqlSupport.offset(safePage, safeSize))
                .query((rs, rowNum) -> new ScheduleDtos.ScheduleStateItem(
                        rs.getString("id"),
                        rs.getString("user_id"),
                        rs.getString("user_label"),
                        rs.getString("plan_id"),
                        (Integer) rs.getObject("plan_version"),
                        rs.getString("day_id"),
                        SqlSupport.iso(rs.getDate("assigned_date")),
                        SqlSupport.iso(rs.getTimestamp("skipped_at")),
                        SqlSupport.iso(rs.getTimestamp("client_updated_at")),
                        SqlSupport.iso(rs.getTimestamp("updated_at"))
                )).list();
        return PageResponse.of(items, safePage, safeSize, total);
    }
}
