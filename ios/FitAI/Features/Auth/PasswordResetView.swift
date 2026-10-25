import Foundation
import SwiftUI

struct PasswordResetView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss

    let prefillPhone: String

    @State private var phone = ""
    @State private var code = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isSendingCode = false
    @State private var countdown = 0
    @State private var errorMessage = ""
    @State private var showSuccess = false

    init(prefillPhone: String) {
        self.prefillPhone = prefillPhone
        _phone = State(initialValue: prefillPhone)
    }

    private var isValidPhone: Bool {
        phone.count == 11 && phone.allSatisfy { $0.isNumber }
    }

    private var isValidPassword: Bool {
        newPassword.count >= 8
            && newPassword.contains(where: { $0.isLetter })
            && newPassword.contains(where: { $0.isNumber })
    }

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("重置登录密码")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("验证注册手机号后设置新密码，重置后其他设备会退出登录。")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 7) {
                            fieldLabel("手机号")
                            fieldShell {
                                Text("+86")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.secondaryText)
                                Rectangle()
                                    .fill(Theme.stroke)
                                    .frame(width: 1, height: 18)
                                TextField("请输入注册手机号", text: $phone)
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                                    .keyboardType(.numberPad)
                                    .textContentType(.telephoneNumber)
                                    .onChange(of: phone) { _, value in
                                        phone = String(value.filter(\.isNumber).prefix(11))
                                        errorMessage = ""
                                    }
                            }
                        }

                        VStack(alignment: .leading, spacing: 7) {
                            fieldLabel("验证码")
                            fieldShell {
                                TextField("请输入 6 位验证码", text: $code)
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                                    .keyboardType(.numberPad)
                                    .textContentType(.oneTimeCode)
                                    .onChange(of: code) { _, value in
                                        code = String(value.filter(\.isNumber).prefix(6))
                                        errorMessage = ""
                                    }

                                Button {
                                    sendCode()
                                } label: {
                                    if isSendingCode {
                                        ProgressView().tint(Theme.accent)
                                    } else {
                                        Text(countdown > 0 ? "\(countdown)s 后重发" : "获取验证码")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(
                                                countdown > 0 || !isValidPhone
                                                    ? Theme.tertiaryText
                                                    : Theme.accent
                                            )
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(!isValidPhone || countdown > 0 || isSendingCode)
                            }
                        }

                        VStack(alignment: .leading, spacing: 7) {
                            fieldLabel("新密码")
                            fieldShell {
                                Image(systemName: "lock")
                                    .foregroundStyle(Theme.tertiaryText)
                                    .frame(width: 18)
                                SecureField("至少 8 位，含字母和数字", text: $newPassword)
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                                    .textContentType(.newPassword)
                                    .onChange(of: newPassword) { _, _ in errorMessage = "" }
                            }
                        }

                        VStack(alignment: .leading, spacing: 7) {
                            fieldLabel("确认新密码")
                            fieldShell {
                                Image(systemName: "lock.rotation")
                                    .foregroundStyle(Theme.tertiaryText)
                                    .frame(width: 18)
                                SecureField("再次输入新密码", text: $confirmPassword)
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                                    .textContentType(.newPassword)
                                    .onChange(of: confirmPassword) { _, _ in errorMessage = "" }
                            }
                        }

                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(Theme.danger)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Button {
                            resetPassword()
                        } label: {
                            if auth.isWorking {
                                ProgressView().tint(.black)
                            } else {
                                Text("重置密码")
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(auth.isWorking)

                        Text("如果手机号已经停用或无法接收验证码，请通过 App 内反馈渠道联系支持。")
                            .font(.caption2)
                            .foregroundStyle(Theme.tertiaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .card()
                }
                .padding(20)
                .padding(.bottom, 20)
            }
            .background(AppBackground())
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("找回密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .alert("密码已重置", isPresented: $showSuccess) {
                Button("返回登录") { dismiss() }
            } message: {
                Text("请使用手机号和新密码重新登录。")
            }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(Theme.secondaryText)
            .padding(.leading, 2)
    }

    private func fieldShell<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 10) {
            content()
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .background(
            Theme.surfaceStrong,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.stroke, lineWidth: 1)
        )
    }

    private func sendCode() {
        guard isValidPhone else {
            errorMessage = "请输入正确的 11 位手机号"
            return
        }
        Task { @MainActor in
            isSendingCode = true
            defer { isSendingCode = false }
            do {
                if let devCode = try await auth.sendCode(
                    phone: phone,
                    purpose: "reset_password"
                ) {
                    code = devCode
                }
                startCountdown()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func startCountdown() {
        countdown = 60
        Task { @MainActor in
            while countdown > 0 {
                try? await Task.sleep(for: .seconds(1))
                countdown -= 1
            }
        }
    }

    private func resetPassword() {
        guard isValidPhone else {
            errorMessage = "请输入正确的 11 位手机号"
            return
        }
        guard code.count == 6 else {
            errorMessage = "请输入 6 位验证码"
            return
        }
        guard isValidPassword else {
            errorMessage = "新密码至少 8 位，并同时包含字母和数字"
            return
        }
        guard newPassword == confirmPassword else {
            errorMessage = "两次输入的新密码不一致"
            return
        }

        Task { @MainActor in
            do {
                try await auth.resetPassword(
                    phone: phone,
                    code: code,
                    newPassword: newPassword
                )
                showSuccess = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
