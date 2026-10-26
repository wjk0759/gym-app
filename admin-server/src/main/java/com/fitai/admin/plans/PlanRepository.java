package com.fitai.admin.plans;

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
public class PlanRepository {

    private final JdbcClient jdbc;
    private final JsonCodec jsonCodec;

    public PlanRepository(JdbcClient jdbc, JsonCodec jsonCodec) {
        this.jdbc = jdbc;
        this.jsonCodec = jsonCodec;
    }

    public PageResponse<PlanDtos.PlanListItem> list(String query, String status, int page, int size) {
        int safePage = SqlSupport.page(page);
        int safeSize = SqlSupport.size(size);
        String where = where(query, status);
        Map<String, Object> params = params(query, status);
        long total = jdbc.sql("""
                SELECT COUNT(*)
                FROM programs p
                JOIN users u ON u.id = p.user_id
                LEFT JOIN profiles pr ON pr.user_id = p.user_id
                """ + where).params(params).query(Long.class).optional().orElse(0L);
        List<PlanDtos.PlanListItem> items = jdbc.sql("""
                SELECT p.id, p.user_id, p.title, p.goal_type, p.version, p.status,
                       p.start_date, p.weeks, p.created_at,
                       COALESCE(NULLIF(pr.nickname, ''), u.phone, u.username, p.user_id) AS user_label,
                       (SELECT COUNT(*) FROM program_days d WHERE d.program_id = p.id) AS day_count,
                       (SELECT COUNT(*)
                          FROM plan_exercises e
                          JOIN program_days d2 ON d2.id = e.program_day_id
                         WHERE d2.program_id = p.id) AS exercise_count
                FROM programs p
                JOIN users u ON u.id = p.user_id
                LEFT JOIN profiles pr ON pr.user_id = p.user_id
                """ + where + """
                ORDER BY p.created_at DESC
                LIMIT :limit OFFSET :offset
                """).params(params)
                .param("limit", safeSize)
                .param("offset", SqlSupport.offset(safePage, safeSize))
                .query((rs, rowNum) -> mapPlan(rs))
                .list();
        return PageResponse.of(items, safePage, safeSize, total);
    }

    public Optional<PlanDtos.PlanDetail> detail(String id) {
        Optional<PlanDtos.PlanListItem> plan = jdbc.sql("""
                SELECT p.id, p.user_id, p.title, p.goal_type, p.version, p.status,
                       p.start_date, p.weeks, p.created_at,
                       COALESCE(NULLIF(pr.nickname, ''), u.phone, u.username, p.user_id) AS user_label,
                       (SELECT COUNT(*) FROM program_days d WHERE d.program_id = p.id) AS day_count,
                       (SELECT COUNT(*)
                          FROM plan_exercises e
                          JOIN program_days d2 ON d2.id = e.program_day_id
                         WHERE d2.program_id = p.id) AS exercise_count
                FROM programs p
                JOIN users u ON u.id = p.user_id
                LEFT JOIN profiles pr ON pr.user_id = p.user_id
                WHERE p.id = :id
                """).param("id", id).query((rs, rowNum) -> mapPlan(rs)).optional();
        if (plan.isEmpty()) {
            return Optional.empty();
        }
        List<Map<String, Object>> dayRows = jdbc.sql("""
                SELECT id, week_index, weekday, title, focus
                FROM program_days WHERE program_id = :id
                ORDER BY week_index, weekday
                """).param("id", id).query().listOfRows();
        List<PlanDtos.PlanDay> days = new ArrayList<>();
        for (Map<String, Object> row : dayRows) {
            String dayId = String.valueOf(row.get("id"));
            List<PlanDtos.PlanExerciseItem> exercises = jdbc.sql("""
                    SELECT e.id, e.exercise_slug, x.name_zh, x.muscle_group, x.equipment,
                           e.sets, e.reps, e.weight_kg, e.rest_sec, e.rpe, e.notes
                    FROM plan_exercises e
                    JOIN exercises x ON x.slug = e.exercise_slug
                    WHERE e.program_day_id = :dayId
                    ORDER BY e.order_index
                    """).param("dayId", dayId).query((rs, rowNum) -> new PlanDtos.PlanExerciseItem(
                    rs.getString("id"),
                    rs.getString("exercise_slug"),
                    rs.getString("name_zh"),
                    rs.getString("muscle_group"),
                    rs.getString("equipment"),
                    rs.getInt("sets"),
                    rs.getString("reps"),
                    rs.getObject("weight_kg"),
                    rs.getInt("rest_sec"),
                    rs.getObject("rpe"),
                    rs.getString("notes")
            )).list();
            days.add(new PlanDtos.PlanDay(
                    dayId,
                    ((Number) row.get("week_index")).intValue(),
                    ((Number) row.get("weekday")).intValue(),
                    String.valueOf(row.get("title")),
                    jsonCodec.parse(row.get("focus")),
                    exercises
            ));
        }
        return Optional.of(new PlanDtos.PlanDetail(plan.get(), days));
    }

    public boolean archive(String id) {
        return jdbc.sql("UPDATE programs SET status = 'archived' WHERE id = :id").param("id", id).update() > 0;
    }

    public boolean activate(String id) {
        String userId = jdbc.sql("SELECT user_id FROM programs WHERE id = :id")
                .param("id", id).query(String.class).optional().orElse(null);
        if (userId == null) {
            return false;
        }
        jdbc.sql("""
                UPDATE programs SET status = 'archived'
                WHERE user_id = :userId AND status = 'active'
                """).param("userId", userId).update();
        return jdbc.sql("UPDATE programs SET status = 'active' WHERE id = :id")
                .param("id", id).update() > 0;
    }

    private String where(String query, String status) {
        List<String> clauses = new ArrayList<>();
        if (status != null && !status.isBlank()) {
            clauses.add("p.status = :status");
        }
        if (query != null && !query.isBlank()) {
            clauses.add("""
                    (LOWER(p.title) LIKE :q
                     OR LOWER(COALESCE(pr.nickname, '')) LIKE :q
                     OR COALESCE(u.phone, '') LIKE :q
                     OR p.user_id = :rawQuery)
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

    private PlanDtos.PlanListItem mapPlan(java.sql.ResultSet rs) throws java.sql.SQLException {
        return new PlanDtos.PlanListItem(
                rs.getString("id"),
                rs.getString("user_id"),
                rs.getString("user_label"),
                rs.getString("title"),
                rs.getString("goal_type"),
                rs.getInt("version"),
                rs.getString("status"),
                SqlSupport.iso(rs.getDate("start_date")),
                rs.getInt("weeks"),
                rs.getInt("day_count"),
                rs.getInt("exercise_count"),
                SqlSupport.iso(rs.getTimestamp("created_at"))
        );
    }
}

