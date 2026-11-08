package com.fitai.admin.mediaassets;

import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.fitai.admin.common.api.ApiException;
import com.fitai.admin.common.audit.AuditService;
import com.fitai.admin.media.MediaService;

@Service
public class MediaAssetService {

    private final MediaAssetRepository repository;
    private final MediaService mediaService;
    private final AuditService auditService;

    public MediaAssetService(
            MediaAssetRepository repository,
            MediaService mediaService,
            AuditService auditService
    ) {
        this.repository = repository;
        this.mediaService = mediaService;
        this.auditService = auditService;
    }

    public MediaAssetDtos.MediaAssetItem get(String id) {
        return repository.find(id)
                .orElseThrow(() -> ApiException.notFound("MEDIA_ASSET_NOT_FOUND", "动作媒体不存在"));
    }

    public MediaAssetDtos.MediaCoverage coverage() {
        return repository.coverage();
    }

    @Transactional
    public MediaAssetDtos.MediaAssetItem create(MediaAssetDtos.CreateMediaAssetRequest request) {
        if (!repository.exerciseExists(request.exerciseSlug())) {
            throw ApiException.notFound("EXERCISE_NOT_FOUND", "动作不存在");
        }
        validateUrl(request.phoneUrl(), "iPhone 视频");
        validateUrl(request.watchUrl(), "Watch 视频");
        if (request.posterUrl() != null && !request.posterUrl().isBlank()) {
            validateUrl(request.posterUrl(), "封面");
        }
        String status = normalizeStatus(request.status(), "draft");
        String id = repository.create(new MediaAssetDtos.CreateMediaAssetRequest(
                request.exerciseSlug(),
                request.sex(),
                request.source().trim(),
                request.phoneUrl().trim(),
                request.watchUrl().trim(),
                blankToNull(request.posterUrl()),
                request.durationSeconds(),
                request.loopStartMs(),
                request.loopEndMs(),
                normalizeSha(request.watchSha256()),
                blankToNull(request.licenseNote()),
                request.licenseExpiresAt(),
                blankToNull(request.purchaseRef()),
                status
        ), status);
        if ("published".equals(status)) {
            repository.archiveOtherVersions(id, request.exerciseSlug(), request.sex());
            repository.updateStatus(id, "published");
        }
        auditService.record("MEDIA_ASSET_CREATED", "exercise_media_asset", id,
                Map.of("exerciseSlug", request.exerciseSlug(), "sex", request.sex(), "status", status));
        return get(id);
    }

    @Transactional
    public MediaAssetDtos.MediaAssetItem update(
            String id,
            MediaAssetDtos.UpdateMediaAssetRequest request
    ) {
        MediaAssetDtos.MediaAssetItem old = get(id);
        if (request.isEmpty()) {
            throw ApiException.badRequest("EMPTY_PATCH", "至少提交一个要修改的字段");
        }
        validateUrlIfPresent(request.phoneUrl(), "iPhone 视频");
        validateUrlIfPresent(request.watchUrl(), "Watch 视频");
        validateUrlIfPresent(request.posterUrl(), "封面");
        Integer loopStart = request.loopStartMs() == null ? old.loopStartMs() : request.loopStartMs();
        Integer loopEnd = request.loopEndMs() == null ? old.loopEndMs() : request.loopEndMs();
        if (loopStart != null && loopEnd != null && loopEnd <= loopStart) {
            throw ApiException.badRequest("INVALID_LOOP_RANGE", "循环终点必须大于循环起点");
        }
        String sha = request.watchSha256() == null ? old.watchSha256() : normalizeSha(request.watchSha256());
        repository.update(id, new MediaAssetDtos.UpdateMediaAssetRequest(
                trimIfPresent(request.source()),
                trimIfPresent(request.phoneUrl()),
                trimIfPresent(request.watchUrl()),
                trimAllowingEmpty(request.posterUrl()),
                request.durationSeconds(),
                request.loopStartMs(),
                request.loopEndMs(),
                sha,
                trimAllowingEmpty(request.licenseNote()),
                request.licenseExpiresAt(),
                trimAllowingEmpty(request.purchaseRef())
        ));
        deleteReplacedMedia(old.phoneUrl(), request.phoneUrl(), id);
        deleteReplacedMedia(old.watchUrl(), request.watchUrl(), id);
        deleteReplacedMedia(old.posterUrl(), request.posterUrl(), id);
        Map<String, Object> detail = new LinkedHashMap<>();
        detail.put("exerciseSlug", old.exerciseSlug());
        detail.put("sex", old.sex());
        detail.put("fields", changedFields(request));
        auditService.record("MEDIA_ASSET_UPDATED", "exercise_media_asset", id, detail);
        return get(id);
    }

