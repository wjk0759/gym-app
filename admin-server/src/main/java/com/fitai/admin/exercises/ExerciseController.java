package com.fitai.admin.exercises;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.fitai.admin.common.api.PageResponse;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/admin/v1/exercises")
public class ExerciseController {

    private final ExerciseRepository repository;
    private final ExerciseService service;

    public ExerciseController(ExerciseRepository repository, ExerciseService service) {
        this.repository = repository;
        this.service = service;
    }

    @GetMapping
    @PreAuthorize("hasAuthority('exercise:read')")
    public PageResponse<ExerciseDtos.ExerciseItem> list(
            @RequestParam(required = false) String q,
            @RequestParam(required = false) String muscleGroup,
            @RequestParam(required = false) String equipment,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "50") int size
    ) {
        return repository.list(q, muscleGroup, equipment, page, size);
    }

    @PatchMapping("/{slug}")
    @PreAuthorize("hasAuthority('exercise:write')")
    public ExerciseDtos.ExerciseItem update(
            @PathVariable String slug,
            @Valid @RequestBody ExerciseDtos.PatchExerciseRequest request
    ) {
        return service.update(slug, request);
    }
}
