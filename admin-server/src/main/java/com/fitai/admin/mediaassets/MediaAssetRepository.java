package com.fitai.admin.mediaassets;

import java.sql.Date;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import com.fitai.admin.common.api.PageResponse;
import com.fitai.admin.common.persistence.SqlSupport;

@Repository
public class MediaAssetRepository {

    private static final String FROM = """
            FROM exercise_media_assets m
            JOIN exercises e ON e.slug = m.exercise_slug
            """;

    private static final String SELECT = """
            SELECT m.id, m.exercise_slug, e.name_zh AS exercise_name, m.sex, m.source,
                   m.phone_url, m.watch_url, m.poster_url, m.duration_seconds,
                   m.loop_start_ms, m.loop_end_ms, m.watch_sha256, m.version, m.status,
                   m.license_note, m.license_expires_at, m.purchase_ref,
                   m.created_at, m.updated_at
            """ + FROM;

    private final JdbcClient jdbc;

    public MediaAssetRepository(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    public PageResponse<MediaAssetDtos.MediaAssetItem> list(
            String query,
            String sex,
            String status,
            String coverage,
            int page,
            int size
    ) {
        int safePage = SqlSupport.page(page);
        int safeSize = SqlSupport.size(size);
        Map<String, Object> params = new HashMap<>();
        String where = where(query, sex, status, coverage, params);
        long total = jdbc.sql("SELECT COUNT(*) " + FROM + where)
                .params(params)
                .query(Long.class)
                .optional()
                .orElse(0L);
        List<MediaAssetDtos.MediaAssetItem> items = jdbc.sql(SELECT + where + """
                ORDER BY e.name_zh, m.sex, m.version DESC
                LIMIT :limit OFFSET :offset
                """)
                .params(params)
                .param("limit", safeSize)
                .param("offset", SqlSupport.offset(safePage, safeSize))
                .query((rs, rowNum) -> new MediaAssetDtos.MediaAssetItem(
                        rs.getString("id"),
                        rs.getString("exercise_slug"),
                        rs.getString("exercise_name"),
                        rs.getString("sex"),
                        rs.getString("source"),
                        rs.getString("phone_url"),
                        rs.getString("watch_url"),
                        rs.getString("poster_url"),
                        (Integer) rs.getObject("duration_seconds"),
                        (Integer) rs.getObject("loop_start_ms"),
                        (Integer) rs.getObject("loop_end_ms"),
                        rs.getString("watch_sha256"),
                        rs.getInt("version"),
                        rs.getString("status"),
                        rs.getString("license_note"),
                        date(rs.getDate("license_expires_at")),
                        rs.getString("purchase_ref"),
                        SqlSupport.iso(rs.getTimestamp("created_at")),
                        SqlSupport.iso(rs.getTimestamp("updated_at"))
                ))
                .list();
        return PageResponse.of(items, safePage, safeSize, total);
    }

    public Optional<MediaAssetDtos.MediaAssetItem> find(String id) {
        return jdbc.sql(SELECT + " WHERE m.id = :id LIMIT 1")
                .param("id", id)
                .query((rs, rowNum) -> new MediaAssetDtos.MediaAssetItem(
                        rs.getString("id"),
                        rs.getString("exercise_slug"),
                        rs.getString("exercise_name"),
                        rs.getString("sex"),
                        rs.getString("source"),
                        rs.getString("phone_url"),
                        rs.getString("watch_url"),
                        rs.getString("poster_url"),
                        (Integer) rs.getObject("duration_seconds"),
                        (Integer) rs.getObject("loop_start_ms"),
                        (Integer) rs.getObject("loop_end_ms"),
                        rs.getString("watch_sha256"),
                        rs.getInt("version"),
                        rs.getString("status"),
                        rs.getString("license_note"),
                        date(rs.getDate("license_expires_at")),
                        rs.getString("purchase_ref"),
                        SqlSupport.iso(rs.getTimestamp("created_at")),
                        SqlSupport.iso(rs.getTimestamp("updated_at"))
                ))
                .optional();
    }

    public boolean exerciseExists(String slug) {
        return jdbc.sql("SELECT COUNT(*) FROM exercises WHERE slug = :slug")
                .param("slug", slug)
                .query(Long.class)
                .optional()
                .orElse(0L) > 0;
    }

    public String create(MediaAssetDtos.CreateMediaAssetRequest request, String status) {
        int version = jdbc.sql("""
                SELECT COALESCE(MAX(version), 0) + 1
                FROM exercise_media_assets
                WHERE exercise_slug = :slug AND sex = :sex
                """)
                .param("slug", request.exerciseSlug())
                .param("sex", request.sex())
                .query(Integer.class)
                .optional()
                .orElse(1);
        String id = UUID.randomUUID().toString();
        jdbc.sql("""
                INSERT INTO exercise_media_assets
                    (id, exercise_slug, sex, source, phone_url, watch_url, poster_url,
                     duration_seconds, loop_start_ms, loop_end_ms, watch_sha256, version,
                     status, license_note, license_expires_at, purchase_ref, created_at, updated_at)
                VALUES
                    (:id, :exerciseSlug, :sex, :source, :phoneUrl, :watchUrl, :posterUrl,
                     :durationSeconds, :loopStartMs, :loopEndMs, :watchSha256, :version,
                     :status, :licenseNote, :licenseExpiresAt, :purchaseRef,
                     UTC_TIMESTAMP(), UTC_TIMESTAMP())
                """)
                .param("id", id)
                .param("exerciseSlug", request.exerciseSlug())
                .param("sex", request.sex())
                .param("source", request.source())
                .param("phoneUrl", request.phoneUrl())
                .param("watchUrl", request.watchUrl())
                .param("posterUrl", request.posterUrl())
                .param("durationSeconds", request.durationSeconds())
                .param("loopStartMs", request.loopStartMs())
                .param("loopEndMs", request.loopEndMs())
                .param("watchSha256", request.watchSha256())
                .param("version", version)
                .param("status", status)
                .param("licenseNote", request.licenseNote())
                .param("licenseExpiresAt", request.licenseExpiresAt())
                .param("purchaseRef", request.purchaseRef())
                .update();
        return id;
    }

    public void update(String id, MediaAssetDtos.UpdateMediaAssetRequest request) {
        List<String> sets = new ArrayList<>();
        Map<String, Object> params = new HashMap<>();
        params.put("id", id);
        if (request.source() != null) {
            sets.add("source = :source");
            params.put("source", request.source());
        }
        if (request.phoneUrl() != null) {
            sets.add("phone_url = :phoneUrl");
            params.put("phoneUrl", request.phoneUrl());
        }
        if (request.watchUrl() != null) {
            sets.add("watch_url = :watchUrl");
            params.put("watchUrl", request.watchUrl());
        }
        if (request.posterUrl() != null) {
            sets.add("poster_url = NULLIF(:posterUrl, '')");
            params.put("posterUrl", request.posterUrl());
        }
        if (request.durationSeconds() != null) {
            sets.add("duration_seconds = :durationSeconds");
            params.put("durationSeconds", request.durationSeconds());
        }
        if (request.loopStartMs() != null) {
            sets.add("loop_start_ms = :loopStartMs");
            params.put("loopStartMs", request.loopStartMs());
        }
        if (request.loopEndMs() != null) {
            sets.add("loop_end_ms = :loopEndMs");
            params.put("loopEndMs", request.loopEndMs());
        }
        if (request.watchSha256() != null) {
            sets.add("watch_sha256 = :watchSha256");
            params.put("watchSha256", request.watchSha256());
        }
        if (request.licenseNote() != null) {
            sets.add("license_note = NULLIF(:licenseNote, '')");
            params.put("licenseNote", request.licenseNote());
        }
        if (request.licenseExpiresAt() != null) {
            sets.add("license_expires_at = :licenseExpiresAt");
            params.put("licenseExpiresAt", request.licenseExpiresAt());
        }
        if (request.purchaseRef() != null) {
            sets.add("purchase_ref = NULLIF(:purchaseRef, '')");
            params.put("purchaseRef", request.purchaseRef());
        }
        if (sets.isEmpty()) {
            return;
        }
        sets.add("updated_at = UTC_TIMESTAMP()");
        jdbc.sql("UPDATE exercise_media_assets SET " + String.join(", ", sets) + " WHERE id = :id")
                .params(params)
                .update();
    }

    public void updateStatus(String id, String status) {
        jdbc.sql("""
                UPDATE exercise_media_assets
                SET status = :status, updated_at = UTC_TIMESTAMP()
                WHERE id = :id
                """)
                .param("status", status)
                .param("id", id)
                .update();
    }

    public void archiveOtherVersions(String id, String exerciseSlug, String sex) {
        jdbc.sql("""
                UPDATE exercise_media_assets
                SET status = 'archived', updated_at = UTC_TIMESTAMP()
                WHERE exercise_slug = :exerciseSlug
                  AND sex = :sex
                  AND id <> :id
                  AND status = 'published'
                """)
                .param("exerciseSlug", exerciseSlug)
                .param("sex", sex)
                .param("id", id)
                .update();
    }

    public boolean delete(String id) {
        return jdbc.sql("DELETE FROM exercise_media_assets WHERE id = :id")
                .param("id", id)
                .update() > 0;
    }

    public boolean isUrlReferenced(String url, String excludeId) {
        if (url == null || url.isBlank()) {
            return false;
        }
        return jdbc.sql("""
                SELECT COUNT(*)
                FROM exercise_media_assets
                WHERE id <> :excludeId
                  AND (phone_url = :url OR watch_url = :url OR poster_url = :url)
                """)
                .param("excludeId", excludeId)
                .param("url", url)
                .query(Long.class)
                .optional()
                .orElse(0L) > 0;
    }

    public MediaAssetDtos.MediaCoverage coverage() {
        long active = count("SELECT COUNT(*) FROM exercises WHERE is_active = 1");
        long withAny = count("""
                SELECT COUNT(DISTINCT e.slug)
                FROM exercises e
                WHERE e.is_active = 1
                  AND EXISTS (
                      SELECT 1 FROM exercise_media_assets m
                      WHERE m.exercise_slug = e.slug AND m.status = 'published'
                  )
                """);
        long withMale = count("""
                SELECT COUNT(DISTINCT e.slug)
                FROM exercises e
                WHERE e.is_active = 1
                  AND EXISTS (
                      SELECT 1 FROM exercise_media_assets m
                      WHERE m.exercise_slug = e.slug AND m.status = 'published'
                        AND m.sex IN ('male', 'unisex')
                  )
                """);
        long withFemale = count("""
                SELECT COUNT(DISTINCT e.slug)
                FROM exercises e
                WHERE e.is_active = 1
                  AND EXISTS (
                      SELECT 1 FROM exercise_media_assets m
                      WHERE m.exercise_slug = e.slug AND m.status = 'published'
                        AND m.sex IN ('female', 'unisex')
                  )
                """);
        long withUnisex = count("""
                SELECT COUNT(DISTINCT e.slug)
                FROM exercises e
                WHERE e.is_active = 1
                  AND EXISTS (
                      SELECT 1 FROM exercise_media_assets m
                      WHERE m.exercise_slug = e.slug AND m.status = 'published'
                        AND m.sex = 'unisex'
                  )
                """);
        long phoneReady = count("""
                SELECT COUNT(DISTINCT m.exercise_slug)
                FROM exercise_media_assets m
                JOIN exercises e ON e.slug = m.exercise_slug
                WHERE e.is_active = 1 AND m.status = 'published'
                  AND m.phone_url IS NOT NULL AND m.phone_url <> ''
                """);
        long watchReady = count("""
                SELECT COUNT(DISTINCT m.exercise_slug)
                FROM exercise_media_assets m
                JOIN exercises e ON e.slug = m.exercise_slug
                WHERE e.is_active = 1 AND m.status = 'published'
                  AND m.watch_url IS NOT NULL AND m.watch_url <> ''
                """);
        long posterReady = count("""
                SELECT COUNT(DISTINCT m.exercise_slug)
                FROM exercise_media_assets m
                JOIN exercises e ON e.slug = m.exercise_slug
                WHERE e.is_active = 1 AND m.status = 'published'
                  AND m.poster_url IS NOT NULL AND m.poster_url <> ''
                """);
        long expiring = count("""
                SELECT COUNT(*)
                FROM exercise_media_assets
                WHERE status = 'published'
                  AND license_expires_at IS NOT NULL
                  AND license_expires_at BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 30 DAY)
                """);
        long missingAnyCount = count("""
                SELECT COUNT(*)
                FROM exercises e
                WHERE e.is_active = 1
                  AND NOT EXISTS (
                      SELECT 1 FROM exercise_media_assets m
                      WHERE m.exercise_slug = e.slug AND m.status = 'published'
                  )
                """);
        long missingMaleCount = count("""
                SELECT COUNT(*)
                FROM exercises e
                WHERE e.is_active = 1
                  AND NOT EXISTS (
                      SELECT 1 FROM exercise_media_assets m
                      WHERE m.exercise_slug = e.slug AND m.status = 'published'
                        AND m.sex IN ('male', 'unisex')
                  )
                """);
        long missingFemaleCount = count("""
                SELECT COUNT(*)
                FROM exercises e
                WHERE e.is_active = 1
                  AND NOT EXISTS (
                      SELECT 1 FROM exercise_media_assets m
                      WHERE m.exercise_slug = e.slug AND m.status = 'published'
                        AND m.sex IN ('female', 'unisex')
                  )
                """);
        return new MediaAssetDtos.MediaCoverage(
                active,
                withAny,
                withMale,
                withFemale,
                withUnisex,
                phoneReady,
                watchReady,
                posterReady,
                expiring,
                missingAnyCount,
                missingMaleCount,
                missingFemaleCount,
                missing("""
                        NOT EXISTS (
                            SELECT 1 FROM exercise_media_assets m
                            WHERE m.exercise_slug = e.slug AND m.status = 'published'
                        )
                        """),
                missing("""
                        NOT EXISTS (
                            SELECT 1 FROM exercise_media_assets m
                            WHERE m.exercise_slug = e.slug AND m.status = 'published'
                              AND m.sex IN ('male', 'unisex')
                        )
                        """),
                missing("""
                        NOT EXISTS (
                            SELECT 1 FROM exercise_media_assets m
                            WHERE m.exercise_slug = e.slug AND m.status = 'published'
                              AND m.sex IN ('female', 'unisex')
                        )
                        """)
        );
    }

    private List<MediaAssetDtos.MissingExercise> missing(String condition) {
        return jdbc.sql("""
                SELECT e.slug, e.name_zh, e.muscle_group
                FROM exercises e
                WHERE e.is_active = 1 AND
                """ + condition + """
                ORDER BY e.name_zh
                LIMIT 100
                """)
                .query((rs, rowNum) -> new MediaAssetDtos.MissingExercise(
                        rs.getString("slug"),
                        rs.getString("name_zh"),
                        rs.getString("muscle_group")
                ))
                .list();
    }

    private long count(String sql) {
        return jdbc.sql(sql).query(Long.class).optional().orElse(0L);
    }

    private String where(
            String query,
            String sex,
            String status,
            String coverage,
            Map<String, Object> params
    ) {
        List<String> clauses = new ArrayList<>();
        if (query != null && !query.isBlank()) {
            clauses.add("(e.name_zh LIKE :prefix OR e.name_en LIKE :prefix OR e.slug LIKE :prefix)");
            params.put("prefix", query.trim() + "%");
        }
        if (sex != null && !sex.isBlank()) {
            clauses.add("m.sex = :sex");
            params.put("sex", sex);
        }
        if (status != null && !status.isBlank()) {
            clauses.add("m.status = :status");
            params.put("status", status);
        }
        if (coverage != null && !coverage.isBlank()) {
            switch (coverage) {
                case "missing_phone" -> clauses.add("(m.phone_url IS NULL OR m.phone_url = '')");
                case "missing_watch" -> clauses.add("(m.watch_url IS NULL OR m.watch_url = '')");
                case "missing_poster" -> clauses.add("(m.poster_url IS NULL OR m.poster_url = '')");
                case "expiring" -> clauses.add(
                        "m.license_expires_at BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 30 DAY)");
                default -> {
                }
            }
        }
        return clauses.isEmpty() ? " " : " WHERE " + String.join(" AND ", clauses);
    }

    private java.time.LocalDate date(Date value) {
        return value == null ? null : value.toLocalDate();
    }
}