    @Transactional
    public MediaAssetDtos.MediaAssetItem publish(String id) {
        MediaAssetDtos.MediaAssetItem asset = get(id);
        repository.archiveOtherVersions(id, asset.exerciseSlug(), asset.sex());
        repository.updateStatus(id, "published");
        auditService.record("MEDIA_ASSET_PUBLISHED", "exercise_media_asset", id,
                Map.of("exerciseSlug", asset.exerciseSlug(), "sex", asset.sex()));
        return get(id);
    }

    @Transactional
    public MediaAssetDtos.MediaAssetItem unpublish(String id) {
        MediaAssetDtos.MediaAssetItem asset = get(id);
        repository.updateStatus(id, "draft");
        auditService.record("MEDIA_ASSET_UNPUBLISHED", "exercise_media_asset", id,
                Map.of("exerciseSlug", asset.exerciseSlug(), "sex", asset.sex()));
        return get(id);
    }

    @Transactional
    public void delete(String id) {
        MediaAssetDtos.MediaAssetItem asset = get(id);
        repository.delete(id);
        deleteIfUnreferenced(asset.phoneUrl(), id);
        deleteIfUnreferenced(asset.watchUrl(), id);
        deleteIfUnreferenced(asset.posterUrl(), id);
        auditService.record("MEDIA_ASSET_DELETED", "exercise_media_asset", id,
                Map.of("exerciseSlug", asset.exerciseSlug(), "sex", asset.sex()));
    }

    private void deleteReplacedMedia(String oldUrl, String newUrl, String id) {
        if (newUrl == null || oldUrl == null || oldUrl.equals(newUrl)) {
            return;
        }
        deleteIfUnreferenced(oldUrl, id);
    }

    private void deleteIfUnreferenced(String url, String id) {
        if (url != null && !repository.isUrlReferenced(url, id)) {
            mediaService.deleteByUrl(url);
        }
    }

    private void validateUrlIfPresent(String url, String label) {
        if (url != null && !url.isBlank()) {
            validateUrl(url, label);
        }
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

    private String normalizeStatus(String raw, String fallback) {
        String status = raw == null || raw.isBlank() ? fallback : raw.trim().toLowerCase(Locale.ROOT);
        if (!status.equals("draft") && !status.equals("published")) {
            throw ApiException.badRequest("INVALID_MEDIA_STATUS", "新建媒体状态仅支持 draft 或 published");
        }
        return status;
    }

    private String normalizeSha(String sha) {
        String value = blankToNull(sha);
        return value == null ? null : value.toLowerCase(Locale.ROOT);
    }

    private String trimIfPresent(String value) {
        return value == null ? null : value.trim();
    }

    private String trimAllowingEmpty(String value) {
        return value == null ? null : value.trim();
    }

    private String blankToNull(String value) {
        if (value == null) {
            return null;
        }
        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }

    private java.util.List<String> changedFields(MediaAssetDtos.UpdateMediaAssetRequest request) {
        java.util.List<String> fields = new java.util.ArrayList<>();
        if (request.source() != null) fields.add("source");
        if (request.phoneUrl() != null) fields.add("phoneUrl");
        if (request.watchUrl() != null) fields.add("watchUrl");
        if (request.posterUrl() != null) fields.add("posterUrl");
        if (request.durationSeconds() != null) fields.add("durationSeconds");
        if (request.loopStartMs() != null) fields.add("loopStartMs");
        if (request.loopEndMs() != null) fields.add("loopEndMs");
        if (request.watchSha256() != null) fields.add("watchSha256");
        if (request.licenseNote() != null) fields.add("licenseNote");
        if (request.licenseExpiresAt() != null) fields.add("licenseExpiresAt");
        if (request.purchaseRef() != null) fields.add("purchaseRef");
        return fields;
    }
}
