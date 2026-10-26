package com.fitai.admin.videos;

import java.sql.Date;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import com.fitai.admin.common.api.PageResponse;
import com.fitai.admin.common.persistence.SqlSupport;

@Repository
public class VideoRepository {

    private final JdbcClient jdbc;

    public VideoRepository(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    public PageResponse<VideoDtos.VideoItem> list(
            String query,
            String status,
            String exerciseSlug,
            int page,
            int size
    ) {
        int safePage = SqlSupport.page(page);
        int safeSize = SqlSupport.size(size);
        List<String> clauses = new ArrayList<>();
        Map<String, Object> params = new HashMap<>();
        if (query != null && !query.isBlank()) {
            clauses.add("(LOWER(v.title) LIKE :q OR LOWER(e.name_zh) LIKE :q OR v.exercise_slug LIKE :q)");
            params.put("q", SqlSupport.like(query));
        }
        if (status != null && !status.isBlank()) {
            clauses.add("v.status = :status");
            params.put("status", status);
        }
        if (exerciseSlug != null && !exerciseSlug.isBlank()) {
            clauses.add("v.exercise_slug = :exerciseSlug");
            params.put("exerciseSlug", exerciseSlug);
        }
        String where = clauses.isEmpty() ? "" : " WHERE " + String.join(" AND ", clauses) + " ";
        long total = jdbc.sql("""
                SELECT COUNT(*) FROM exercise_videos v
                JOIN exercises e ON e.slug = v.exercise_slug
                """ + where).params(params).query(Long.class).optional().orElse(0L);
        List<VideoDtos.VideoItem> items = jdbc.sql("""
                SELECT v.id, v.exercise_slug, e.name_zh AS exercise_name, v.title, v.description,
                       v.video_url, v.poster_url, v.duration_seconds, v.source, v.license_note,
                       v.license_expires_at, v.status, v.version, v.created_by, v.created_at, v.updated_at
                FROM exercise_videos v
                JOIN exercises e ON e.slug = v.exercise_slug
                """ + where + """
                ORDER BY v.updated_at DESC
                LIMIT :limit OFFSET :offset
                """).params(params)
                .param("limit", safeSize)
                .param("offset", SqlSupport.offset(safePage, safeSize))
                .query((rs, rowNum) -> mapVideo(rs))
                .list();
        return PageResponse.of(items, safePage, safeSize, total);
    }

    public Optional<VideoDtos.VideoItem> find(String id) {
        return jdbc.sql("""
                SELECT v.id, v.exercise_slug, e.name_zh AS exercise_name, v.title, v.description,
                       v.video_url, v.poster_url, v.duration_seconds, v.source, v.license_note,
                       v.license_expires_at, v.status, v.version, v.created_by, v.created_at, v.updated_at
                FROM exercise_videos v
                JOIN exercises e ON e.slug = v.exercise_slug
                WHERE v.id = :id
                """).param("id", id).query((rs, rowNum) -> mapVideo(rs)).optional();
    }

    public boolean exerciseExists(String slug) {
        return jdbc.sql("SELECT COUNT(*) FROM exercises WHERE slug = :slug")
                .param("slug", slug).query(Long.class).optional().orElse(0L) > 0;
    }

    public String create(VideoDtos.CreateVideoRequest request, String createdBy, String status) {
        String id = UUID.randomUUID().toString();
        Timestamp now = Timestamp.from(Instant.now());
        jdbc.sql("""
                INSERT INTO exercise_videos
                    (id, exercise_slug, title, description, video_url, poster_url, duration_seconds,
                     source, license_note, license_expires_at, status, version, created_by, created_at, updated_at)
                VALUES
                    (:id, :exerciseSlug, :title, :description, :videoUrl, :posterUrl, :durationSeconds,
                     :source, :licenseNote, :licenseExpiresAt, :status, 1, :createdBy, :now, :now)
                """)
                .param("id", id)
                .param("exerciseSlug", request.exerciseSlug())
                .param("title", request.title().trim())
                .param("description", blankToNull(request.description()))
                .param("videoUrl", request.videoUrl().trim())
                .param("posterUrl", blankToNull(request.posterUrl()))
                .param("durationSeconds", request.durationSeconds())
                .param("source", blankToNull(request.source()))
                .param("licenseNote", blankToNull(request.licenseNote()))
                .param("licenseExpiresAt", request.licenseExpiresAt() == null ? null : Date.valueOf(request.licenseExpiresAt()))
                .param("status", status)
                .param("createdBy", createdBy)
                .param("now", now)
                .update();
        return id;
    }

    public boolean update(String id, VideoDtos.UpdateVideoRequest request) {
        Map<String, Object> values = new LinkedHashMap<>();
        if (request.title() != null) values.put("title", request.title().trim());
        if (request.description() != null) values.put("description", blankToNull(request.description()));
        if (request.videoUrl() != null) values.put("video_url", request.videoUrl().trim());
        if (request.posterUrl() != null) values.put("poster_url", blankToNull(request.posterUrl()));
        if (request.durationSeconds() != null) values.put("duration_seconds", request.durationSeconds());
        if (request.source() != null) values.put("source", blankToNull(request.source()));
        if (request.licenseNote() != null) values.put("license_note", blankToNull(request.licenseNote()));
        if (request.licenseExpiresAt() != null) {
            values.put("license_expires_at", Date.valueOf(request.licenseExpiresAt()));
        }
        if (values.isEmpty()) {
            return false;
        }
        List<String> assignments = new ArrayList<>();
        values.keySet().forEach(column -> assignments.add(column + " = :" + column));
        Map<String, Object> params = new HashMap<>(values);
        params.put("id", id);
        return jdbc.sql("""
                UPDATE exercise_videos
                SET %s, updated_at = UTC_TIMESTAMP(), version = version + 1
                WHERE id = :id
                """.formatted(String.join(", ", assignments)))
                .params(params).update() > 0;
    }

    public void publish(String id) {
        Map<String, Object> row = jdbc.sql("SELECT exercise_slug FROM exercise_videos WHERE id = :id")
                .param("id", id).query().listOfRows().stream().findFirst().orElseThrow();
        String slug = String.valueOf(row.get("exercise_slug"));
        jdbc.sql("""
                UPDATE exercise_videos
                SET status = 'archived', updated_at = UTC_TIMESTAMP()
                WHERE exercise_slug = :slug AND id <> :id AND status = 'published'
                """).param("slug", slug).param("id", id).update();
        jdbc.sql("""
                UPDATE exercise_videos
                SET status = 'published', updated_at = UTC_TIMESTAMP()
                WHERE id = :id
                """).param("id", id).update();
        syncExerciseVideo(slug);
    }

    public void unpublish(String id) {
        Map<String, Object> row = jdbc.sql("SELECT exercise_slug FROM exercise_videos WHERE id = :id")
                .param("id", id).query().listOfRows().stream().findFirst().orElseThrow();
        String slug = String.valueOf(row.get("exercise_slug"));
        jdbc.sql("""
                UPDATE exercise_videos
                SET status = 'draft', updated_at = UTC_TIMESTAMP()
                WHERE id = :id
                """).param("id", id).update();
        syncExerciseVideo(slug);
    }

    public void syncExerciseVideo(String slug) {
        Map<String, Object> row = jdbc.sql("""
                SELECT video_url, poster_url
                FROM exercise_videos
                WHERE exercise_slug = :slug AND status = 'published'
                ORDER BY updated_at DESC
                LIMIT 1
                """).param("slug", slug).query().listOfRows().stream().findFirst().orElse(null);
        if (row == null) {
            jdbc.sql("UPDATE exercises SET video_url = NULL, thumbnail_url = NULL WHERE slug = :slug")
                    .param("slug", slug).update();
        } else {
            jdbc.sql("""
                    UPDATE exercises SET video_url = :videoUrl, thumbnail_url = :posterUrl
                    WHERE slug = :slug
                    """)
                    .param("videoUrl", row.get("video_url"))
                    .param("posterUrl", row.get("poster_url"))
                    .param("slug", slug)
                    .update();
        }
    }

    public boolean delete(String id) {
        return jdbc.sql("DELETE FROM exercise_videos WHERE id = :id").param("id", id).update() > 0;
    }

    private VideoDtos.VideoItem mapVideo(java.sql.ResultSet rs) throws java.sql.SQLException {
        Date licenseDate = rs.getDate("license_expires_at");
        return new VideoDtos.VideoItem(
                rs.getString("id"),
                rs.getString("exercise_slug"),
                rs.getString("exercise_name"),
                rs.getString("title"),
                rs.getString("description"),
                rs.getString("video_url"),
                rs.getString("poster_url"),
                (Integer) rs.getObject("duration_seconds"),
                rs.getString("source"),
                rs.getString("license_note"),
                licenseDate == null ? null : licenseDate.toLocalDate(),
                rs.getString("status"),
                rs.getInt("version"),
                rs.getString("created_by"),
                SqlSupport.iso(rs.getTimestamp("created_at")),
                SqlSupport.iso(rs.getTimestamp("updated_at"))
        );
    }

    private String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }
}
