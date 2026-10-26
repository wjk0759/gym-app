package com.fitai.admin.security;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/admin/v1/admin-users")
public class AdminAccountController {

    private final AdminAccountService service;

    public AdminAccountController(AdminAccountService service) {
        this.service = service;
    }

    @GetMapping
    @PreAuthorize("hasAuthority('settings:manage')")
    public List<AdminAccountSummary> list() {
        return service.list();
    }

    @GetMapping("/roles")
    @PreAuthorize("hasAuthority('settings:manage')")
    public List<AdminAccountDtos.RoleOption> roles() {
        return service.roles();
    }

    @PostMapping
    @PreAuthorize("hasAuthority('settings:manage')")
    public ResponseEntity<AdminAccountSummary> create(
            @Valid @RequestBody AdminAccountDtos.CreateAdminAccountRequest request
    ) {
        return ResponseEntity.status(201).body(service.create(request));
    }

    @PatchMapping("/{id}")
    @PreAuthorize("hasAuthority('settings:manage')")
    public AdminAccountSummary update(
            @PathVariable String id,
            @Valid @RequestBody AdminAccountDtos.UpdateAdminAccountRequest request
    ) {
        return service.update(id, request);
    }

    @PostMapping("/{id}/reset-password")
    @PreAuthorize("hasAuthority('settings:manage')")
    public ResponseEntity<Void> resetPassword(
            @PathVariable String id,
            @Valid @RequestBody AdminAccountDtos.ResetAdminPasswordRequest request
    ) {
        service.resetPassword(id, request);
        return ResponseEntity.noContent().build();
    }
}
