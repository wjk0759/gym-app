package com.fitai.admin.ai;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.fitai.admin.common.api.PageResponse;

@RestController
@RequestMapping("/api/admin/v1/ai")
public class AiController {

    private final AiRepository repository;

    public AiController(AiRepository repository) {
        this.repository = repository;
    }

    @GetMapping("/overview")
    @PreAuthorize("hasAuthority('ai:read')")
    public AiDtos.AiOverview overview() {
        return repository.overview();
    }

    @GetMapping("/jobs")
    @PreAuthorize("hasAuthority('ai:read')")
    public PageResponse<AiDtos.AiJobItem> jobs(
            @RequestParam(required = false) String kind,
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String q,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        return repository.jobs(kind, status, q, page, size);
    }
}
