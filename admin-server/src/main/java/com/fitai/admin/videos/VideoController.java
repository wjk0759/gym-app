package com.fitai.admin.videos;

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
@RequestMapping("/api/admin/v1/videos")
public class VideoController {

    private final VideoRepository repository;
    private final VideoService service;
    private final MediaService mediaService;

    public VideoController(VideoRepository repository, VideoService service, MediaService mediaService) {
        this.repository = repository;
        this.service = service;
        this.mediaService = mediaService;
    }

    @GetMapping
    @PreAuthorize("hasAuthority('video:read')")
    public PageResponse<VideoDtos.VideoItem> list(
            @RequestParam(required = false) String q,
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String exerciseSlug,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        return repository.list(q, status, exerciseSlug, page, size);
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasAuthority('video:read')")
    public VideoDtos.VideoItem get(@PathVariable String id) {
        return service.get(id);
    }

    @PostMapping
    @PreAuthorize("hasAuthority('video:write')")
    public ResponseEntity<VideoDtos.VideoItem> create(@Valid @RequestBody VideoDtos.CreateVideoRequest request) {
        return ResponseEntity.status(201).body(service.create(request));
    }

    @PatchMapping("/{id}")
    @PreAuthorize("hasAuthority('video:write')")
    public VideoDtos.VideoItem update(
            @PathVariable String id,
            @Valid @RequestBody VideoDtos.UpdateVideoRequest request
    ) {
        return service.update(id, request);
    }

    @PostMapping("/{id}/publish")
    @PreAuthorize("hasAuthority('video:write')")
    public VideoDtos.VideoItem publish(@PathVariable String id) {
        return service.publish(id);
    }

    @PostMapping("/{id}/unpublish")
    @PreAuthorize("hasAuthority('video:write')")
    public VideoDtos.VideoItem unpublish(@PathVariable String id) {
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
