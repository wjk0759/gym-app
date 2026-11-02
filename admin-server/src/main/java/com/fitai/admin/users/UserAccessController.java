package com.fitai.admin.users;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/admin/v1/users")
public class UserAccessController {

    private final UserAccessService service;

    public UserAccessController(UserAccessService service) {
        this.service = service;
    }

    @GetMapping("/{id}/access")
    @PreAuthorize("hasAuthority('user:read')")
    public UserAccessDtos.UserAccess access(@PathVariable String id) {
        return service.access(id);
    }

    @PostMapping("/{id}/entitlements")
    @PreAuthorize("hasAuthority('user:entitlement:write')")
    public UserAccessDtos.UserAccess grant(
            @PathVariable String id,
            @Valid @RequestBody UserAccessDtos.GrantRequest request
    ) {
        return service.grant(id, request);
    }

    @PostMapping("/{id}/entitlements/{entitlementId}/revoke")
    @PreAuthorize("hasAuthority('user:entitlement:write')")
    public UserAccessDtos.UserAccess revoke(
            @PathVariable String id,
            @PathVariable String entitlementId,
            @Valid @RequestBody UserAccessDtos.RevokeRequest request
    ) {
        return service.revoke(id, entitlementId, request);
    }

    @PostMapping("/{id}/trials/{featureKey}/reset")
    @PreAuthorize("hasAuthority('user:entitlement:write')")
    public UserAccessDtos.UserAccess resetTrial(
            @PathVariable String id,
            @PathVariable String featureKey
    ) {
        return service.resetTrial(id, featureKey);
    }
}
