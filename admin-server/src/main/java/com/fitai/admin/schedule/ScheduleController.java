package com.fitai.admin.schedule;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.fitai.admin.common.api.PageResponse;

@RestController
@RequestMapping("/api/admin/v1/schedule")
public class ScheduleController {

    private final ScheduleRepository repository;

    public ScheduleController(ScheduleRepository repository) {
        this.repository = repository;
    }

    @GetMapping
    @PreAuthorize("hasAuthority('plan:read')")
    public PageResponse<ScheduleDtos.ScheduleStateItem> list(
            @RequestParam(required = false) String q,
            @RequestParam(required = false) String planId,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        return repository.list(q, planId, page, size);
    }
}
