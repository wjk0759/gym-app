package com.fitai.admin.security;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;

import org.junit.jupiter.api.Test;

import com.fitai.admin.common.api.ApiException;

class PasswordPolicyTest {

    @Test
    void acceptsStrongPassword() {
        assertDoesNotThrow(() -> PasswordPolicy.validate("Admin@123456"));
        assertDoesNotThrow(() -> PasswordPolicy.validate("A-very-long-password-1"));
    }

    @Test
    void rejectsWeakPasswords() {
        assertThatThrownBy(() -> PasswordPolicy.validate("short"))
                .isInstanceOf(ApiException.class);
        assertThatThrownBy(() -> PasswordPolicy.validate("alllowercase1!"))
                .isInstanceOf(ApiException.class);
        assertThatThrownBy(() -> PasswordPolicy.validate("ALLUPPERCASE1!"))
                .isInstanceOf(ApiException.class);
        assertThatThrownBy(() -> PasswordPolicy.validate("NoNumbers!!"))
                .isInstanceOf(ApiException.class);
        assertThatThrownBy(() -> PasswordPolicy.validate("NoSpecial123"))
                .isInstanceOf(ApiException.class);
    }
}
