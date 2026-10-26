package com.fitai.admin.common.persistence;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class SqlSupportTest {

    @Test
    void normalizesSearchPaginationAndDates() {
        assertThat(SqlSupport.like("  Alice ")).isEqualTo("%alice%");
        assertThat(SqlSupport.like("  ")).isNull();
        assertThat(SqlSupport.page(-1)).isEqualTo(1);
        assertThat(SqlSupport.size(1000)).isEqualTo(100);
        assertThat(SqlSupport.offset(3, 20)).isEqualTo(40);
        assertThat(SqlSupport.iso(null)).isNull();
        assertThat(SqlSupport.longValue(null)).isZero();
    }
}
