package com.fitai.admin.common.persistence;

import java.sql.Timestamp;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.Locale;

public final class SqlSupport {

    private SqlSupport() {
    }

    public static String like(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        return "%" + value.trim().toLowerCase(Locale.ROOT) + "%";
    }

    public static String iso(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof Timestamp timestamp) {
            return timestamp.toInstant().toString();
        }
        if (value instanceof LocalDateTime localDateTime) {
            return localDateTime.toInstant(ZoneOffset.UTC).toString();
        }
        if (value instanceof OffsetDateTime offsetDateTime) {
            return offsetDateTime.toInstant().toString();
        }
        if (value instanceof Instant instant) {
            return instant.toString();
        }
        if (value instanceof LocalDate date) {
            return date.format(DateTimeFormatter.ISO_LOCAL_DATE);
        }
        if (value instanceof java.sql.Date date) {
            return date.toLocalDate().format(DateTimeFormatter.ISO_LOCAL_DATE);
        }
        return value.toString();
    }

    public static long longValue(Object value) {
        if (value == null) {
            return 0L;
        }
        if (value instanceof Number number) {
            return number.longValue();
        }
        return Long.parseLong(value.toString());
    }

    public static int intValue(Object value) {
        if (value == null) {
            return 0;
        }
        if (value instanceof Number number) {
            return number.intValue();
        }
        return Integer.parseInt(value.toString());
    }

    public static double doubleValue(Object value) {
        if (value == null) {
            return 0D;
        }
        if (value instanceof Number number) {
            return number.doubleValue();
        }
        return Double.parseDouble(value.toString());
    }

    public static int page(int page) {
        return Math.max(1, page);
    }

    public static int size(int size) {
        return Math.min(100, Math.max(1, size));
    }

    public static int offset(int page, int size) {
        return (page(page) - 1) * size(size);
    }
}
