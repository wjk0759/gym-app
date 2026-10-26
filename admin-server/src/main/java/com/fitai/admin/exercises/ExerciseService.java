package com.fitai.admin.exercises;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.fitai.admin.common.api.ApiException;
import com.fitai.admin.common.audit.AuditService;

@Service
public class ExerciseService {

    private final ExerciseRepository repository;
    private final AuditService auditService;

    public ExerciseService(ExerciseRepository repository, AuditService auditService) {
        this.repository = repository;
        this.auditService = auditService;
    }

    @Transactional
    public ExerciseDtos.ExerciseItem update(String slug, ExerciseDtos.PatchExerciseRequest request) {
        if (request.isEmpty()) {
            throw ApiException.badRequest("EMPTY_PATCH", "至少提交一个要修改的字段");
        }
        repository.find(slug)
                .orElseThrow(() -> ApiException.notFound("EXERCISE_NOT_FOUND", "动作不存在"));
        repository.update(slug, request);
        List<String> fields = new ArrayList<>();
        if (request.nameZh() != null) fields.add("nameZh");
        if (request.nameEn() != null) fields.add("nameEn");
        if (request.muscleGroup() != null) fields.add("muscleGroup");
        if (request.equipment() != null) fields.add("equipment");
        if (request.compound() != null) fields.add("compound");
        if (request.difficulty() != null) fields.add("difficulty");
        if (request.instructions() != null) fields.add("instructions");
        if (request.videoUrl() != null) fields.add("videoUrl");
        if (request.thumbnailUrl() != null) fields.add("thumbnailUrl");
        if (request.contraindications() != null) fields.add("contraindications");
        if (request.source() != null) fields.add("source");
        if (request.license() != null) fields.add("license");
        auditService.record("EXERCISE_UPDATED", "exercise", slug, Map.of("fields", fields));
        return repository.find(slug)
                .orElseThrow(() -> ApiException.notFound("EXERCISE_NOT_FOUND", "动作不存在"));
    }
}
