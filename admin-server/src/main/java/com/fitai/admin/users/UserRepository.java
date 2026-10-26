package com.fitai.admin.users;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import com.fitai.admin.common.api.PageResponse;
import com.fitai.admin.common.persistence.JsonCodec;
import com.fitai.admin.common.persistence.SqlSupport;

@Repository
public class UserRepository {

    private final JdbcClient jdbc;
    private final JsonCodec jsonCodec;

    public UserRepository(JdbcClient jdbc, JsonCodec jsonCodec) {
        this.jdbc = jdbc;
        this.jsonCodec = jsonCodec;
    }

    public PageResponse<UserDtos.UserListItem> list(
            String query,
            String status,
            boolean includeDeleted,
            int page,
            int size
    ) {
        int safePage = SqlSupport.page(page);
        int safeSize = SqlSupport.size(size);
        String where = where(query, status, includeDeleted);
        Map<String, Object> params = params(query, status);
        long total = jdbc.sql("SELECT COUNT(*) FROM users u LEFT JOIN profiles p ON p.user_id = u.id " + where)
                .params(params)
                .query(Long.class)
                .optional()
                .orElse(0L);
        List<UserDtos.UserListItem> items = jdbc.sql("""
                SELECT u.id, u.phone, u.username, u.status, u.created_at, u.last_login_at, u.deleted_at,
                       p.nickname, p.sex, p.weekly_days, g.type AS goal_type,
                       (SELECT COUNT(*) FROM workout_sessions ws WHERE ws.user_id = u.id) AS workout_count
                FROM users u
                LEFT JOIN profiles p ON p.user_id = u.id
                LEFT JOIN goals g ON g.user_id = u.id AND g.status = 'active'
                """ + where + """
                ORDER BY u.created_at DESC
                LIMIT :limit OFFSET :offset
                """)
                .params(params)
                .param("limit", safeSize)
                .param("offset", SqlSupport.offset(safePage, safeSize))
                .query((rs, rowNum) -> mapListItem(rs))
                .list();
        return PageResponse.of(items, safePage, safeSize, total);
    }

    public Optional<UserDtos.UserDetail> detail(String id) {
        Map<String, Object> userRow = jdbc.sql("""
                SELECT u.id, u.phone, u.username, u.status, u.created_at, u.last_login_at, u.deleted_at,
                       p.nickname, p.sex, p.weekly_days, g.type AS goal_type,
                       (SELECT COUNT(*) FROM workout_sessions ws WHERE ws.user_id = u.id) AS workout_count
                FROM users u
                LEFT JOIN profiles p ON p.user_id = u.id
                LEFT JOIN goals g ON g.user_id = u.id AND g.status = 'active'
                WHERE u.id = :id
                LIMIT 1
                """).param("id", id).query().listOfRows().stream().findFirst().orElse(null);
        if (userRow == null) {
            return Optional.empty();
        }
        UserDtos.UserListItem item = mapListItemRow(userRow);
        Map<String, Object> profile = jdbc.sql("""
                SELECT nickname, sex, birth_date, height_cm, weight_kg, body_fat_pct, chest_cm,
                       waist_cm, hip_cm, experience, injuries, equipment, weekly_days,
                       session_minutes, onboarded_at, updated_at
                FROM profiles WHERE user_id = :id
                """).param("id", id).query().listOfRows().stream().findFirst().map(this::mapProfile).orElse(Map.of());
        Map<String, Object> goal = jdbc.sql("""
                SELECT type, target_weight_kg, target_body_fat_pct, target_waist_cm, target_date,
                       status, created_at
                FROM goals WHERE user_id = :id AND status = 'active'
                ORDER BY created_at DESC LIMIT 1
                """).param("id", id).query().listOfRows().stream().findFirst().map(row -> {
                    Map<String, Object> map = new LinkedHashMap<>();
                    map.put("type", row.get("type"));
                    map.put("targetWeightKg", number(row.get("target_weight_kg")));
                    map.put("targetBodyFatPct", number(row.get("target_body_fat_pct")));
                    map.put("targetWaistCm", number(row.get("target_waist_cm")));
                    map.put("targetDate", SqlSupport.iso(row.get("target_date")));
                    map.put("status", row.get("status"));
                    map.put("createdAt", SqlSupport.iso(row.get("created_at")));
                    return map;
                }).orElse(Map.of());

        List<UserDtos.ProgramBrief> programs = jdbc.sql("""
                SELECT id, title, status, version, start_date, weeks, created_at
                FROM programs WHERE user_id = :id ORDER BY created_at DESC LIMIT 20
                """).param("id", id).query((rs, rowNum) -> new UserDtos.ProgramBrief(
                rs.getString("id"),
                rs.getString("title"),
                rs.getString("status"),
                rs.getInt("version"),
                SqlSupport.iso(rs.getDate("start_date")),
                rs.getInt("weeks"),
                SqlSupport.iso(rs.getTimestamp("created_at"))
        )).list();
        List<UserDtos.WorkoutBrief> workouts = jdbc.sql("""
                SELECT id, started_at, duration_min, feeling
                FROM workout_sessions WHERE user_id = :id ORDER BY started_at DESC LIMIT 20
                """).param("id", id).query((rs, rowNum) -> new UserDtos.WorkoutBrief(
                rs.getString("id"),
                SqlSupport.iso(rs.getTimestamp("started_at")),
                (Integer) rs.getObject("duration_min"),
                (Integer) rs.getObject("feeling")
        )).list();
        List<UserDtos.ChatBrief> chats = jdbc.sql("""
                SELECT c.id, c.title, c.created_at,
                       (SELECT COUNT(*) FROM chat_messages m WHERE m.session_id = c.id) AS message_count
                FROM chat_sessions c WHERE c.user_id = :id ORDER BY c.created_at DESC LIMIT 20
                """).param("id", id).query((rs, rowNum) -> new UserDtos.ChatBrief(
                rs.getString("id"),
                rs.getString("title"),
                SqlSupport.iso(rs.getTimestamp("created_at")),
                rs.getLong("message_count")
        )).list();
        return Optional.of(new UserDtos.UserDetail(item, profile, goal, programs, workouts, chats));
    }

