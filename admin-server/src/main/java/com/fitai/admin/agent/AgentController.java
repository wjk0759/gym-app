package com.fitai.admin.agent;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.fitai.admin.common.api.PageResponse;

@RestController
@RequestMapping("/api/admin/v1/agent")
public class AgentController {

    private final AgentRepository repository;

    public AgentController(AgentRepository repository) {
        this.repository = repository;
    }

    @GetMapping("/runs")
    @PreAuthorize("hasAuthority('ai:read')")
    public PageResponse<AgentDtos.AgentRunItem> runs(
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String intent,
            @RequestParam(required = false) String q,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        return repository.runs(status, intent, q, page, size);
    }

    @GetMapping("/runs/{id}")
    @PreAuthorize("hasAuthority('ai:read')")
    public AgentDtos.AgentRunDetail detail(@PathVariable String id) {
        return repository.detail(id);
    }

    @GetMapping("/actions")
    @PreAuthorize("hasAuthority('ai:read')")
    public PageResponse<AgentDtos.AgentActionItem> actions(
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String actionType,
            @RequestParam(required = false) String q,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        return repository.actions(status, actionType, q, page, size);
    }
}
