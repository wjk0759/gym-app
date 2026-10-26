package com.fitai.admin.dashboard;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/v1/dashboard")
public class DashboardController {

    private final DashboardRepository repository;

    public DashboardController(DashboardRepository repository) {
        this.repository = repository;
    }

    @GetMapping("/summary")
    @PreAuthorize("hasAuthority('dashboard:read')")
    public DashboardSummary summary() {
        return repository.load();
    }
}