    public boolean exists(String id) {
        return jdbc.sql("SELECT COUNT(*) FROM users WHERE id = :id").param("id", id)
                .query(Long.class).optional().orElse(0L) > 0;
    }

    public boolean setStatus(String id, String status) {
        return jdbc.sql("""
                UPDATE users SET status = :status, updated_at = UTC_TIMESTAMP()
                WHERE id = :id AND deleted_at IS NULL
                """).param("status", status).param("id", id).update() > 0;
    }

    public boolean softDelete(String id) {
        return jdbc.sql("""
                UPDATE users
                SET status = 'deleted', deleted_at = UTC_TIMESTAMP(), updated_at = UTC_TIMESTAMP()
                WHERE id = :id AND deleted_at IS NULL
                """).param("id", id).update() > 0;
    }

    public boolean restore(String id) {
        return jdbc.sql("""
                UPDATE users
                SET status = 'active', deleted_at = NULL, updated_at = UTC_TIMESTAMP()
                WHERE id = :id AND deleted_at IS NOT NULL
                """).param("id", id).update() > 0;
    }

    private String where(String query, String status, boolean includeDeleted) {
        List<String> clauses = new ArrayList<>();
        if (!includeDeleted) {
            clauses.add("u.deleted_at IS NULL");
        }
        if (status != null && !status.isBlank()) {
            clauses.add("u.status = :status");
        }
        if (query != null && !query.isBlank()) {
            clauses.add("""
                    (LOWER(COALESCE(p.nickname, '')) LIKE :q
                     OR LOWER(COALESCE(u.username, '')) LIKE :q
                     OR COALESCE(u.phone, '') LIKE :q
                     OR u.id = :rawQuery)
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

    private UserDtos.UserListItem mapListItem(java.sql.ResultSet rs) throws java.sql.SQLException {
        Map<String, Object> row = new LinkedHashMap<>();
        row.put("id", rs.getString("id"));
        row.put("phone", rs.getString("phone"));
        row.put("username", rs.getString("username"));
        row.put("status", rs.getString("status"));
        row.put("created_at", rs.getTimestamp("created_at"));
        row.put("last_login_at", rs.getTimestamp("last_login_at"));
        row.put("deleted_at", rs.getTimestamp("deleted_at"));
        row.put("nickname", rs.getString("nickname"));
        row.put("sex", rs.getString("sex"));
        row.put("weekly_days", rs.getObject("weekly_days"));
        row.put("goal_type", rs.getString("goal_type"));
        row.put("workout_count", rs.getLong("workout_count"));
        return mapListItemRow(row);
    }

    private UserDtos.UserListItem mapListItemRow(Map<String, Object> row) {
        Object weekly = row.get("weekly_days");
        return new UserDtos.UserListItem(
                string(row.get("id")),
                string(row.get("phone")),
                string(row.get("username")),
                string(row.get("nickname")),
                string(row.get("status")),
                string(row.get("sex")),
                SqlSupport.iso(row.get("created_at")),
                SqlSupport.iso(row.get("last_login_at")),
                weekly instanceof Number number ? number.intValue() : null,
                string(row.get("goal_type")),
                SqlSupport.longValue(row.get("workout_count")),
                row.get("deleted_at") != null
        );
    }

    private Map<String, Object> mapProfile(Map<String, Object> row) {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("nickname", row.get("nickname"));
        map.put("sex", row.get("sex"));
        map.put("birthDate", SqlSupport.iso(row.get("birth_date")));
        map.put("heightCm", number(row.get("height_cm")));
        map.put("weightKg", number(row.get("weight_kg")));
        map.put("bodyFatPct", number(row.get("body_fat_pct")));
        map.put("chestCm", number(row.get("chest_cm")));
        map.put("waistCm", number(row.get("waist_cm")));
        map.put("hipCm", number(row.get("hip_cm")));
        map.put("experience", row.get("experience"));
        map.put("injuries", jsonCodec.parse(row.get("injuries")));
        map.put("equipment", jsonCodec.parse(row.get("equipment")));
        map.put("weeklyDays", row.get("weekly_days"));
        map.put("sessionMinutes", row.get("session_minutes"));
        map.put("onboardedAt", SqlSupport.iso(row.get("onboarded_at")));
        map.put("updatedAt", SqlSupport.iso(row.get("updated_at")));
        return map;
    }

    private Object number(Object value) {
        return value instanceof java.math.BigDecimal decimal ? decimal.doubleValue() : value;
    }

    private String string(Object value) {
        return value == null ? null : value.toString();
    }
}

