package com.fitai.admin.chats;

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
public class ChatRepository {

    private final JdbcClient jdbc;
    private final JsonCodec jsonCodec;

    public ChatRepository(JdbcClient jdbc, JsonCodec jsonCodec) {
        this.jdbc = jdbc;
        this.jsonCodec = jsonCodec;
    }

    public PageResponse<ChatDtos.ChatListItem> list(
            String query,
            boolean safetyOnly,
            int page,
            int size
    ) {
        int safePage = SqlSupport.page(page);
        int safeSize = SqlSupport.size(size);
        String where = where(query, safetyOnly);
        Map<String, Object> params = params(query);
        long total = jdbc.sql("""
                SELECT COUNT(*)
                FROM chat_sessions c
                JOIN users u ON u.id = c.user_id
                LEFT JOIN profiles p ON p.user_id = c.user_id
                """ + where).params(params).query(Long.class).optional().orElse(0L);
        List<ChatDtos.ChatListItem> items = jdbc.sql("""
                SELECT c.id, c.user_id, c.title, c.created_at,
                       COALESCE(NULLIF(p.nickname, ''), u.phone, u.username, c.user_id) AS user_label,
                       (SELECT COUNT(*) FROM chat_messages m WHERE m.session_id = c.id) AS message_count,
                       (SELECT COUNT(*) FROM chat_messages m WHERE m.session_id = c.id AND m.safety_flag IS NOT NULL) AS safety_count,
                       (SELECT MAX(m.created_at) FROM chat_messages m WHERE m.session_id = c.id) AS last_message_at
                FROM chat_sessions c
                JOIN users u ON u.id = c.user_id
                LEFT JOIN profiles p ON p.user_id = c.user_id
                """ + where + """
                ORDER BY c.created_at DESC
                LIMIT :limit OFFSET :offset
                """).params(params)
                .param("limit", safeSize)
                .param("offset", SqlSupport.offset(safePage, safeSize))
                .query((rs, rowNum) -> mapChat(rs))
                .list();
        return PageResponse.of(items, safePage, safeSize, total);
    }

    public Optional<ChatDtos.ChatDetail> detail(String id) {
        Optional<ChatDtos.ChatListItem> chat = jdbc.sql("""
                SELECT c.id, c.user_id, c.title, c.created_at,
                       COALESCE(NULLIF(p.nickname, ''), u.phone, u.username, c.user_id) AS user_label,
                       (SELECT COUNT(*) FROM chat_messages m WHERE m.session_id = c.id) AS message_count,
                       (SELECT COUNT(*) FROM chat_messages m WHERE m.session_id = c.id AND m.safety_flag IS NOT NULL) AS safety_count,
                       (SELECT MAX(m.created_at) FROM chat_messages m WHERE m.session_id = c.id) AS last_message_at
                FROM chat_sessions c
                JOIN users u ON u.id = c.user_id
                LEFT JOIN profiles p ON p.user_id = c.user_id
                WHERE c.id = :id
                """).param("id", id).query((rs, rowNum) -> mapChat(rs)).optional();
        if (chat.isEmpty()) {
            return Optional.empty();
        }
        List<ChatDtos.ChatMessageItem> messages = jdbc.sql("""
                SELECT id, `role`, content, citations, safety_flag, tokens, created_at
                FROM chat_messages
                WHERE session_id = :id
                ORDER BY created_at, id
                """).param("id", id).query((rs, rowNum) -> new ChatDtos.ChatMessageItem(
                rs.getString("id"),
                rs.getString("role"),
                rs.getString("content"),
                jsonCodec.parse(rs.getString("citations")),
                rs.getString("safety_flag"),
                (Integer) rs.getObject("tokens"),
                SqlSupport.iso(rs.getTimestamp("created_at"))
        )).list();
        return Optional.of(new ChatDtos.ChatDetail(chat.get(), messages));
    }

    public boolean delete(String id) {
        return jdbc.sql("DELETE FROM chat_sessions WHERE id = :id").param("id", id).update() > 0;
    }

    private String where(String query, boolean safetyOnly) {
        java.util.ArrayList<String> clauses = new java.util.ArrayList<>();
        if (safetyOnly) {
            clauses.add("""
                    EXISTS (SELECT 1 FROM chat_messages sm
                            WHERE sm.session_id = c.id AND sm.safety_flag IS NOT NULL)
                    """);
        }
        if (query != null && !query.isBlank()) {
            clauses.add("""
                    (LOWER(c.title) LIKE :q
                     OR COALESCE(u.phone, '') LIKE :q
                     OR LOWER(COALESCE(p.nickname, '')) LIKE :q
                     OR c.user_id = :rawQuery)
                    """);
        }
        return clauses.isEmpty() ? "" : " WHERE " + String.join(" AND ", clauses) + " ";
    }

    private Map<String, Object> params(String query) {
        Map<String, Object> params = new HashMap<>();
        if (query != null && !query.isBlank()) {
            params.put("q", SqlSupport.like(query));
            params.put("rawQuery", query.trim());
        }
        return params;
    }

    private ChatDtos.ChatListItem mapChat(java.sql.ResultSet rs) throws java.sql.SQLException {
        return new ChatDtos.ChatListItem(
                rs.getString("id"),
                rs.getString("user_id"),
                rs.getString("user_label"),
                rs.getString("title"),
                SqlSupport.iso(rs.getTimestamp("created_at")),
                rs.getLong("message_count"),
                rs.getLong("safety_count"),
                SqlSupport.iso(rs.getTimestamp("last_message_at"))
        );
    }
}
