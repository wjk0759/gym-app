import Foundation
import SwiftUI

struct PasswordResetView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var onResetCompleted: ((String) -> Void)?

    private enum Field: Hashable {
        case phone
        case code
        case newPassword
        case confirmPassword
    }

    @State private var phone: String
    @State private var code = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var isSendingCode = false
    @State private var isSubmitting = false
    @State private var countdown = 0
    @State private var countdownTask: Task<Void, Never>?
    @State private var devCode: String?
    @State private var errorMessage: String?
    @State private var showSuccess = false

    @FocusState private var focusedField: Field?

    init(prefillPhone: String, onResetCompleted: ((String) -> Void)? = nil) {
        self.onResetCompleted = onResetCompleted
        _phone = State(initialValue: AuthInput.phoneDigits(prefillPhone))
    }

    private var isValidPhone: Bool {
        AuthInput.isValidPhone(phone)
    }

    private var isValidPassword: Bool {
        newPassword.count >= 8
            && newPassword.contains(where: { $0.isLetter })
            && newPassword.contains(where: { $0.isNumber })
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 8) {
                    Text("+86")
                        .foregroundStyle(.secondary)

                    TextField("手机号", text: $phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .focused($focusedField, equals: .phone)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .code
                        }
                        .accessibilityLabel("手机号")
                        .onChange(of: phone) { _, newValue in
                            let filtered = AuthInput.phoneDigits(newValue)
                            if filtered != newValue {
                                phone = filtered
                            }
                            if countdown > 0 || devCode != nil {
                                code = ""
                                devCode = nil
                                countdown = 0
                                countdownTask?.cancel()
                            }
                            errorMessage = nil
                        }
                }

                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 4) {
                        codeInput
                        HStack {
                            Spacer()
                            resendCodeButton
                        }
                    }
                } else {
                    HStack(spacing: 8) {
                        codeInput
                        resendCodeButton
                    }
                }
            } header: {
                Text("验证手机号")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("验证码将发送至该手机号；重置后其他设备会退出登录。")
                    #if DEBUG
                    if let devCode {
                        Text("开发验证码：\(devCode)")
                            .foregroundStyle(Theme.warning)
                    }
                    #endif
                }
            }
            .disabled(isSubmitting)

            Section {
                Group {
                    if showPassword {
                        TextField("新密码", text: $newPassword)
                    } else {
                        SecureField("新密码", text: $newPassword)
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.newPassword)
                .focused($focusedField, equals: .newPassword)
                .submitLabel(.next)
                .onSubmit {
                    focusedField = .confirmPassword
                }
                .accessibilityLabel("新密码")
                .onChange(of: newPassword) { _, _ in
                    errorMessage = nil
                }

                Group {
                    if showPassword {
                        TextField("确认新密码", text: $confirmPassword)
                    } else {
                        SecureField("确认新密码", text: $confirmPassword)
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.newPassword)
                .focused($focusedField, equals: .confirmPassword)
                .submitLabel(.go)
                .onSubmit {
                    resetPassword()
                }
                .accessibilityLabel("确认新密码")
                .onChange(of: confirmPassword) { _, _ in
                    errorMessage = nil
                }

                Toggle("显示密码", isOn: $showPassword)
                    .tint(Theme.accentText)
            } header: {
                Text("设置新密码")
            } footer: {
                Text("至少 8 位，需同时包含字母和数字。")
            }
            .disabled(isSubmitting)

            Section {
                Button {
                    resetPassword()
                } label: {
                    HStack(spacing: 8) {
                        if isSubmitting {
                            ProgressView()
                                .controlSize(.small)
                                .tint(Theme.onAccentFill)
                        }
                        Text(isSubmitting ? "正在重置…" : "重置密码")
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.onAccentFill)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(Theme.accentFill)
                .disabled(isSubmitting || isSendingCode)
                .accessibilityLabel(isSubmitting ? "正在重置密码" : "重置密码")
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(Theme.danger)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityElement(children: .combine)
                    }

                    Text("如果手机号已经停用或无法接收验证码，请通过 App 内反馈渠道联系支持。")
                        .font(.footnote)
                }
            }
        }
        .navigationTitle("找回密码")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .tint(Theme.accentText)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") {
                    focusedField = nil
                }
            }
        }
        .alert("密码已重置", isPresented: $showSuccess) {
            Button("返回登录") {
                onResetCompleted?(AuthInput.phoneDigits(phone))
                dismiss()
            }
        } message: {
            Text("请使用手机号和新密码重新登录。")
        }
        .sensoryFeedback(.error, trigger: errorMessage) { _, newValue in
            newValue != nil
        }
        .sensoryFeedback(.success, trigger: showSuccess) { _, newValue in
            newValue
        }
        .announcesAuthError(errorMessage)
        .onDisappear {
            countdownTask?.cancel()
        }
    }

    private var codeInput: some View {
        TextField("6 位验证码", text: $code)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .focused($focusedField, equals: .code)
            .submitLabel(.next)
            .onSubmit {
                focusedField = .newPassword
            }
            .accessibilityLabel("验证码")
            .onChange(of: code) { _, newValue in
                let filtered = AuthInput.codeDigits(newValue)
                if filtered != newValue {
                    code = filtered
                }
                errorMessage = nil
            }
    }

    private var resendCodeButton: some View {
        Button {
            sendCode()
        } label: {
            if isSendingCode {
                ProgressView()
                    .controlSize(.small)
            } else {
                Text(countdown > 0 ? "\(countdown) 秒后" : "获取验证码")
                    .monospacedDigit()
            }
        }
        .buttonStyle(.borderless)
        .font(.subheadline.weight(.medium))
        .frame(minWidth: 88, minHeight: 44)
        .contentShape(Rectangle())
        .disabled(
            !isValidPhone || countdown > 0 || isSendingCode || isSubmitting
        )
        .accessibilityLabel(
            countdown > 0 ? "\(countdown) 秒后可重新获取验证码" : "获取验证码"
        )
    }

    private func sendCode() {
        guard !isSendingCode, !isSubmitting else { return }
        guard isValidPhone else {
            errorMessage = "请输入正确的 11 位手机号"
            focusedField = .phone
            return
        }

        errorMessage = nil
        let sentPhone = phone
        isSendingCode = true
        Task { @MainActor in
            defer { isSendingCode = false }
            do {
                let value = try await auth.sendCode(
                    phone: sentPhone,
                    purpose: "reset_password"
                )
                guard phone == sentPhone else { return }
                if let value {
                    devCode = value
                    code = value
                }
                startCountdown()
                focusedField = .code
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func startCountdown() {
        countdownTask?.cancel()
        countdown = 60
        countdownTask = Task { @MainActor in
            while countdown > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                countdown -= 1
            }
        }
    }

    private func resetPassword() {
        guard !isSubmitting, !isSendingCode else { return }
        guard isValidPhone else {
            errorMessage = "请输入正确的 11 位手机号"
            focusedField = .phone
            return
        }
        guard code.count == 6 else {
            errorMessage = "请输入 6 位验证码"
            focusedField = .code
            return
        }
        guard isValidPassword else {
            errorMessage = "新密码至少 8 位，并同时包含字母和数字"
            focusedField = .newPassword
            return
        }
        guard newPassword == confirmPassword else {
            errorMessage = "两次输入的新密码不一致"
            focusedField = .confirmPassword
            return
        }

        focusedField = nil
        errorMessage = nil
        isSubmitting = true
        Task { @MainActor in
            defer { isSubmitting = false }
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
