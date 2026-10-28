package com.fitai.admin.equipment;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import com.fitai.admin.common.api.PageResponse;
import com.fitai.admin.common.persistence.SqlSupport;

/**
 * Read-only view of users' personal equipment/action library, including
 * custom entries added after photo recognition reported "not in library".
 */
@Repository
public class EquipmentLibraryRepository {

    private final JdbcClient jdbc;

    public EquipmentLibraryRepository(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    public PageResponse<EquipmentLibraryDtos.Item> list(
            String query,
            String source,
            int page,
            int size
    ) {
        int safePage = SqlSupport.page(page);
        int safeSize = SqlSupport.size(size);
        String where = where(query, source);
        Map<String, Object> params = params(query, source);

        long total = jdbc.sql("SELECT COUNT(*) FROM equipment_library e LEFT JOIN users u ON u.id = e.user_id" + where)
                .params(params).query(Long.class).optional().orElse(0L);

        List<EquipmentLibraryDtos.Item> items = jdbc.sql("""
                SELECT e.id, e.user_id, e.client_id, e.name, e.slug, e.muscle, e.equipment,
                       e.notes, e.source, e.created_at, u.phone, u.username
                FROM equipment_library e
                LEFT JOIN users u ON u.id = e.user_id
                """ + where + """
                ORDER BY e.created_at DESC
                LIMIT :limit OFFSET :offset
                """).params(params)
                .param("limit", safeSize)
                .param("offset", SqlSupport.offset(safePage, safeSize))
                .query((rs, rowNum) -> new EquipmentLibraryDtos.Item(
                        rs.getString("id"),
                        rs.getString("user_id"),
                        rs.getString("phone"),
                        rs.getString("username"),
                        rs.getString("client_id"),
                        rs.getString("name"),
                        rs.getString("slug"),
                        rs.getString("muscle"),
                        rs.getString("equipment"),
                        rs.getString("notes"),
                        rs.getString("source"),
                        SqlSupport.iso(rs.getTimestamp("created_at"))
                )).list();

        return PageResponse.of(items, safePage, safeSize, total);
    }

    private String where(String query, String source) {
        List<String> clauses = new ArrayList<>();
        if (query != null && !query.isBlank()) {
            clauses.add("(LOWER(e.name) LIKE :q OR LOWER(COALESCE(e.notes, '')) LIKE :q "
                    + "OR LOWER(COALESCE(u.phone, '')) LIKE :q OR LOWER(COALESCE(u.username, '')) LIKE :q)");
        }
        if (source != null && !source.isBlank()) {
            clauses.add("e.source = :source");
        }
        return clauses.isEmpty() ? "" : " WHERE " + String.join(" AND ", clauses) + " ";
    }

    private Map<String, Object> params(String query, String source) {
        Map<String, Object> params = new HashMap<>();
        if (query != null && !query.isBlank()) {
            params.put("q", SqlSupport.like(query));
        }
        if (source != null && !source.isBlank()) {
            params.put("source", source);
        }
        return params;
    }
}
