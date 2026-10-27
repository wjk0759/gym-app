package com.fitai.admin.users;

import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.fitai.admin.common.api.PageResponse;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Pattern;

@RestController
@RequestMapping("/api/admin/v1/users")
public class UserController {

    private final UserRepository repository;
    private final UserService service;

    public UserController(UserRepository repository, UserService service) {
        this.repository = repository;
        this.service = service;
    }

    @GetMapping
    @PreAuthorize("hasAuthority('user:read')")
    public PageResponse<UserDtos.UserListItem> list(
            @RequestParam(required = false) String q,
            @RequestParam(required = false) String status,
            @RequestParam(defaultValue = "false") boolean includeDeleted,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        return repository.list(q, status, includeDeleted, page, size);
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAuthority('user:read')")
    public UserDtos.UserDetail detail(@PathVariable String id) {
        return service.detail(id);
    }

    @GetMapping("/{id}/export")
    @PreAuthorize("hasAuthority('user:read')")
    public ResponseEntity<byte[]> export(@PathVariable String id) {
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION,
                        "attachment; filename=\"" + service.fileName(id) + "\"")
                .contentType(MediaType.APPLICATION_JSON)
                .body(service.export(id));
    }

    @PatchMapping("/{id}/status")
    @PreAuthorize("hasAuthority('user:write')")
    public ResponseEntity<Void> status(
            @PathVariable String id,
            @Valid @RequestBody UpdateStatusRequest request
    ) {
        service.setStatus(id, request.status());
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAuthority('user:write')")
    public ResponseEntity<Void> delete(@PathVariable String id) {
        service.delete(id);
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping("/{id}/purge")
    @PreAuthorize("hasAuthority('user:write')")
    public ResponseEntity<Void> purge(@PathVariable String id) {
        service.purge(id);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/{id}/restore")
    @PreAuthorize("hasAuthority('user:write')")
    public ResponseEntity<Void> restore(@PathVariable String id) {
        service.restore(id);
        return ResponseEntity.noContent().build();
    }

    public record UpdateStatusRequest(
            @Pattern(regexp = "active|suspended", message = "状态仅支持 active 或 suspended")
            String status
    ) {
    }
}
