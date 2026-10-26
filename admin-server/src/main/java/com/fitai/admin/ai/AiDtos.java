package com.fitai.admin.ai;

import java.util.List;

public final class AiDtos {

    private AiDtos() {
    }

    public record AiOverview(
            long total,
            long ok,
            long fallback,
            long error,
            long avgLatencyMs,
            long p95LatencyMs,
            long inputTokens,
            long outputTokens,
            List<DailyPoint> daily,
            List<KindPoint> kinds,
            List<SkillInfo> skills
    ) {
    }

    public record DailyPoint(String date, long total, long errors) {
    }

    public record KindPoint(String kind, String label, long total, long errors) {
    }

    public record SkillInfo(String key, String name, String description, String promptVersion) {
    }

    public record AiJobItem(
            String id,
            String userId,
            String userLabel,
            String kind,
            String kindLabel,
            String model,
            String promptVersion,
            Integer inputTokens,
            Integer outputTokens,
            Integer latencyMs,
            String status,
            String error,
            String createdAt
    ) {
    }
}
