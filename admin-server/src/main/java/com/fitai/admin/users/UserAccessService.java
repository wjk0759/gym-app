package com.fitai.admin.users;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.fitai.admin.common.api.ApiException;
import com.fitai.admin.common.audit.AuditService;
import com.fitai.admin.security.AdminPrincipal;
import com.fitai.admin.security.CurrentAdmin;

@Service
public class UserAccessService {

    private static final Set<String> TRIAL_FEATURES = Set.of("training_plan", "meal_plan");

    private final UserAccessRepository repository;
    private final AuditService auditService;

    public UserAccessService(UserAccessRepository repository, AuditService auditService) {
        this.repository = repository;
        this.auditService = auditService;
    }

    public UserAccessDtos.UserAccess access(String userId) {
        return repository.access(userId)
                .orElseThrow(() -> ApiException.notFound("USER_NOT_FOUND", "用户不存在"));
    }

    @Transactional
    public UserAccessDtos.UserAccess grant(
            String userId,
            UserAccessDtos.GrantRequest request
    ) {
        if (!repository.exists(userId)) {
            throw ApiException.notFound("USER_NOT_FOUND", "用户不存在");
        }
        int days = request.durationDays() == null ? 30 : request.durationDays();
        if (days < 1 || days > 3650) {
            throw ApiException.badRequest("INVALID_MEMBERSHIP_DURATION", "会员时长需在 1–3650 天之间");
        }
        String reason = request.reason() == null ? "" : request.reason().trim();
        if (reason.isEmpty()) {
            throw ApiException.badRequest("REASON_REQUIRED", "请填写操作原因");
        }
        String adminId = CurrentAdmin.find().map(AdminPrincipal::id).orElse(null);
        repository.grant(userId, days, reason, adminId);
        UserAccessDtos.UserAccess updated = access(userId);
        Map<String, Object> detail = new LinkedHashMap<>();
        detail.put("plan", "pro");
        detail.put("durationDays", days);
        detail.put("reason", reason);
        if (updated.proExpiresAt() != null) {
            detail.put("proExpiresAt", updated.proExpiresAt());
        }
        auditService.record(
                "USER_ENTITLEMENT_GRANTED",
                "user",
                userId,
                detail
        );
        return updated;
    }

    @Transactional
    public UserAccessDtos.UserAccess revoke(
            String userId,
            String entitlementId,
            UserAccessDtos.RevokeRequest request
    ) {
        String reason = request.reason() == null ? "" : request.reason().trim();
        if (reason.isEmpty()) {
            throw ApiException.badRequest("REASON_REQUIRED", "请填写撤销原因");
        }
        if (!repository.revoke(userId, entitlementId, reason)) {
            throw ApiException.notFound("ENTITLEMENT_NOT_FOUND", "会员权益不存在或已撤销");
        }
        auditService.record(
                "USER_ENTITLEMENT_REVOKED",
                "user",
                userId,
                Map.of("entitlementId", entitlementId, "reason", reason)
        );
        return access(userId);
    }

    @Transactional
    public UserAccessDtos.UserAccess resetTrial(String userId, String featureKey) {
        if (!TRIAL_FEATURES.contains(featureKey)) {
            throw ApiException.badRequest("INVALID_FEATURE", "不支持重置该功能体验");
        }
        if (!repository.exists(userId)) {
            throw ApiException.notFound("USER_NOT_FOUND", "用户不存在");
        }
        repository.resetTrial(userId, featureKey);
        auditService.record(
                "USER_TRIAL_RESET",
                "user",
                userId,
                Map.of("feature", featureKey)
        );
        return access(userId);
    }
}
