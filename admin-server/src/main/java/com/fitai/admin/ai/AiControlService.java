package com.fitai.admin.ai;

import java.util.Map;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.fitai.admin.common.api.ApiException;
import com.fitai.admin.common.audit.AuditService;
import com.fitai.admin.security.AdminPrincipal;
import com.fitai.admin.security.CurrentAdmin;

@Service
public class AiControlService {

    private final AiRepository repository;
    private final AuditService auditService;

    public AiControlService(AiRepository repository, AuditService auditService) {
        this.repository = repository;
        this.auditService = auditService;
    }

    @Transactional
    public AiDtos.AiControl update(AiDtos.AiControlUpdate request) {
        boolean enabled = Boolean.TRUE.equals(request.enabled());
        String reason = request.reason() == null ? "" : request.reason().trim();
        if (!enabled && reason.isEmpty()) {
            throw ApiException.badRequest("AI_PAUSE_REASON_REQUIRED", "暂停 AI 时必须填写原因");
        }
        String adminId = CurrentAdmin.find().map(AdminPrincipal::id).orElse(null);
        repository.setControl(enabled, reason.isEmpty() ? null : reason, adminId);
        auditService.record(
                "AI_RUNTIME_CONTROL_CHANGED",
                "ai",
                "runtime",
                Map.of("enabled", enabled, "reason", reason)
        );
        return repository.control();
    }
}
