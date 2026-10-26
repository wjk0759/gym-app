package com.fitai.admin.chats;

import java.util.List;

public final class ChatDtos {

    private ChatDtos() {
    }

    public record ChatListItem(
            String id,
            String userId,
            String userLabel,
            String title,
            String createdAt,
            long messageCount,
            long safetyCount,
            String lastMessageAt
    ) {
    }

    public record ChatDetail(ChatListItem chat, List<ChatMessageItem> messages) {
    }

    public record ChatMessageItem(
            String id,
            String role,
            String content,
            Object citations,
            String safetyFlag,
            Integer tokens,
            String createdAt
    ) {
    }
}
