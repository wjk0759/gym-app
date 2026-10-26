package com.fitai.admin.security;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import java.util.List;

public final class AdminAccountDtos {

    private AdminAccountDtos() {
    }

    public record CreateAdminAccountRequest(
            @NotBlank(message = "请输入管理员账号")
            @Size(min = 3, max = 64, message = "账号长度需为 3–64 位")
            @Pattern(regexp = "^[A-Za-z0-9._-]+$", message = "账号只能包含字母、数字、点、下划线和短横线")
            String username,
            @NotBlank(message = "请输入初始密码")
            @Size(min = 10, max = 72, message = "密码长度需为 10–72 位")
            String password,
            @NotBlank(message = "请输入显示名称")
            @Size(max = 80, message = "显示名称不能超过 80 位")
            String displayName,
            @NotBlank(message = "请选择角色")
            String roleCode
    ) {
    }

    public record UpdateAdminAccountRequest(
            @Size(max = 80, message = "显示名称不能超过 80 位")
            String displayName,
            @Pattern(regexp = "active|suspended|disabled", message = "状态仅支持 active、suspended 或 disabled")
            String status,
            List<String> roleCodes
    ) {
        public boolean isEmpty() {
            return displayName == null && status == null && roleCodes == null;
        }
    }

    public record ResetAdminPasswordRequest(
            @NotBlank(message = "请输入新密码")
            @Size(min = 10, max = 72, message = "密码长度需为 10–72 位")
            String password
    ) {
    }

    public record RoleOption(String code, String name, String description) {
    }
}
