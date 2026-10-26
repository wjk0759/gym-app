package com.fitai.admin.scans;

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
@RequestMapping("/api/admin/v1/scans")
public class ScanController {

    private final ScanRepository repository;
    private final ScanService service;

    public ScanController(ScanRepository repository, ScanService service) {
        this.repository = repository;
        this.service = service;
    }

    @GetMapping
    @PreAuthorize("hasAuthority('scan:read')")
    public PageResponse<ScanDtos.ScanListItem> list(
            @RequestParam(required = false) String q,
            @RequestParam(required = false) String status,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        return repository.list(q, status, page, size);
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAuthority('scan:read')")
    public ScanDtos.ScanDetail detail(@PathVariable String id) {
        return service.detail(id);
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAuthority('scan:write')")
    public ResponseEntity<Void> delete(@PathVariable String id) {
        service.delete(id);
        return ResponseEntity.noContent().build();
    }
}
