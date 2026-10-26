package com.fitai.admin.workouts;

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
@RequestMapping("/api/admin/v1/workouts")
public class WorkoutController {

    private final WorkoutRepository repository;
    private final WorkoutService service;

    public WorkoutController(WorkoutRepository repository, WorkoutService service) {
        this.repository = repository;
        this.service = service;
    }

    @GetMapping
    @PreAuthorize("hasAuthority('workout:read')")
    public PageResponse<WorkoutDtos.WorkoutListItem> list(
            @RequestParam(required = false) String q,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        return repository.list(q, page, size);
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAuthority('workout:read')")
    public WorkoutDtos.WorkoutDetail detail(@PathVariable String id) {
        return service.detail(id);
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAuthority('workout:write')")
    public ResponseEntity<Void> delete(@PathVariable String id) {
        service.delete(id);
        return ResponseEntity.noContent().build();
    }
}
