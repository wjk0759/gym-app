package com.fitai.admin.chats;

import java.util.Map;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.fitai.admin.common.api.ApiException;
import com.fitai.admin.common.audit.AuditService;

@Service
public class ChatService {

    private final ChatRepository repository;
    private final AuditService auditService;

    public ChatService(ChatRepository repository, AuditService auditService) {
        this.repository = repository;
        this.auditService = auditService;
    }

    public ChatDtos.ChatDetail detail(String id) {
        return repository.detail(id)
                .orElseThrow(() -> ApiException.notFound("CHAT_NOT_FOUND", "教练对话不存在"));
    }

    @Transactional
    public void delete(String id) {
        if (!repository.delete(id)) {
            throw ApiException.notFound("CHAT_NOT_FOUND", "教练对话不存在");
        }
        auditService.record("CHAT_DELETED", "chat_session", id, Map.of("hardDelete", true));
    }
}
