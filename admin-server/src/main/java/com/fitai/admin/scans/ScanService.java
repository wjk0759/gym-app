package com.fitai.admin.scans;

import java.util.Map;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.fitai.admin.common.api.ApiException;
import com.fitai.admin.common.audit.AuditService;

@Service
public class ScanService {

    private final ScanRepository repository;
    private final AuditService auditService;

    public ScanService(ScanRepository repository, AuditService auditService) {
        this.repository = repository;
        this.auditService = auditService;
    }

    public ScanDtos.ScanDetail detail(String id) {
        return repository.detail(id)
                .orElseThrow(() -> ApiException.notFound("SCAN_NOT_FOUND", "器械识别记录不存在"));
    }

    @Transactional
    public void delete(String id) {
        if (!repository.delete(id)) {
            throw ApiException.notFound("SCAN_NOT_FOUND", "器械识别记录不存在");
        }
        auditService.record("SCAN_DELETED", "equipment_scan", id, Map.of("hardDelete", true));
    }
}
