package com.fitai.admin.mediaassets;

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
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import com.fitai.admin.common.api.PageResponse;
import com.fitai.admin.media.MediaService;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/admin/v1/media-assets")
public class MediaAssetController {

    private final MediaAssetRepository repository;
    private final MediaAssetService service;
    private final MediaService mediaService;

    public MediaAssetController(
            MediaAssetRepository repository,
            MediaAssetService service,
            MediaService mediaService
    ) {
        this.repository = repository;
        this.service = service;
        this.mediaService = mediaService;
    }

    @GetMapping
    @PreAuthorize("hasAuthority('video:read')")
    public PageResponse<MediaAssetDtos.MediaAssetItem> list(
            @RequestParam(required = false) String q,
            @RequestParam(required = false) String sex,
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String coverage,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        return repository.list(q, sex, status, coverage, page, size);
    }

    @GetMapping("/coverage")
    @PreAuthorize("hasAuthority('video:read')")
    public MediaAssetDtos.MediaCoverage coverage() {
        return service.coverage();
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAuthority('video:read')")
    public MediaAssetDtos.MediaAssetItem get(@PathVariable String id) {
        return service.get(id);
    }

    @PostMapping
    @PreAuthorize("hasAuthority('video:write')")
    public ResponseEntity<MediaAssetDtos.MediaAssetItem> create(
            @Valid @RequestBody MediaAssetDtos.CreateMediaAssetRequest request
    ) {
        return ResponseEntity.status(201).body(service.create(request));
    }

    @PatchMapping("/{id}")
    @PreAuthorize("hasAuthority('video:write')")
    public MediaAssetDtos.MediaAssetItem update(
            @PathVariable String id,
            @Valid @RequestBody MediaAssetDtos.UpdateMediaAssetRequest request
    ) {
        return service.update(id, request);
    }

    @PostMapping("/{id}/publish")
    @PreAuthorize("hasAuthority('video:write')")
    public MediaAssetDtos.MediaAssetItem publish(@PathVariable String id) {
        return service.publish(id);
    }

    @PostMapping("/{id}/unpublish")
    @PreAuthorize("hasAuthority('video:write')")
    public MediaAssetDtos.MediaAssetItem unpublish(@PathVariable String id) {
        return service.unpublish(id);
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAuthority('video:write')")
    public ResponseEntity<Void> delete(@PathVariable String id) {
        service.delete(id);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/upload")
    @PreAuthorize("hasAuthority('video:write')")
    public MediaService.MediaUpload upload(
            @RequestPart("file") MultipartFile file,
            @RequestParam(defaultValue = "video") String kind
    ) {
        return mediaService.store(file, kind);
    }
}
