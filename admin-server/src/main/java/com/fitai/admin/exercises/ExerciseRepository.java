package com.fitai.admin.exercises;

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
public class ExerciseRepository {

    private final JdbcClient jdbc;
    private final JsonCodec jsonCodec;

    public ExerciseRepository(JdbcClient jdbc, JsonCodec jsonCodec) {
        this.jdbc = jdbc;
        this.jsonCodec = jsonCodec;
    }

    public PageResponse<ExerciseDtos.ExerciseItem> list(
            String query,
            String muscleGroup,
            String equipment,
            int page,
            int size
    ) {
        int safePage = SqlSupport.page(page);
        int safeSize = SqlSupport.size(size);
        String where = where(query, muscleGroup, equipment);
        Map<String, Object> params = params(query, muscleGroup, equipment);
        long total = jdbc.sql("SELECT COUNT(*) FROM exercises" + where)
                .params(params).query(Long.class).optional().orElse(0L);
        List<ExerciseDtos.ExerciseItem> items = jdbc.sql("""
                SELECT slug, name_zh, name_en, muscle_group, equipment, is_compound, difficulty,
                       instructions, video_url, thumbnail_url, contraindications, source, license, created_at
                FROM exercises
                """ + where + """
                ORDER BY muscle_group, name_zh
                LIMIT :limit OFFSET :offset
                """).params(params)
                .param("limit", safeSize)
                .param("offset", SqlSupport.offset(safePage, safeSize))
                .query((rs, rowNum) -> new ExerciseDtos.ExerciseItem(
                        rs.getString("slug"),
                        rs.getString("name_zh"),
                        rs.getString("name_en"),
                        rs.getString("muscle_group"),
                        rs.getString("equipment"),
                        rs.getBoolean("is_compound"),
                        rs.getInt("difficulty"),
                        rs.getString("instructions"),
                        rs.getString("video_url"),
                        rs.getString("thumbnail_url"),
                        jsonCodec.parse(rs.getString("contraindications")),
                        rs.getString("source"),
                        rs.getString("license"),
                        SqlSupport.iso(rs.getTimestamp("created_at"))
                )).list();
        return PageResponse.of(items, safePage, safeSize, total);
    }

    public Optional<ExerciseDtos.ExerciseItem> find(String slug) {
        return jdbc.sql("""
                SELECT slug, name_zh, name_en, muscle_group, equipment, is_compound, difficulty,
                       instructions, video_url, thumbnail_url, contraindications, source, license, created_at
                FROM exercises WHERE slug = :slug
                """).param("slug", slug).query((rs, rowNum) -> new ExerciseDtos.ExerciseItem(
                rs.getString("slug"),
                rs.getString("name_zh"),
                rs.getString("name_en"),
                rs.getString("muscle_group"),
                rs.getString("equipment"),
                rs.getBoolean("is_compound"),
                rs.getInt("difficulty"),
                rs.getString("instructions"),
                rs.getString("video_url"),
                rs.getString("thumbnail_url"),
                jsonCodec.parse(rs.getString("contraindications")),
                rs.getString("source"),
                rs.getString("license"),
                SqlSupport.iso(rs.getTimestamp("created_at"))
        )).optional();
    }

    public boolean update(String slug, ExerciseDtos.PatchExerciseRequest request) {
        Map<String, Object> values = new LinkedHashMap<>();
        if (request.nameZh() != null) values.put("name_zh", request.nameZh());
        if (request.nameEn() != null) values.put("name_en", request.nameEn());
        if (request.muscleGroup() != null) values.put("muscle_group", request.muscleGroup());
        if (request.equipment() != null) values.put("equipment", request.equipment());
        if (request.compound() != null) values.put("is_compound", request.compound());
        if (request.difficulty() != null) values.put("difficulty", request.difficulty());
        if (request.instructions() != null) values.put("instructions", request.instructions());
        if (request.videoUrl() != null) values.put("video_url", request.videoUrl());
        if (request.thumbnailUrl() != null) values.put("thumbnail_url", request.thumbnailUrl());
        if (request.contraindications() != null) {
            values.put("contraindications", jsonCodec.write(request.contraindications()));
        }
        if (request.source() != null) values.put("source", request.source());
        if (request.license() != null) values.put("license", request.license());
        if (values.isEmpty()) {
            return false;
        }
        List<String> assignments = new ArrayList<>();
        values.keySet().forEach(column -> assignments.add(column + " = :" + column));
        Map<String, Object> params = new HashMap<>(values);
        params.put("slug", slug);
        return jdbc.sql("UPDATE exercises SET " + String.join(", ", assignments) + " WHERE slug = :slug")
                .params(params)
                .update() > 0;
    }

    private String where(String query, String muscleGroup, String equipment) {
        List<String> clauses = new ArrayList<>();
        if (query != null && !query.isBlank()) {
            clauses.add("(LOWER(name_zh) LIKE :q OR LOWER(COALESCE(name_en, '')) LIKE :q OR slug LIKE :q)");
        }
        if (muscleGroup != null && !muscleGroup.isBlank()) {
            clauses.add("muscle_group = :muscleGroup");
        }
        if (equipment != null && !equipment.isBlank()) {
            clauses.add("equipment = :equipment");
        }
        return clauses.isEmpty() ? "" : " WHERE " + String.join(" AND ", clauses) + " ";
    }

    private Map<String, Object> params(String query, String muscleGroup, String equipment) {
        Map<String, Object> params = new HashMap<>();
        if (query != null && !query.isBlank()) params.put("q", SqlSupport.like(query));
        if (muscleGroup != null && !muscleGroup.isBlank()) params.put("muscleGroup", muscleGroup);
        if (equipment != null && !equipment.isBlank()) params.put("equipment", equipment);
        return params;
    }
}
