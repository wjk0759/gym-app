package com.fitai.admin.media;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import com.fitai.admin.common.api.ApiException;
import com.fitai.admin.config.MediaProperties;

@Service
public class MediaService {

    private static final Logger log = LoggerFactory.getLogger(MediaService.class);

    private static final Set<String> VIDEO_EXTENSIONS = Set.of("mp4", "mov", "webm");
    private static final Set<String> IMAGE_EXTENSIONS = Set.of("jpg", "jpeg", "png", "webp");
    private static final long IMAGE_LIMIT_BYTES = 10L * 1024 * 1024;

    private final MediaProperties properties;

    public MediaService(MediaProperties properties) {
        this.properties = properties;
    }

    public MediaUpload store(MultipartFile file, String kind) {
        String normalizedKind = normalizeKind(kind);
        if (file == null || file.isEmpty() || file.getOriginalFilename() == null) {
            throw ApiException.badRequest("EMPTY_FILE", "请选择要上传的文件");
        }
        String extension = extension(file.getOriginalFilename());
        if ("videos".equals(normalizedKind)) {
            requireExtension(extension, VIDEO_EXTENSIONS, "视频仅支持 mp4、mov、webm");
            if (file.getSize() > properties.maxVideoMb() * 1024 * 1024) {
                throw ApiException.badRequest("FILE_TOO_LARGE", "视频超过大小限制");
            }
        } else {
            requireExtension(extension, IMAGE_EXTENSIONS, "封面仅支持 jpg、png、webp");
            if (file.getSize() > IMAGE_LIMIT_BYTES) {
                throw ApiException.badRequest("FILE_TOO_LARGE", "封面文件超过 10MB");
            }
        }
        String fileName = UUID.randomUUID() + "." + extension;
        Path directory = Path.of(properties.root()).toAbsolutePath().normalize().resolve(normalizedKind);
        Path target = directory.resolve(fileName).normalize();
        if (!target.startsWith(directory)) {
            throw ApiException.badRequest("INVALID_PATH", "非法文件路径");
        }
        try {
            Files.createDirectories(directory);
            try (InputStream input = file.getInputStream()) {
                Files.copy(input, target, StandardCopyOption.REPLACE_EXISTING);
            }
        } catch (IOException ex) {
            throw new IllegalStateException("保存上传文件失败", ex);
        }
        return new MediaUpload("/media/" + normalizedKind + "/" + fileName,
                file.getOriginalFilename(), file.getSize(), file.getContentType());
    }

    public void deleteByUrl(String url) {
        if (url == null || !url.startsWith("/media/")) {
            return;
        }
        Path root = Path.of(properties.root()).toAbsolutePath().normalize();
        Path target = root.resolve(url.substring("/media/".length())).normalize();
        if (!target.startsWith(root)) {
            return;
        }
        try {
            Files.deleteIfExists(target);
        } catch (IOException ex) {
            log.warn("无法删除媒体文件 {}: {}", target, ex.getMessage());
        }
    }

    private String normalizeKind(String kind) {
        if ("video".equalsIgnoreCase(kind) || "videos".equalsIgnoreCase(kind)) {
            return "videos";
        }
        if ("poster".equalsIgnoreCase(kind) || "posters".equalsIgnoreCase(kind) || "image".equalsIgnoreCase(kind)) {
            return "posters";
        }
        throw ApiException.badRequest("INVALID_KIND", "上传类型仅支持 video 或 poster");
    }

    private String extension(String filename) {
        int dot = filename.lastIndexOf('.');
        if (dot < 0 || dot == filename.length() - 1) {
            throw ApiException.badRequest("INVALID_FILE", "文件缺少扩展名");
        }
        return filename.substring(dot + 1).toLowerCase(Locale.ROOT);
    }

    private void requireExtension(String extension, Set<String> allowed, String message) {
        if (!allowed.contains(extension)) {
            throw ApiException.badRequest("INVALID_FILE_TYPE", message);
        }
    }

    public record MediaUpload(String url, String originalName, long size, String contentType) {
    }
}
