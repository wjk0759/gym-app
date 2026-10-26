package com.fitai.admin.security;

import java.util.Map;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import com.fitai.admin.common.audit.AuditService;
import com.fitai.admin.config.BootstrapProperties;

@Component
@Order(20)
public class AdminBootstrap implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(AdminBootstrap.class);

    private final AdminAccountRepository accounts;
    private final PasswordEncoder passwordEncoder;
    private final BootstrapProperties properties;
    private final AuditService auditService;

    public AdminBootstrap(
            AdminAccountRepository accounts,
            PasswordEncoder passwordEncoder,
            BootstrapProperties properties,
            AuditService auditService
    ) {
        this.accounts = accounts;
        this.passwordEncoder = passwordEncoder;
        this.properties = properties;
        this.auditService = auditService;
    }

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        if (!properties.enabled() || accounts.hasUsers()) {
            return;
        }
        if (properties.password() == null || properties.password().length() < 10) {
            log.error("未创建初始管理员：bootstrap 密码必须至少 10 位，或手动写入 admin_users");
            return;
        }
        PasswordPolicy.validate(properties.password());
        String id = UUID.randomUUID().toString();
        accounts.insertAdminUser(
                id,
                properties.username(),
                passwordEncoder.encode(properties.password()),
                properties.displayName()
        );
        String roleId = accounts.roleIdByCode("SUPER_ADMIN")
                .orElseThrow(() -> new IllegalStateException("Flyway 未初始化 SUPER_ADMIN 角色"));
        accounts.assignRole(id, roleId);
        auditService.recordAs("system", "ADMIN_BOOTSTRAP", "admin_user", id,
                Map.of("username", properties.username(), "role", "SUPER_ADMIN"));
        log.warn("已创建初始化管理员 '{}'。请立即修改默认密码并关闭 bootstrap。", properties.username());
    }
}
