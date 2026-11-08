package com.fitai.admin.mediaassets;

import java.time.LocalDate;
import java.util.List;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public final class MediaAssetDtos {

    private MediaAssetDtos() {
    }

    public record MediaAssetItem(
            String id,
            String exerciseSlug,
            String exerciseName,
            String sex,
            String source,
            String phoneUrl,
            String watchUrl,
            String posterUrl,
            Integer durationSeconds,
            Integer loopStartMs,
            Integer loopEndMs,
            String watchSha256,
            int version,
            String status,
            String licenseNote,
            LocalDate licenseExpiresAt,
            String purchaseRef,
            String createdAt,
            String updatedAt
    ) {
    }

    public record CreateMediaAssetRequest(
            @NotBlank(message = "请选择动作")
            String exerciseSlug,
            @NotBlank(message = "请选择性别版本")
            @Pattern(regexp = "male|female|unisex", message = "性别仅支持 male、female、unisex")
            String sex,
            @NotBlank(message = "请填写素材来源")
            @Size(max = 40, message = "来源最多 40 个字符")
            String source,
            @NotBlank(message = "请上传或填写 iPhone 视频")
            @Size(max = 2000, message = "iPhone 视频地址最多 2000 个字符")
            String phoneUrl,
            @NotBlank(message = "请上传或填写 Watch 视频")
            @Size(max = 2000, message = "Watch 视频地址最多 2000 个字符")
            String watchUrl,
            @Size(max = 2000, message = "封面地址最多 2000 个字符")
            String posterUrl,
            @Min(value = 0, message = "时长不能为负数")
            @Max(value = 86400, message = "时长不能超过 24 小时")
            Integer durationSeconds,
            @Min(value = 0, message = "循环起点不能为负数")
            Integer loopStartMs,
            @Min(value = 0, message = "循环终点不能为负数")
            Integer loopEndMs,
            @Pattern(regexp = "^[a-fA-F0-9]{64}$", message = "SHA-256 必须是 64 位十六进制")
            String watchSha256,
            @Size(max = 200, message = "许可说明最多 200 个字符")
            String licenseNote,
            LocalDate licenseExpiresAt,
            @Size(max = 120, message = "采购引用最多 120 个字符")
            String purchaseRef,
            String status
    ) {
    }

    public record UpdateMediaAssetRequest(
            @Size(max = 40, message = "来源最多 40 个字符")
            String source,
            @Size(max = 2000, message = "iPhone 视频地址最多 2000 个字符")
            String phoneUrl,
            @Size(max = 2000, message = "Watch 视频地址最多 2000 个字符")
            String watchUrl,
            @Size(max = 2000, message = "封面地址最多 2000 个字符")
            String posterUrl,
            @Min(value = 0, message = "时长不能为负数")
            @Max(value = 86400, message = "时长不能超过 24 小时")
            Integer durationSeconds,
            @Min(value = 0, message = "循环起点不能为负数")
            Integer loopStartMs,
            @Min(value = 0, message = "循环终点不能为负数")
            Integer loopEndMs,
            @Pattern(regexp = "^[a-fA-F0-9]{64}$", message = "SHA-256 必须是 64 位十六进制")
            String watchSha256,
            @Size(max = 200, message = "许可说明最多 200 个字符")
            String licenseNote,
            LocalDate licenseExpiresAt,
            @Size(max = 120, message = "采购引用最多 120 个字符")
            String purchaseRef
    ) {
        public boolean isEmpty() {
            return source == null
                    && phoneUrl == null
                    && watchUrl == null
                    && posterUrl == null
                    && durationSeconds == null
                    && loopStartMs == null
                    && loopEndMs == null
                    && watchSha256 == null
                    && licenseNote == null
                    && licenseExpiresAt == null
                    && purchaseRef == null;
        }
    }

    public record MediaCoverage(
            long activeExercises,
            long exercisesWithAnyMedia,
            long exercisesWithMale,
            long exercisesWithFemale,
            long exercisesWithUnisex,
            long phoneReady,
            long watchReady,
            long posterReady,
            long licenseExpiring30d,
            long missingAnyCount,
            long missingMaleCount,
            long missingFemaleCount,
            List<MissingExercise> missingAny,
            List<MissingExercise> missingMale,
            List<MissingExercise> missingFemale
    ) {
    }

    public record MissingExercise(
            String slug,
            String nameZh,
            String muscleGroup
    ) {
    }

    public record ImportResult(
            int total,
            int created,
            int failed,
            List<ImportError> errors
    ) {
    }

    public record ImportError(
            int line,
            String message
    ) {
    }

    public record MediaConfig(boolean uploadEnabled) {
    }
}
