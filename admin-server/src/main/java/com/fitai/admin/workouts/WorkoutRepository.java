package com.fitai.admin.workouts;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import com.fitai.admin.common.api.PageResponse;
import com.fitai.admin.common.persistence.SqlSupport;

@Repository
public class WorkoutRepository {

    private final JdbcClient jdbc;

    public WorkoutRepository(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    public PageResponse<WorkoutDtos.WorkoutListItem> list(String query, int page, int size) {
        int safePage = SqlSupport.page(page);
        int safeSize = SqlSupport.size(size);
        String where = where(query);
        Map<String, Object> params = params(query);
        long total = jdbc.sql("""
                SELECT COUNT(*)
                FROM workout_sessions w
                JOIN users u ON u.id = w.user_id
                LEFT JOIN profiles p ON p.user_id = w.user_id
                """ + where).params(params).query(Long.class).optional().orElse(0L);
        List<WorkoutDtos.WorkoutListItem> items = jdbc.sql("""
                SELECT w.id, w.user_id, w.started_at, w.finished_at, w.duration_min, w.feeling,
                       COALESCE(NULLIF(p.nickname, ''), u.phone, u.username, w.user_id) AS user_label,
                       (SELECT COUNT(DISTINCT s.exercise_slug) FROM set_logs s WHERE s.session_id = w.id) AS exercise_count,
                       (SELECT COUNT(*) FROM set_logs s WHERE s.session_id = w.id) AS set_count,
                       (SELECT COALESCE(SUM(COALESCE(s.weight_kg, 0) * COALESCE(s.reps, 0)), 0)
                          FROM set_logs s WHERE s.session_id = w.id AND s.completed = 1) AS volume_kg
                FROM workout_sessions w
                JOIN users u ON u.id = w.user_id
                LEFT JOIN profiles p ON p.user_id = w.user_id
                """ + where + """
                ORDER BY w.started_at DESC
                LIMIT :limit OFFSET :offset
                """).params(params)
                .param("limit", safeSize)
                .param("offset", SqlSupport.offset(safePage, safeSize))
                .query((rs, rowNum) -> mapWorkout(rs))
                .list();
        return PageResponse.of(items, safePage, safeSize, total);
    }

    public Optional<WorkoutDtos.WorkoutDetail> detail(String id) {
        Optional<WorkoutDtos.WorkoutListItem> workout = jdbc.sql("""
                SELECT w.id, w.user_id, w.started_at, w.finished_at, w.duration_min, w.feeling,
                       COALESCE(NULLIF(p.nickname, ''), u.phone, u.username, w.user_id) AS user_label,
                       (SELECT COUNT(DISTINCT s.exercise_slug) FROM set_logs s WHERE s.session_id = w.id) AS exercise_count,
                       (SELECT COUNT(*) FROM set_logs s WHERE s.session_id = w.id) AS set_count,
                       (SELECT COALESCE(SUM(COALESCE(s.weight_kg, 0) * COALESCE(s.reps, 0)), 0)
                          FROM set_logs s WHERE s.session_id = w.id AND s.completed = 1) AS volume_kg
                FROM workout_sessions w
                JOIN users u ON u.id = w.user_id
                LEFT JOIN profiles p ON p.user_id = w.user_id
                WHERE w.id = :id
                """).param("id", id).query((rs, rowNum) -> mapWorkout(rs)).optional();
        if (workout.isEmpty()) {
            return Optional.empty();
        }
        List<WorkoutDtos.WorkoutSetItem> sets = jdbc.sql("""
                SELECT s.id, s.exercise_slug, e.name_zh, s.set_index, s.weight_kg, s.reps,
                       s.rpe, s.completed, s.created_at
                FROM set_logs s
                LEFT JOIN exercises e ON e.slug = s.exercise_slug
                WHERE s.session_id = :id
                ORDER BY s.exercise_slug, s.set_index
                """).param("id", id).query((rs, rowNum) -> new WorkoutDtos.WorkoutSetItem(
                rs.getString("id"),
                rs.getString("exercise_slug"),
                rs.getString("name_zh"),
                rs.getInt("set_index"),
                rs.getObject("weight_kg"),
                (Integer) rs.getObject("reps"),
                rs.getObject("rpe"),
                rs.getBoolean("completed"),
                SqlSupport.iso(rs.getTimestamp("created_at"))
        )).list();
        return Optional.of(new WorkoutDtos.WorkoutDetail(workout.get(), sets));
    }

    public boolean delete(String id) {
        return jdbc.sql("DELETE FROM workout_sessions WHERE id = :id").param("id", id).update() > 0;
    }

    private String where(String query) {
        if (query == null || query.isBlank()) {
            return "";
        }
        return """
                 WHERE (u.id = :rawQuery
                        OR COALESCE(u.phone, '') LIKE :q
                        OR LOWER(COALESCE(p.nickname, '')) LIKE :q
                        OR LOWER(COALESCE(u.username, '')) LIKE :q)
                """ + " ";
    }

    private Map<String, Object> params(String query) {
        Map<String, Object> params = new HashMap<>();
        if (query != null && !query.isBlank()) {
            params.put("q", SqlSupport.like(query));
            params.put("rawQuery", query.trim());
        }
        return params;
    }

    private WorkoutDtos.WorkoutListItem mapWorkout(java.sql.ResultSet rs) throws java.sql.SQLException {
        return new WorkoutDtos.WorkoutListItem(
                rs.getString("id"),
                rs.getString("user_id"),
                rs.getString("user_label"),
                SqlSupport.iso(rs.getTimestamp("started_at")),
                SqlSupport.iso(rs.getTimestamp("finished_at")),
                (Integer) rs.getObject("duration_min"),
                (Integer) rs.getObject("feeling"),
                rs.getInt("exercise_count"),
                rs.getInt("set_count"),
                rs.getDouble("volume_kg")
        );
    }
}
