package com.fitai.admin.agent;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import com.fitai.admin.common.api.ApiException;
import com.fitai.admin.common.api.PageResponse;
import com.fitai.admin.common.persistence.JsonCodec;
import com.fitai.admin.common.persistence.SqlSupport;

@Repository
public class AgentRepository {

    private final JdbcClient jdbc;
    private final JsonCodec json;

    public AgentRepository(JdbcClient jdbc, JsonCodec json) {
        this.jdbc = jdbc;
        this.json = json;
    }

    public PageResponse<AgentDtos.AgentRunItem> runs(
            String status,
            String intent,
            String query,
            int page,
            int size
    ) {
        int safePage = SqlSupport.page(page);
        int safeSize = SqlSupport.size(size);
        List<String> clauses = new ArrayList<>();
        Map<String, Object> params = new HashMap<>();
        if (status != null && !status.isBlank()) {
            clauses.add("r.status = :status");
            params.put("status", status);
        }
        if (intent != null && !intent.isBlank()) {
            clauses.add("r.intent = :intent");
            params.put("intent", intent);
        }
        if (query != null && !query.isBlank()) {
            clauses.add("""
                    (LOWER(COALESCE(p.nickname, '')) LIKE :q
                     OR COALESCE(u.phone, '') LIKE :q
                     OR COALESCE(u.username, '') LIKE :q
                     OR r.user_id = :rawQuery)
                    """);
            params.put("q", SqlSupport.like(query));
            params.put("rawQuery", query.trim());
        }
        String where = clauses.isEmpty() ? "" : " WHERE " + String.join(" AND ", clauses) + " ";
        long total = jdbc.sql("""
                SELECT COUNT(*) FROM agent_runs r
                LEFT JOIN users u ON u.id = r.user_id
                LEFT JOIN profiles p ON p.user_id = r.user_id
                """ + where).params(params).query(Long.class).optional().orElse(0L);

        List<AgentDtos.AgentRunItem> items = jdbc.sql("""
                SELECT r.id, r.user_id, r.session_id, r.intent, r.status, r.model,
                       r.step_count, r.input_text, r.output_text, r.error,
                       r.created_at, r.completed_at,
                       pp.id AS proposal_id, pp.status AS proposal_status,
                       COALESCE(NULLIF(p.nickname, ''), u.phone, u.username, r.user_id) AS user_label
                FROM agent_runs r
                LEFT JOIN users u ON u.id = r.user_id
                LEFT JOIN profiles p ON p.user_id = r.user_id
                LEFT JOIN agent_plan_proposals pp
                  ON pp.id = (
                    SELECT pp2.id FROM agent_plan_proposals pp2
                    WHERE pp2.run_id = r.id
                    ORDER BY pp2.created_at DESC LIMIT 1
                  )
                """ + where + """
                ORDER BY r.created_at DESC
                LIMIT :limit OFFSET :offset
                """).params(params)
                .param("limit", safeSize)
                .param("offset", SqlSupport.offset(safePage, safeSize))
                .query((rs, rowNum) -> new AgentDtos.AgentRunItem(
                        rs.getString("id"),
                        rs.getString("user_id"),
                        rs.getString("user_label"),
                        rs.getString("session_id"),
                        rs.getString("intent"),
                        rs.getString("status"),
                        rs.getString("model"),
                        rs.getInt("step_count"),
                        rs.getString("input_text"),
                        rs.getString("output_text"),
                        rs.getString("error"),
                        SqlSupport.iso(rs.getTimestamp("created_at")),
                        SqlSupport.iso(rs.getTimestamp("completed_at")),
                        rs.getString("proposal_id"),
                        rs.getString("proposal_status")
                )).list();
        return PageResponse.of(items, safePage, safeSize, total);
    }

    public AgentDtos.AgentRunDetail detail(String id) {
        AgentDtos.AgentRunItem run = jdbc.sql("""
                SELECT r.id, r.user_id, r.session_id, r.intent, r.status, r.model,
                       r.step_count, r.input_text, r.output_text, r.error,
                       r.created_at, r.completed_at,
                       pp.id AS proposal_id, pp.status AS proposal_status,
                       COALESCE(NULLIF(p.nickname, ''), u.phone, u.username, r.user_id) AS user_label
                FROM agent_runs r
                LEFT JOIN users u ON u.id = r.user_id
                LEFT JOIN profiles p ON p.user_id = r.user_id
                LEFT JOIN agent_plan_proposals pp
                  ON pp.id = (
                    SELECT pp2.id FROM agent_plan_proposals pp2
                    WHERE pp2.run_id = r.id
                    ORDER BY pp2.created_at DESC LIMIT 1
                  )
                WHERE r.id = :id
                """).param("id", id).query((rs, rowNum) -> new AgentDtos.AgentRunItem(
                rs.getString("id"),
                rs.getString("user_id"),
                rs.getString("user_label"),
                rs.getString("session_id"),
                rs.getString("intent"),
                rs.getString("status"),
                rs.getString("model"),
                rs.getInt("step_count"),
                rs.getString("input_text"),
                rs.getString("output_text"),
                rs.getString("error"),
                SqlSupport.iso(rs.getTimestamp("created_at")),
                SqlSupport.iso(rs.getTimestamp("completed_at")),
                rs.getString("proposal_id"),
                rs.getString("proposal_status")
        )).optional().orElseThrow(() -> ApiException.notFound("AGENT_RUN_NOT_FOUND", "Agent 运行记录不存在"));

        List<AgentDtos.AgentStepItem> steps = jdbc.sql("""
                SELECT id, step_index, step_type, tool_name, status, latency_ms,
                       input_json, output_json, error, created_at
                FROM agent_steps
                WHERE run_id = :id
                ORDER BY step_index
                """).param("id", id).query((rs, rowNum) -> new AgentDtos.AgentStepItem(
                rs.getString("id"),
                rs.getInt("step_index"),
                rs.getString("step_type"),
                rs.getString("tool_name"),
                rs.getString("status"),
                (Integer) rs.getObject("latency_ms"),
                json.parse(rs.getObject("input_json")),
                json.parse(rs.getObject("output_json")),
                rs.getString("error"),
                SqlSupport.iso(rs.getTimestamp("created_at"))
        )).list();

        List<AgentDtos.AgentProposalItem> proposals = jdbc.sql("""
                SELECT id, title, status, base_version, diff_data, validation_data,
                       created_at, expires_at, applied_at
                FROM agent_plan_proposals
                WHERE run_id = :id
                ORDER BY created_at DESC
                """).param("id", id).query((rs, rowNum) -> new AgentDtos.AgentProposalItem(
                rs.getString("id"),
                rs.getString("title"),
                rs.getString("status"),
                (Integer) rs.getObject("base_version"),
                json.parse(rs.getObject("diff_data")),
                json.parse(rs.getObject("validation_data")),
                SqlSupport.iso(rs.getTimestamp("created_at")),
                SqlSupport.iso(rs.getTimestamp("expires_at")),
                SqlSupport.iso(rs.getTimestamp("applied_at"))
        )).list();

        return new AgentDtos.AgentRunDetail(run, steps, proposals);
    }
}
