package com.fitai.admin.security;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record ChangePasswordRequest(
        @NotBlank(message = "请输入当前密码")
        String currentPassword,
        @NotBlank(message = "请输入新密码")
        @Size(min = 10, max = 72, message = "新密码长度需为 10–72 位")
        String newPassword
) {
}
