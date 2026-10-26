package com.fitai.admin.videos;

import java.time.LocalDate;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public final class VideoDtos {

    private VideoDtos() {
    }

    public record VideoItem(
            String id,
            String exerciseSlug,
            String exerciseName,
            String title,
            String description,
            String videoUrl,
            String posterUrl,
            Integer durationSeconds,
            String source,
            String licenseNote,
            LocalDate licenseExpiresAt,
            String status,
            int version,
            String createdBy,
            String createdAt,
            String updatedAt
    ) {
    }

    public record CreateVideoRequest(
            @NotBlank(message = "请选择动作") String exerciseSlug,
            @NotBlank(message = "请输入视频标题") @Size(max = 120) String title,
            @Size(max = 5000) String description,
            @NotBlank(message = "请上传或填写视频地址") @Size(max = 2000) String videoUrl,
            @Size(max = 2000) String posterUrl,
            @Min(0) Integer durationSeconds,
            @Size(max = 80) String source,
            @Size(max = 200) String licenseNote,
            LocalDate licenseExpiresAt,
            String status
    ) {
    }

    public record UpdateVideoRequest(
            @Size(max = 120) String title,
            @Size(max = 5000) String description,
            @Size(max = 2000) String videoUrl,
            @Size(max = 2000) String posterUrl,
            @Min(0) Integer durationSeconds,
            @Size(max = 80) String source,
            @Size(max = 200) String licenseNote,
            LocalDate licenseExpiresAt
    ) {
        public boolean isEmpty() {
            return title == null && description == null && videoUrl == null && posterUrl == null
                    && durationSeconds == null && source == null && licenseNote == null
                    && licenseExpiresAt == null;
        }
    }
}
