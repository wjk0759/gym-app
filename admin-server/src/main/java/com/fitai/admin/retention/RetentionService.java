package com.fitai.admin.retention;

import java.sql.Timestamp;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.LinkedHashMap;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

/**
 * Batched retention cleanup for data that has no product value after its
 * operational window. Disabled by default in dev; enabled in prod.
 *
 * Deleting in small batches keeps locks short and avoids a single huge
 * transaction. The job is idempotent: each run simply removes rows older than
 * the configured cutoff.
 */
@Service
public class RetentionService {

    private static final Logger log = LoggerFactory.getLogger(RetentionService.class);

    private static final int MAX_BATCHES = 50;

    private final JdbcClient jdbc;
    private final boolean enabled;
    private final int batchSize;

    public RetentionService(
            JdbcClient jdbc,
            @Value("${fitai.admin.retention.enabled:false}") boolean enabled,
            @Value("${fitai.admin.retention.batch-size:2000}") int batchSize
    ) {
        this.jdbc = jdbc;
        this.enabled = enabled;
        this.batchSize = Math.max(100, Math.min(10_000, batchSize));
    }

    @Scheduled(cron = "${fitai.admin.retention.cron:0 30 3 * * *}")
    public void purgeExpiredData() {
        if (!enabled) {
            log.debug("retention disabled; skipping");
            return;
        }
        Instant now = Instant.now();
        Map<String, Integer> deleted = new LinkedHashMap<>();
        deleted.put("sms_codes", delete("sms_codes", "created_at", now.minus(1, ChronoUnit.DAYS)));
        deleted.put("oauth_tickets", delete("oauth_tickets", "expires_at", now.minus(1, ChronoUnit.DAYS)));
        deleted.put("auth_sessions", delete("auth_sessions", "expires_at", now.minus(7, ChronoUnit.DAYS)));
        deleted.put("auth_events", delete("auth_events", "created_at", now.minus(180, ChronoUnit.DAYS)));
        deleted.put("ai_jobs", delete("ai_jobs", "created_at", now.minus(180, ChronoUnit.DAYS)));
        deleted.put("agent_plan_proposals", delete("agent_plan_proposals", "expires_at", now.minus(7, ChronoUnit.DAYS)));
        deleted.put("chat_sessions", delete("chat_sessions", "created_at", now.minus(365, ChronoUnit.DAYS)));
        deleted.put("admin_refresh_tokens", delete("admin_refresh_tokens", "expires_at", now.minus(7, ChronoUnit.DAYS)));
        deleted.put("admin_audit_logs", delete("admin_audit_logs", "created_at", now.minus(365, ChronoUnit.DAYS)));
        deleted.put("equipment_scans", delete("equipment_scans", "created_at", now.minus(180, ChronoUnit.DAYS)));
        deleted.put("plan_day_states", delete("plan_day_states", "updated_at", now.minus(180, ChronoUnit.DAYS)));
        deleted.put("ai_memories", delete("ai_memories", "updated_at", now.minus(90, ChronoUnit.DAYS), "active = FALSE"));
        deleted.put("agent_runs", delete("agent_runs", "created_at", now.minus(365, ChronoUnit.DAYS)));

        int total = deleted.values().stream().mapToInt(Integer::intValue).sum();
        if (total > 0) {
            log.info("retention cleanup removed {} rows: {}", total, deleted);
        }
    }

    private int delete(String table, String timeColumn, Instant cutoff) {
        return delete(table, timeColumn, cutoff, null);
    }

    private int delete(String table, String timeColumn, Instant cutoff, String extraWhere) {
        String where = timeColumn + " < :cutoff";
        if (extraWhere != null && !extraWhere.isBlank()) {
            where += " AND " + extraWhere;
        }
        String sql = "DELETE FROM " + table + " WHERE " + where + " ORDER BY " + timeColumn + " LIMIT :batch";
        Timestamp timestamp = Timestamp.from(cutoff);
        int total = 0;
        for (int batch = 0; batch < MAX_BATCHES; batch++) {
            int removed = jdbc.sql(sql)
                    .param("cutoff", timestamp)
                    .param("batch", batchSize)
                    .update();
            total += removed;
            if (removed < batchSize) {
                break;
            }
        }
        return total;
    }
}
