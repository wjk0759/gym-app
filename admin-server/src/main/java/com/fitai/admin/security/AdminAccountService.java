package com.fitai.admin.security;

import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.fitai.admin.common.api.ApiException;
import com.fitai.admin.common.audit.AuditService;

@Service
public class AdminAccountService {

    private final AdminAccountRepository repository;
    private final PasswordEncoder passwordEncoder;
    private final AuditService auditService;

    public AdminAccountService(
            AdminAccountRepository repository,
            PasswordEncoder passwordEncoder,
            AuditService auditService
    ) {
        this.repository = repository;
        this.passwordEncoder = passwordEncoder;
        this.auditService = auditService;
    }

    public List<AdminAccountSummary> list() {
        return repository.listSummaries();
    }

    public List<AdminAccountDtos.RoleOption> roles() {
        return repository.roleOptions();
    }

    @Transactional
    public AdminAccountSummary create(AdminAccountDtos.CreateAdminAccountRequest request) {
        String username = request.username().trim();
        if (repository.existsUsername(username)) {
            throw ApiException.conflict("ADMIN_USERNAME_EXISTS", "管理员账号已存在");
        }
        PasswordPolicy.validate(request.password());
        String roleId = validateRoleIds(List.of(request.roleCode())).getFirst();
        String id = UUID.randomUUID().toString();
        repository.insertAdminUser(
                id,
                username,
                passwordEncoder.encode(request.password()),
                request.displayName().trim()
        );
        repository.assignRole(id, roleId);
        auditService.record("ADMIN_ACCOUNT_CREATED", "admin_user", id,
                Map.of("username", username, "role", request.roleCode()));
        return findSummary(id);
    }

    @Transactional
    public AdminAccountSummary update(String id, AdminAccountDtos.UpdateAdminAccountRequest request) {
        if (request.isEmpty()) {
            throw ApiException.badRequest("EMPTY_PATCH", "至少提交一个要修改的字段");
        }
        AdminAccountRow account = repository.findById(id)
                .orElseThrow(() -> ApiException.notFound("ADMIN_ACCOUNT_NOT_FOUND", "管理员账号不存在"));
        AdminPrincipal current = CurrentAdmin.require();
        if (current.id().equals(id) && request.status() != null && !"active".equals(request.status())) {
            throw ApiException.forbidden("CANNOT_DISABLE_SELF", "不能停用当前登录的管理员账号");
        }
        List<String> roleIds = null;
        if (request.roleCodes() != null) {
            Set<String> codes = new LinkedHashSet<>(request.roleCodes());
            if (codes.isEmpty()) {
                throw ApiException.badRequest("ROLE_REQUIRED", "管理员至少需要保留一个角色");
            }
            if (codes.size() != request.roleCodes().size()) {
                throw ApiException.badRequest("DUPLICATE_ROLE", "角色不能重复");
            }
            if (current.id().equals(id) && !codes.contains("SUPER_ADMIN")) {
                throw ApiException.forbidden("CANNOT_REMOVE_OWN_SUPER_ADMIN", "不能移除当前账号的超级管理员角色");
            }
            if (!current.id().equals(id) && repository.isSuperAdmin(id)
                    && !codes.contains("SUPER_ADMIN") && repository.countSuperAdmins() <= 1) {
                throw new ApiException(HttpStatus.CONFLICT, "LAST_SUPER_ADMIN",
                        "系统必须保留至少一个启用中的超级管理员");
            }
            roleIds = validateRoleIds(request.roleCodes());
        }
        repository.updateProfile(id,
                request.displayName() == null ? null : blankToNull(request.displayName()),
                request.status());
        if (roleIds != null) {
            repository.replaceRoles(id, roleIds);
        }
        Map<String, Object> detail = new LinkedHashMap<>();
        detail.put("username", account.username());
        if (request.displayName() != null) detail.put("displayName", request.displayName());
        if (request.status() != null) detail.put("status", request.status());
        if (request.roleCodes() != null) detail.put("roles", request.roleCodes());
        auditService.record("ADMIN_ACCOUNT_UPDATED", "admin_user", id, detail);
        return findSummary(id);
    }

    @Transactional
    public void resetPassword(String id, AdminAccountDtos.ResetAdminPasswordRequest request) {
        AdminPrincipal current = CurrentAdmin.require();
        if (current.id().equals(id)) {
            throw ApiException.badRequest("USE_PASSWORD_CHANGE", "修改自己的密码请使用修改密码功能");
        }
        AdminAccountRow account = repository.findById(id)
                .orElseThrow(() -> ApiException.notFound("ADMIN_ACCOUNT_NOT_FOUND", "管理员账号不存在"));
        PasswordPolicy.validate(request.password());
        repository.resetPassword(id, passwordEncoder.encode(request.password()));
        repository.revokeAllRefreshTokens(id);
        auditService.record("ADMIN_ACCOUNT_PASSWORD_RESET", "admin_user", id,
                Map.of("username", account.username()));
    }

    private List<String> validateRoleIds(List<String> codes) {
        List<String> roleIds = repository.roleIdsByCodes(codes);
        if (roleIds.size() != codes.size()) {
            throw ApiException.badRequest("INVALID_ROLE", "包含不存在的角色");
        }
        return roleIds;
    }

    private AdminAccountSummary findSummary(String id) {
        return repository.listSummaries().stream()
                .filter(item -> item.id().equals(id))
                .findFirst()
                .orElseThrow(() -> ApiException.notFound("ADMIN_ACCOUNT_NOT_FOUND", "管理员账号不存在"));
    }

    private String blankToNull(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }
}
