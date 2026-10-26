package com.fitai.admin.workouts;

import java.util.Map;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.fitai.admin.common.api.ApiException;
import com.fitai.admin.common.audit.AuditService;

@Service
public class WorkoutService {

    private final WorkoutRepository repository;
    private final AuditService auditService;

    public WorkoutService(WorkoutRepository repository, AuditService auditService) {
        this.repository = repository;
        this.auditService = auditService;
    }

    public WorkoutDtos.WorkoutDetail detail(String id) {
        return repository.detail(id)
                .orElseThrow(() -> ApiException.notFound("WORKOUT_NOT_FOUND", "训练记录不存在"));
    }

    @Transactional
    public void delete(String id) {
        if (!repository.delete(id)) {
            throw ApiException.notFound("WORKOUT_NOT_FOUND", "训练记录不存在");
        }
        auditService.record("WORKOUT_DELETED", "workout_session", id, Map.of("hardDelete", true));
    }
}
