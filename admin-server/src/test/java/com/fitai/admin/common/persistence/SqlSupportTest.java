package com.fitai.admin.common.persistence;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.HashMap;
import java.util.Map;

import org.junit.jupiter.api.Test;

class SqlSupportTest {

    @Test
    void normalizesSearchPaginationAndDates() {
        Map<String, Object> params = new HashMap<>();
        SqlSupport.putSearchParams(params, "  Alice ");
        assertThat(params).containsEntry("prefix", "Alice%");
        assertThat(params).containsEntry("matchQuery", "Alice");
        assertThat(params).containsEntry("rawQuery", "Alice");
        assertThat(SqlSupport.userIdsSubquery()).contains("MATCH(nickname)");
        assertThat(SqlSupport.userOwnedFrom("workout_sessions", "w", "user_id", true))
                .contains("STRAIGHT_JOIN workout_sessions w");
        assertThat(SqlSupport.userOwnedFrom("workout_sessions", "w", "user_id", false))
                .contains("workout_sessions w");
        assertThat(SqlSupport.page(-1)).isEqualTo(1);
        assertThat(SqlSupport.size(1000)).isEqualTo(100);
        assertThat(SqlSupport.offset(3, 20)).isEqualTo(40);
        assertThat(SqlSupport.iso(null)).isNull();
        assertThat(SqlSupport.longValue(null)).isZero();
    }
}
