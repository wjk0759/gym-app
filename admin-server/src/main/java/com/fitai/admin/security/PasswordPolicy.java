package com.fitai.admin.security;

import java.util.regex.Pattern;

import com.fitai.admin.common.api.ApiException;

/**
 * Password policy for administrative accounts. Length is enforced by DTO
 * validation; complexity is enforced here so every write path shares it.
 */
public final class PasswordPolicy {

    private static final Pattern UPPER = Pattern.compile("[A-Z]");
    private static final Pattern LOWER = Pattern.compile("[a-z]");
    private static final Pattern DIGIT = Pattern.compile("\\d");
    private static final Pattern SPECIAL = Pattern.compile("[^A-Za-z0-9]");

    private PasswordPolicy() {
    }

    public static void validate(String password) {
        if (password == null
                || password.length() < 10
                || password.length() > 72
                || !UPPER.matcher(password).find()
                || !LOWER.matcher(password).find()
                || !DIGIT.matcher(password).find()
                || !SPECIAL.matcher(password).find()) {
            throw ApiException.badRequest(
                    "WEAK_PASSWORD",
                    "密码需为 10–72 位，且同时包含大写字母、小写字母、数字和特殊字符"
            );
        }
    }
}
