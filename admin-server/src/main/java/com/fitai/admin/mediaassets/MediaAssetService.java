package com.fitai.admin.mediaassets;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

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

    public MediaAssetDtos.ImportResult importCsv(org.springframework.web.multipart.MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw ApiException.badRequest("EMPTY_FILE", "请选择 CSV 文件");
        }
        List<MediaAssetDtos.ImportError> errors = new ArrayList<>();
        int total = 0;
        int created = 0;
        try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(file.getInputStream(), StandardCharsets.UTF_8))) {
            String headerLine = reader.readLine();
            if (headerLine == null || headerLine.isBlank()) {
                throw ApiException.badRequest("EMPTY_CSV", "CSV 为空");
            }
            if (headerLine.startsWith("\uFEFF")) {
                headerLine = headerLine.substring(1);
            }
            List<String> headers = parseCsvLine(headerLine).stream()
                    .map(value -> value.trim().toLowerCase(Locale.ROOT))
                    .toList();
            Map<String, Integer> index = new LinkedHashMap<>();
            for (int i = 0; i < headers.size(); i++) {
                index.put(headers.get(i), i);
            }
            for (String required : List.of("exercise_slug", "sex", "phone_url", "watch_url")) {
                if (!index.containsKey(required)) {
                    throw ApiException.badRequest(
                            "INVALID_CSV_HEADER",
                            "CSV 缺少必填列：" + required
                    );
                }
            }
            String line;
            int lineNumber = 1;
            while ((line = reader.readLine()) != null) {
                lineNumber++;
                if (line.isBlank()) {
                    continue;
                }
                total++;
                if (total > 500) {
                    throw ApiException.badRequest("CSV_TOO_LARGE", "单次最多导入 500 行");
                }
                try {
                    List<String> columns = parseCsvLine(line);
                    String status = value(index, columns, "status");
                    create(new MediaAssetDtos.CreateMediaAssetRequest(
                            required(value(index, columns, "exercise_slug"), "exercise_slug"),
                            required(value(index, columns, "sex"), "sex").toLowerCase(Locale.ROOT),
                            defaultValue(value(index, columns, "source"), "import"),
                            required(value(index, columns, "phone_url"), "phone_url"),
                            required(value(index, columns, "watch_url"), "watch_url"),
                            value(index, columns, "poster_url"),
                            intValue(value(index, columns, "duration_seconds"), "duration_seconds"),
                            intValue(value(index, columns, "loop_start_ms"), "loop_start_ms"),
                            intValue(value(index, columns, "loop_end_ms"), "loop_end_ms"),
                            value(index, columns, "watch_sha256"),
                            value(index, columns, "license_note"),
                            dateValue(value(index, columns, "license_expires_at")),
                            value(index, columns, "purchase_ref"),
                            status == null || status.isBlank() ? "draft" : status
                    ));
                    created++;
                } catch (RuntimeException ex) {
                    errors.add(new MediaAssetDtos.ImportError(
                            lineNumber,
                            ex.getMessage() == null ? "导入失败" : ex.getMessage()
                    ));
                }
            }
        } catch (IOException ex) {
            throw new IllegalStateException("读取 CSV 失败", ex);
        }
        auditService.record("MEDIA_ASSET_IMPORTED", "exercise_media_asset", null,
                Map.of("total", total, "created", created, "failed", errors.size()));
        return new MediaAssetDtos.ImportResult(total, created, errors.size(), errors);
    }

    @Transactional
    public MediaAssetDtos.MediaAssetItem create(MediaAssetDtos.CreateMediaAssetRequest request) {
        if (request.sex() == null || !Set.of("male", "female", "unisex").contains(request.sex())) {
            throw ApiException.badRequest("INVALID_SEX", "性别仅支持 male、female、unisex");
        }
        if (request.loopStartMs() != null && request.loopEndMs() != null
                && request.loopEndMs() <= request.loopStartMs()) {
            throw ApiException.badRequest("INVALID_LOOP_RANGE", "循环终点必须大于循环起点");
        }
        if (request.watchSha256() != null && !request.watchSha256().isBlank()
                && !request.watchSha256().matches("^[a-fA-F0-9]{64}$")) {
            throw ApiException.badRequest("INVALID_SHA256", "SHA-256 必须是 64 位十六进制");
        }
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

    private List<String> parseCsvLine(String line) {
        List<String> fields = new ArrayList<>();
        StringBuilder current = new StringBuilder();
        boolean quoted = false;
        for (int i = 0; i < line.length(); i++) {
            char ch = line.charAt(i);
            if (ch == '"') {
                if (quoted && i + 1 < line.length() && line.charAt(i + 1) == '"') {
                    current.append('"');
                    i++;
                } else {
                    quoted = !quoted;
                }
            } else if (ch == ',' && !quoted) {
                fields.add(current.toString());
                current.setLength(0);
            } else {
                current.append(ch);
            }
        }
        fields.add(current.toString());
        return fields;
    }

    private String value(Map<String, Integer> index, List<String> columns, String key) {
        Integer position = index.get(key);
        if (position == null || position >= columns.size()) {
            return null;
        }
        String value = columns.get(position).trim();
        return value.isEmpty() ? null : value;
    }

    private String required(String value, String field) {
        if (value == null || value.isBlank()) {
            throw ApiException.badRequest("MISSING_CSV_FIELD", "缺少字段：" + field);
        }
        return value;
    }

    private String defaultValue(String value, String fallback) {
        return value == null || value.isBlank() ? fallback : value;
    }

    private Integer intValue(String value, String field) {
        if (value == null || value.isBlank()) {
            return null;
        }
        try {
            return Integer.parseInt(value);
        } catch (NumberFormatException ex) {
            throw ApiException.badRequest("INVALID_CSV_NUMBER", field + " 不是整数");
        }
    }

    private LocalDate dateValue(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        try {
            return LocalDate.parse(value);
        } catch (RuntimeException ex) {
            throw ApiException.badRequest("INVALID_CSV_DATE", "license_expires_at 不是 YYYY-MM-DD");
        }
    }
}
