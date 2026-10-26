package com.fitai.admin.scans;

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
}
