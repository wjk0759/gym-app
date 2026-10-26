package com.fitai.admin.plans;

import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.fitai.admin.common.api.PageResponse;

@RestController
@RequestMapping("/api/admin/v1/plans")
public class PlanController {

    private final PlanRepository repository;
    private final PlanService service;

    public PlanController(PlanRepository repository, PlanService service) {
        this.repository = repository;
        this.service = service;
    }

    @GetMapping
    @PreAuthorize("hasAuthority('plan:read')")
    public PageResponse<PlanDtos.PlanListItem> list(
            @RequestParam(required = false) String q,
            @RequestParam(required = false) String status,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        return repository.list(q, status, page, size);
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAuthority('plan:read')")
    public PlanDtos.PlanDetail detail(@PathVariable String id) {
        return service.detail(id);
    }

    @PostMapping("/{id}/archive")
    @PreAuthorize("hasAuthority('plan:write')")
    public ResponseEntity<Void> archive(@PathVariable String id) {
        service.archive(id);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/{id}/activate")
    @PreAuthorize("hasAuthority('plan:write')")
    public ResponseEntity<Void> activate(@PathVariable String id) {
        service.activate(id);
        return ResponseEntity.noContent().build();
    }
}
