package com.fitai.admin.security;

import java.util.List;

public record LoginRequest(
        @jakarta.validation.constraints.NotBlank(message = "请输入用户名")
        String username,
        @jakarta.validation.constraints.NotBlank(message = "请输入密码")
        String password
) {
}
