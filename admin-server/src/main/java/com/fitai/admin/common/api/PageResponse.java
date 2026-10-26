package com.fitai.admin.common.api;

import java.util.List;

/**
 * Stable page envelope used by every collection endpoint.
 * Page numbers are 1-based; size is capped by the caller.
 */
public record PageResponse<T>(
        List<T> items,
        int page,
        int size,
        long total,
        int totalPages
) {
    public static <T> PageResponse<T> of(List<T> items, int page, int size, long total) {
        int totalPages = size <= 0 ? 0 : (int) Math.ceil((double) total / size);
        return new PageResponse<>(items, page, size, total, totalPages);
    }
}
