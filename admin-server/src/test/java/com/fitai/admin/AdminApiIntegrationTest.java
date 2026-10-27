package com.fitai.admin;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.UUID;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * Full control-plane smoke test. Docker is required; the test is skipped on
 * developer machines without Docker and runs in CI.
 */
@Testcontainers(disabledWithoutDocker = true)
@SpringBootTest
@AutoConfigureMockMvc
class AdminApiIntegrationTest {

    @Container
    static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.4")
            .withDatabaseName("fitai")
            .withUsername("fitai")
            .withPassword("fitai");

    @DynamicPropertySource
    static void properties(DynamicPropertyRegistry registry) throws Exception {
        Path media = Files.createTempDirectory("fitai-admin-media");
        registry.add("spring.datasource.url", MYSQL::getJdbcUrl);
        registry.add("spring.datasource.username", MYSQL::getUsername);
        registry.add("spring.datasource.password", MYSQL::getPassword);
        registry.add("fitai.admin.jwt.secret",
                () -> "integration-test-secret-with-at-least-32-bytes-long");
        registry.add("fitai.admin.bootstrap.enabled", () -> "true");
        registry.add("fitai.admin.bootstrap.username", () -> "admin");
        registry.add("fitai.admin.bootstrap.password", () -> "Admin@123456");
        registry.add("fitai.admin.media.root", media::toString);
        registry.add("fitai.admin.jwt.cookie-secure", () -> "false");
    }

    @Autowired
    MockMvc mockMvc;

    @Autowired
    ObjectMapper objectMapper;

    @Autowired
    JdbcClient jdbc;

    @Test
    void loginAndReadDashboardWithRbac() throws Exception {
        mockMvc.perform(get("/api/admin/v1/dashboard/summary"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));

        String token = login();

        mockMvc.perform(get("/api/admin/v1/dashboard/summary")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.usersTotal").isNumber())
                .andExpect(jsonPath("$.active7d").isNumber())
                .andExpect(jsonPath("$.goals").isArray())
                .andExpect(jsonPath("$.recentUsers").isArray())
                .andExpect(jsonPath("$.recentWorkouts").isArray())
                .andExpect(jsonPath("$.recentSafety").isArray());
    }

    @Test
    void readsScheduleAndActionAuditAndPurgesUser() throws Exception {
        String token = login();
        String userId = UUID.randomUUID().toString();
        String actionId = UUID.randomUUID().toString();
        String scheduleId = UUID.randomUUID().toString();
        String planId = UUID.randomUUID().toString();
        String dayId = UUID.randomUUID().toString();

        jdbc.sql("""
                INSERT INTO users (id, phone, username, status, created_at, updated_at)
                VALUES (:id, :phone, :username, 'active', UTC_TIMESTAMP(), UTC_TIMESTAMP())
                """)
                .param("id", userId)
                .param("phone", "139" + userId.replace("-", "").substring(0, 8))
                .param("username", "smoke_" + userId.substring(0, 8))
                .update();
        jdbc.sql("""
                INSERT INTO agent_action_events
                    (id, user_id, action_id, action_type, status, message, detail, created_at)
                VALUES (:id, :userId, :actionId, 'log_body_metric', 'executed',
                        'recorded', '{"weight_kg":70}', UTC_TIMESTAMP())
                """)
                .param("id", actionId)
                .param("userId", userId)
                .param("actionId", "action-" + actionId)
                .update();
        jdbc.sql("""
                INSERT INTO plan_day_states
                    (id, user_id, plan_id, day_id, plan_version, assigned_date,
                     client_updated_at, updated_at, created_at)
                VALUES (:id, :userId, :planId, :dayId, 1, CURDATE(),
                        UTC_TIMESTAMP(), UTC_TIMESTAMP(), UTC_TIMESTAMP())
                """)
                .param("id", scheduleId)
                .param("userId", userId)
                .param("planId", planId)
                .param("dayId", dayId)
                .update();

        try {
            mockMvc.perform(get("/api/admin/v1/agent/actions")
                            .header("Authorization", "Bearer " + token))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.items[0].actionType").value("log_body_metric"))
                    .andExpect(jsonPath("$.items[0].userLabel").isNotEmpty());

            mockMvc.perform(get("/api/admin/v1/schedule?planId=" + planId)
                            .header("Authorization", "Bearer " + token))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.items[0].planId").value(planId));

            mockMvc.perform(get("/api/admin/v1/users/" + userId)
                            .header("Authorization", "Bearer " + token))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.metrics.workouts").value(0))
                    .andExpect(jsonPath("$.scans").isArray())
                    .andExpect(jsonPath("$.meals").isArray())
                    .andExpect(jsonPath("$.aiJobs").isArray());

            mockMvc.perform(delete("/api/admin/v1/users/" + userId + "/purge")
                            .header("Authorization", "Bearer " + token))
                    .andExpect(status().isNoContent());

            mockMvc.perform(get("/api/admin/v1/users/" + userId)
                            .header("Authorization", "Bearer " + token))
                    .andExpect(status().isNotFound());
        } finally {
            jdbc.sql("DELETE FROM users WHERE id = :id").param("id", userId).update();
        }
    }

    private String login() throws Exception {
        String response = mockMvc.perform(post("/api/admin/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"username":"admin","password":"Admin@123456"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.user.username").value("admin"))
                .andExpect(jsonPath("$.user.roles[0]").value("SUPER_ADMIN"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        JsonNode body = objectMapper.readTree(response);
        String token = body.get("accessToken").asText();
        assertThat(token).isNotBlank();
        return token;
    }
}
