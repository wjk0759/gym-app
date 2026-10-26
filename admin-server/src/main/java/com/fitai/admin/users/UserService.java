package com.fitai.admin.users;

import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fitai.admin.common.api.ApiException;
import com.fitai.admin.common.audit.AuditService;

@Service
public class UserService {

    private final UserRepository repository;
    private final AuditService auditService;
    private final ObjectMapper objectMapper;

    public UserService(UserRepository repository, AuditService auditService, ObjectMapper objectMapper) {
        this.repository = repository;
        this.auditService = auditService;
        this.objectMapper = objectMapper;
    }

    public UserDtos.UserDetail detail(String id) {
        return repository.detail(id)
                .orElseThrow(() -> ApiException.notFound("USER_NOT_FOUND", "用户不存在"));
    }

    public byte[] export(String id) {
        UserDtos.UserDetail detail = detail(id);
        auditService.record("USER_EXPORTED", "user", id, Map.of("format", "json"));
        try {
            return objectMapper.writerWithDefaultPrettyPrinter().writeValueAsBytes(detail);
        } catch (JsonProcessingException ex) {
            throw new IllegalStateException("导出用户数据失败", ex);
        }
    }

    @Transactional
    public void setStatus(String id, String status) {
        if (!"active".equals(status) && !"suspended".equals(status)) {
            throw ApiException.badRequest("INVALID_USER_STATUS", "用户状态仅支持 active 或 suspended");
        }
        if (!repository.exists(id)) {
            throw ApiException.notFound("USER_NOT_FOUND", "用户不存在");
        }
        if (!repository.setStatus(id, status)) {
            throw new ApiException(HttpStatus.CONFLICT, "USER_DELETED", "已删除用户不能直接修改状态，请先恢复");
        }
        auditService.record("USER_STATUS_CHANGED", "user", id, Map.of("status", status));
    }

    @Transactional
    public void delete(String id) {
        if (!repository.exists(id)) {
            throw ApiException.notFound("USER_NOT_FOUND", "用户不存在");
        }
        if (!repository.softDelete(id)) {
            throw new ApiException(HttpStatus.CONFLICT, "USER_ALREADY_DELETED", "用户已被删除");
        }
        auditService.record("USER_DELETED", "user", id, Map.of("softDelete", true));
    }

    @Transactional
    public void restore(String id) {
        if (!repository.exists(id)) {
            throw ApiException.notFound("USER_NOT_FOUND", "用户不存在");
        }
        if (!repository.restore(id)) {
            throw new ApiException(HttpStatus.CONFLICT, "USER_NOT_DELETED", "用户当前未被删除");
        }
        auditService.record("USER_RESTORED", "user", id, Map.of("status", "active"));
    }

    public String fileName(String id) {
        return "fitai-user-" + id + ".json";
    }
}
