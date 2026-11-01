package com.fitai.admin.common.persistence;

import java.sql.Timestamp;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.Map;

public final class SqlSupport {

    private SqlSupport() {
    }

    public static void putSearchParams(Map<String, Object> params, String query) {
        String trimmed = query.trim();
        params.put("prefix", trimmed + "%");
        params.put("matchQuery", trimmed);
        params.put("rawQuery", trimmed);
    }

    /** Index-driven user IDs: exact id, phone/username prefix, nickname ngram. */
    public static String userIdsSubquery() {
        return "(SELECT id FROM users WHERE id = :rawQuery"
                + " UNION SELECT id FROM users WHERE phone LIKE :prefix"
                + " UNION SELECT id FROM users WHERE username LIKE :prefix"
                + " UNION SELECT user_id FROM profiles WHERE MATCH(nickname) AGAINST (:matchQuery)"
                + " UNION SELECT user_id FROM profiles WHERE nickname LIKE :prefix)";
    }

    public static String userSearchFrom(String userAlias, boolean hasQuery) {
        if (!hasQuery) {
            return " users " + userAlias + " ";
        }
        return " " + userIdsSubquery() + " ids STRAIGHT_JOIN users " + userAlias
                + " ON " + userAlias + ".id = ids.id ";
    }

    /** FROM fragment for a table filtered only by its owning user. */
    public static String userOwnedFrom(
            String table,
            String alias,
            String userColumn,
            boolean hasQuery
    ) {
        if (!hasQuery) {
            return " " + table + " " + alias + " ";
        }
        return " " + userIdsSubquery() + " ids STRAIGHT_JOIN " + table + " " + alias
                + " ON " + alias + "." + userColumn + " = ids.id ";
    }

    /**
     * FROM fragment for a user-owned table. When a query is present, resolve
     * candidate IDs from indexed text/user branches first, then STRAIGHT_JOIN
     * back to the table so MySQL cannot drive from a full table scan.
     */
    public static String entitySearchFrom(
            String table,
            String alias,
            String primaryKey,
            String userColumn,
            String textClause,
            boolean hasQuery
    ) {
        if (!hasQuery) {
            return " " + table + " " + alias + " ";
        }
        StringBuilder ids = new StringBuilder("(");
        if (textClause != null && !textClause.isBlank()) {
            ids.append("SELECT ").append(primaryKey)
                    .append(" FROM ").append(table)
                    .append(" WHERE ").append(textClause)
                    .append(" UNION ");
        }
        ids.append("SELECT ").append(primaryKey)
                .append(" FROM ").append(table)
                .append(" WHERE ").append(userColumn)
                .append(" IN (").append(userIdsSubquery()).append("))");
        return " " + ids + " ids STRAIGHT_JOIN " + table + " " + alias
                + " ON " + alias + "." + primaryKey + " = ids.id ";
    }

    public static String entityTextSearchFrom(
            String table,
            String alias,
            String primaryKey,
            String textClause,
            boolean hasQuery
    ) {
        if (!hasQuery) {
            return " " + table + " " + alias + " ";
        }
        return " (SELECT " + primaryKey + " FROM " + table
                + " WHERE " + textClause + ") ids STRAIGHT_JOIN " + table + " " + alias
                + " ON " + alias + "." + primaryKey + " = ids.id ";
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
