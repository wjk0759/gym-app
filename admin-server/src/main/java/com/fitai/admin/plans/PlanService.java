package com.fitai.admin.plans;

import java.util.Map;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.fitai.admin.common.api.ApiException;
import com.fitai.admin.common.audit.AuditService;

@Service
public class PlanService {

    private final PlanRepository repository;
    private final AuditService auditService;

    public PlanService(PlanRepository repository, AuditService auditService) {
        this.repository = repository;
        this.auditService = auditService;
    }

    public PlanDtos.PlanDetail detail(String id) {
        return repository.detail(id)
                .orElseThrow(() -> ApiException.notFound("PLAN_NOT_FOUND", "训练计划不存在"));
    }

    @Transactional
    public void archive(String id) {
        if (!repository.archive(id)) {
            throw ApiException.notFound("PLAN_NOT_FOUND", "训练计划不存在");
        }
        auditService.record("PLAN_ARCHIVED", "program", id, Map.of("status", "archived"));
    }

    @Transactional
    public void activate(String id) {
        if (!repository.detail(id).isPresent()) {
            throw ApiException.notFound("PLAN_NOT_FOUND", "训练计划不存在");
        }
        repository.activate(id);
        auditService.record("PLAN_ACTIVATED", "program", id, Map.of("status", "active"));
    }
}
