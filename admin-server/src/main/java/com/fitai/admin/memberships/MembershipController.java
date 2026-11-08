package com.fitai.admin.memberships;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.fitai.admin.common.api.PageResponse;

@RestController
@RequestMapping("/api/admin/v1/memberships")
public class MembershipController {

    private final MembershipRepository repository;

    public MembershipController(MembershipRepository repository) {
        this.repository = repository;
    }

    @GetMapping
    @PreAuthorize("hasAuthority('user:read')")
    public PageResponse<MembershipDtos.MembershipItem> list(
            @RequestParam(required = false) String q,
            @RequestParam(required = false) String source,
            @RequestParam(required = false) String status,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        return repository.list(q, source, status, page, size);
    }

    @GetMapping("/summary")
    @PreAuthorize("hasAuthority('user:read')")
    public MembershipDtos.MembershipSummary summary() {
        return repository.summary();
    }
}
