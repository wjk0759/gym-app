package com.fitai.admin.scans;

import java.util.List;

public final class ScanDtos {

    private ScanDtos() {
    }

    public record ScanListItem(
            String id,
            String userId,
            String userLabel,
            String imageUrl,
            String status,
            String model,
            int resultCount,
            Object topResult,
            String createdAt
    ) {
    }

    public record ScanDetail(ScanListItem scan, Object result) {
    }

    public record ScanSummary(
            long total,
            long last7d,
            long zeroCandidate,
            double zeroCandidateRate,
            double avgCandidates,
            long unavailable,
            List<ModelCount> models,
            List<StatusCount> statuses,
            List<DailyPoint> daily
    ) {
    }

    public record ModelCount(String model, long count) {
    }

    public record StatusCount(String status, long count) {
    }

    public record DailyPoint(String date, long count) {
    }
}
