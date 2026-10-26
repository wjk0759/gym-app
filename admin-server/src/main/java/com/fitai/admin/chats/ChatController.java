package com.fitai.admin.chats;

import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.fitai.admin.common.api.PageResponse;

@RestController
@RequestMapping("/api/admin/v1/chats")
public class ChatController {

    private final ChatRepository repository;
    private final ChatService service;

    public ChatController(ChatRepository repository, ChatService service) {
        this.repository = repository;
        this.service = service;
    }

    @GetMapping
    @PreAuthorize("hasAuthority('chat:read')")
    public PageResponse<ChatDtos.ChatListItem> list(
            @RequestParam(required = false) String q,
            @RequestParam(defaultValue = "false") boolean safetyOnly,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        return repository.list(q, safetyOnly, page, size);
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAuthority('chat:read')")
    public ChatDtos.ChatDetail detail(@PathVariable String id) {
        return service.detail(id);
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAuthority('chat:write')")
    public ResponseEntity<Void> delete(@PathVariable String id) {
        service.delete(id);
        return ResponseEntity.noContent().build();
    }
}
