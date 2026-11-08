package com.fitai.admin.diet;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/v1/diet")
public class DietController {

    private final DietRepository repository;

    public DietController(DietRepository repository) {
        this.repository = repository;
    }

    @GetMapping("/summary")
    @PreAuthorize("hasAuthority('user:read')")
    public DietDtos.DietSummary summary() {
        return repository.summary();
    }
}
