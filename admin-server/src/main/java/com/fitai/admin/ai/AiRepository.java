package com.fitai.admin.ai;

import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import com.fitai.admin.common.api.PageResponse;
import com.fitai.admin.common.persistence.SqlSupport;

@Repository
public class AiRepository {

    private static final Map<String, String> KIND_LABELS = Map.of(
            "plan", "训练计划生成",
            "coach_trainer", "健身教练",
            "coach_rehab", "康复师",
            "coach_nutrition", "营养师",
            "food_vision", "饮食照片识别",
            "body_vision", "体型照片分析",
            "equipment_vision", "器械照片识别"
    );

    private static final List<AiDtos.SkillInfo> SKILLS = List.of(
            new AiDtos.SkillInfo("trainer", "健身教练", "训练动作、计划调整、负荷与恢复建议", "v1"),
            new AiDtos.SkillInfo("rehab", "康复师", "疼痛分级、红旗症状识别、保守活动与转诊建议", "v1"),
            new AiDtos.SkillInfo("nutrition", "营养师", "热量、蛋白质、膳食结构与特殊人群提示", "v1")
    );

    private final JdbcClient jdbc;

    public AiRepository(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    public AiDtos.AiOverview overview() {
        long total = count("SELECT COUNT(*) FROM ai_jobs WHERE created_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 30 DAY)");
        long ok = count("""
                SELECT COUNT(*) FROM ai_jobs
                WHERE created_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 30 DAY) AND status = 'ok'
                """);
        long fallback = count("""
                SELECT COUNT(*) FROM ai_jobs
                WHERE created_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 30 DAY) AND status = 'fallback'
                """);
        long error = count("""
                SELECT COUNT(*) FROM ai_jobs
                WHERE created_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 30 DAY) AND status NOT IN ('ok', 'fallback')
                """);
        List<Integer> latencies = jdbc.sql("""
                SELECT latency_ms FROM ai_jobs
                WHERE created_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 30 DAY) AND latency_ms IS NOT NULL
                ORDER BY latency_ms
                """).query(Integer.class).list();
        long avg = latencies.isEmpty() ? 0 : Math.round(latencies.stream().mapToLong(Integer::longValue).average().orElse(0));
        long p95 = 0;
        if (!latencies.isEmpty()) {
            List<Integer> sorted = new ArrayList<>(latencies);
            sorted.sort(Comparator.naturalOrder());
            int index = Math.min(sorted.size() - 1, (int) Math.ceil(sorted.size() * 0.95) - 1);
            p95 = sorted.get(index);
        }
        long inputTokens = sum("SELECT COALESCE(SUM(input_tokens), 0) FROM ai_jobs WHERE created_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 30 DAY)");
        long outputTokens = sum("SELECT COALESCE(SUM(output_tokens), 0) FROM ai_jobs WHERE created_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 30 DAY)");

        Map<LocalDate, long[]> dailyMap = new HashMap<>();
        jdbc.sql("""
                SELECT DATE(created_at) AS day, COUNT(*) AS total,
                       SUM(CASE WHEN status NOT IN ('ok', 'fallback') THEN 1 ELSE 0 END) AS errors
                FROM ai_jobs
                WHERE created_at >= DATE_SUB(CURDATE(), INTERVAL 13 DAY)
                GROUP BY DATE(created_at)
                """).query(rs -> {
            dailyMap.put(rs.getDate("day").toLocalDate(), new long[]{rs.getLong("total"), rs.getLong("errors")});
        });
        LocalDate today = LocalDate.now(ZoneOffset.UTC);
        List<AiDtos.DailyPoint> daily = new ArrayList<>();
        for (int i = 13; i >= 0; i--) {
            LocalDate day = today.minusDays(i);
            long[] values = dailyMap.getOrDefault(day, new long[]{0, 0});
            daily.add(new AiDtos.DailyPoint(day.toString(), values[0], values[1]));
        }

        List<AiDtos.KindPoint> kinds = jdbc.sql("""
                SELECT kind, COUNT(*) AS total,
                       SUM(CASE WHEN status NOT IN ('ok', 'fallback') THEN 1 ELSE 0 END) AS errors
                FROM ai_jobs
                WHERE created_at >= DATE_SUB(UTC_TIMESTAMP(), INTERVAL 30 DAY)
                GROUP BY kind
                ORDER BY total DESC
                """).query((rs, rowNum) -> new AiDtos.KindPoint(
                rs.getString("kind"),
                KIND_LABELS.getOrDefault(rs.getString("kind"), rs.getString("kind")),
                rs.getLong("total"),
                rs.getLong("errors")
        )).list();

        return new AiDtos.AiOverview(total, ok, fallback, error, avg, p95, inputTokens, outputTokens,
                daily, kinds, SKILLS);
    }

    public PageResponse<AiDtos.AiJobItem> jobs(
            String kind,
            String status,
            String query,
            int page,
            int size
    ) {
        int safePage = SqlSupport.page(page);
        int safeSize = SqlSupport.size(size);
        List<String> clauses = new ArrayList<>();
        Map<String, Object> params = new HashMap<>();
        if (kind != null && !kind.isBlank()) {
            clauses.add("j.kind = :kind");
            params.put("kind", kind);
        }
        if (status != null && !status.isBlank()) {
            clauses.add("j.status = :status");
            params.put("status", status);
        }
        if (query != null && !query.isBlank()) {
            clauses.add("""
                    (LOWER(COALESCE(p.nickname, '')) LIKE :q
                     OR COALESCE(u.phone, '') LIKE :q
                     OR j.user_id = :rawQuery)
                    """);
            params.put("q", SqlSupport.like(query));
            params.put("rawQuery", query.trim());
        }
        String where = clauses.isEmpty() ? "" : " WHERE " + String.join(" AND ", clauses) + " ";
        long total = jdbc.sql("""
                SELECT COUNT(*) FROM ai_jobs j
                LEFT JOIN users u ON u.id = j.user_id
                LEFT JOIN profiles p ON p.user_id = j.user_id
                """ + where).params(params).query(Long.class).optional().orElse(0L);
        List<AiDtos.AiJobItem> items = jdbc.sql("""
                SELECT j.id, j.user_id, j.kind, j.model, j.prompt_version, j.input_tokens,
                       j.output_tokens, j.latency_ms, j.status, j.error, j.created_at,
                       COALESCE(NULLIF(p.nickname, ''), u.phone, u.username, j.user_id) AS user_label
                FROM ai_jobs j
                LEFT JOIN users u ON u.id = j.user_id
                LEFT JOIN profiles p ON p.user_id = j.user_id
                """ + where + """
                ORDER BY j.created_at DESC
                LIMIT :limit OFFSET :offset
                """).params(params)
                .param("limit", safeSize)
                .param("offset", SqlSupport.offset(safePage, safeSize))
                .query((rs, rowNum) -> new AiDtos.AiJobItem(
                        rs.getString("id"),
                        rs.getString("user_id"),
                        rs.getString("user_label"),
                        rs.getString("kind"),
                        KIND_LABELS.getOrDefault(rs.getString("kind"), rs.getString("kind")),
                        rs.getString("model"),
                        rs.getString("prompt_version"),
                        (Integer) rs.getObject("input_tokens"),
                        (Integer) rs.getObject("output_tokens"),
                        (Integer) rs.getObject("latency_ms"),
                        rs.getString("status"),
                        rs.getString("error"),
                        SqlSupport.iso(rs.getTimestamp("created_at"))
                )).list();
        return PageResponse.of(items, safePage, safeSize, total);
    }

    private long count(String sql) {
        return jdbc.sql(sql).query(Long.class).optional().orElse(0L);
    }

    private long sum(String sql) {
        return jdbc.sql(sql).query(Long.class).optional().orElse(0L);
    }
}
