package com.fitai.admin.videos;

import java.util.Map;
import java.util.Objects;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.fitai.admin.common.api.ApiException;
import com.fitai.admin.common.audit.AuditService;
import com.fitai.admin.media.MediaService;
import com.fitai.admin.security.CurrentAdmin;

@Service
public class VideoService {

    private final VideoRepository repository;
    private final MediaService mediaService;
    private final AuditService auditService;

    public VideoService(VideoRepository repository, MediaService mediaService, AuditService auditService) {
        this.repository = repository;
        this.mediaService = mediaService;
        this.auditService = auditService;
    }

    public VideoDtos.VideoItem get(String id) {
        return repository.find(id)
                .orElseThrow(() -> ApiException.notFound("VIDEO_NOT_FOUND", "教学视频不存在"));
    }

    @Transactional
    public VideoDtos.VideoItem create(VideoDtos.CreateVideoRequest request) {
        if (!repository.exerciseExists(request.exerciseSlug())) {
            throw ApiException.notFound("EXERCISE_NOT_FOUND", "动作不存在");
        }
        validateUrl(request.videoUrl(), "视频地址");
        if (request.posterUrl() != null && !request.posterUrl().isBlank()) {
            validateUrl(request.posterUrl(), "封面地址");
        }
        String status = request.status() == null || request.status().isBlank() ? "draft" : request.status();
        if (!"draft".equals(status) && !"published".equals(status)) {
            throw ApiException.badRequest("INVALID_VIDEO_STATUS", "新视频状态仅支持 draft 或 published");
        }
        String id = repository.create(request, CurrentAdmin.require().getUsername(), status);
        if ("published".equals(status)) {
            repository.publish(id);
        }
        auditService.record("VIDEO_CREATED", "exercise_video", id,
                Map.of("exerciseSlug", request.exerciseSlug(), "status", status));
        return get(id);
    }

    @Transactional
    public VideoDtos.VideoItem update(String id, VideoDtos.UpdateVideoRequest request) {
        VideoDtos.VideoItem old = get(id);
        if (request.isEmpty()) {
            throw ApiException.badRequest("EMPTY_PATCH", "至少提交一个要修改的字段");
        }
        if (request.videoUrl() != null) {
            validateUrl(request.videoUrl(), "视频地址");
        }
        if (request.posterUrl() != null && !request.posterUrl().isBlank()) {
            validateUrl(request.posterUrl(), "封面地址");
        }
        repository.update(id, request);
        if ("published".equals(old.status())) {
            repository.syncExerciseVideo(old.exerciseSlug());
        }
        if (request.videoUrl() != null && !Objects.equals(request.videoUrl(), old.videoUrl())) {
            mediaService.deleteByUrl(old.videoUrl());
        }
        if (request.posterUrl() != null && !Objects.equals(request.posterUrl(), old.posterUrl())) {
            mediaService.deleteByUrl(old.posterUrl());
        }
        auditService.record("VIDEO_UPDATED", "exercise_video", id,
                Map.of("fields", changedFields(request)));
        return get(id);
    }

    @Transactional
    public VideoDtos.VideoItem publish(String id) {
        VideoDtos.VideoItem video = get(id);
        repository.publish(id);
        auditService.record("VIDEO_PUBLISHED", "exercise_video", id,
                Map.of("exerciseSlug", video.exerciseSlug()));
        return get(id);
    }

    @Transactional
    public VideoDtos.VideoItem unpublish(String id) {
        VideoDtos.VideoItem video = get(id);
        repository.unpublish(id);
        auditService.record("VIDEO_UNPUBLISHED", "exercise_video", id,
                Map.of("exerciseSlug", video.exerciseSlug()));
        return get(id);
    }

    @Transactional
    public void delete(String id) {
        VideoDtos.VideoItem video = get(id);
        repository.delete(id);
        repository.syncExerciseVideo(video.exerciseSlug());
        mediaService.deleteByUrl(video.videoUrl());
        mediaService.deleteByUrl(video.posterUrl());
        auditService.record("VIDEO_DELETED", "exercise_video", id,
                Map.of("exerciseSlug", video.exerciseSlug()));
    }

    private java.util.List<String> changedFields(VideoDtos.UpdateVideoRequest request) {
        java.util.List<String> fields = new java.util.ArrayList<>();
        if (request.title() != null) fields.add("title");
        if (request.description() != null) fields.add("description");
        if (request.videoUrl() != null) fields.add("videoUrl");
        if (request.posterUrl() != null) fields.add("posterUrl");
        if (request.durationSeconds() != null) fields.add("durationSeconds");
        if (request.source() != null) fields.add("source");
        if (request.licenseNote() != null) fields.add("licenseNote");
        if (request.licenseExpiresAt() != null) fields.add("licenseExpiresAt");
        return fields;
    }

    private void validateUrl(String url, String label) {
        String value = url == null ? "" : url.trim();
        if (value.isBlank()) {
            throw ApiException.badRequest("INVALID_MEDIA_URL", label + "不能为空");
        }
        if (!(value.startsWith("/media/") || value.startsWith("https://") || value.startsWith("http://"))) {
            throw ApiException.badRequest("INVALID_MEDIA_URL", label + "必须是 /media/ 路径或 http(s) 地址");
        }
    }
}
