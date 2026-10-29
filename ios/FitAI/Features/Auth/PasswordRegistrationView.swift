import Foundation
import SwiftUI

/// 密码注册页。默认使用手机号作为登录账号；如果用户从“用户名 + 密码”
/// 登录失败进入，则保留该用户名作为只读账号，并要求验证手机号。
struct PasswordRegistrationView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let suggestedAccount: String

    private enum Field: Hashable {
        case phone
        case code
        case password
        case confirmPassword
    }

    @State private var phone: String
    @State private var code = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var isSendingCode = false
    @State private var isSubmitting = false
    @State private var countdown = 0
    @State private var countdownTask: Task<Void, Never>?
    @State private var devCode: String?
    @State private var errorMessage: String?

    @FocusState private var focusedField: Field?

    init(suggestedAccount: String = "", prefillPhone: String = "") {
        self.suggestedAccount = suggestedAccount

        let trimmed = suggestedAccount.trimmingCharacters(in: .whitespacesAndNewlines)
        let initialPhone = AuthInput.isValidPhone(trimmed)
            ? AuthInput.phoneDigits(trimmed)
            : AuthInput.phoneDigits(prefillPhone)
        _phone = State(initialValue: initialPhone)
    }

    private var usernameAccount: String? {
        let trimmed = suggestedAccount.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !AuthInput.isValidPhone(trimmed) else { return nil }
        return trimmed
    }

    private var lockedPhone: String? {
        let trimmed = suggestedAccount.trimmingCharacters(in: .whitespacesAndNewlines)
        return AuthInput.isValidPhone(trimmed)
            ? AuthInput.phoneDigits(trimmed)
            : nil
    }

    private var accountForRegistration: String {
        usernameAccount ?? phone
    }

    private var phoneSectionFooter: String {
        if usernameAccount != nil {
            return "验证码将发送至该手机号，用于确认账号归属。"
        }
        if lockedPhone != nil {
            return "该手机号来自你刚才输入的登录账号；如需更换，请返回登录页修改。"
        }
        return "注册后将使用手机号和密码登录；手机号仅用于账号验证和找回密码。"
    }

    private var isValidPhone: Bool {
        AuthInput.isValidPhone(phone)
    }

    private var isValidPassword: Bool {
        password.count >= 8
            && password.contains(where: { $0.isLetter })
            && password.contains(where: { $0.isNumber })
    }

    var body: some View {
        Form {
            if let usernameAccount {
                Section {
                    LabeledContent("登录账号", value: usernameAccount)
                } header: {
                    Text("账号")
                } footer: {
                    Text("该用户名将作为登录账号；手机号仅用于确认账号归属。")
                }
            }

            Section {
                if let lockedPhone {
                    LabeledContent("手机号", value: lockedPhone)
                } else {
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
                    Text(phoneSectionFooter)
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
                        TextField("设置密码", text: $password)
                    } else {
                        SecureField("设置密码", text: $password)
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.newPassword)
                .focused($focusedField, equals: .password)
                .submitLabel(.next)
                .onSubmit {
                    focusedField = .confirmPassword
                }
                .accessibilityLabel("设置密码")
                .onChange(of: password) { _, _ in
                    errorMessage = nil
                }

                Group {
                    if showPassword {
                        TextField("确认密码", text: $confirmPassword)
                    } else {
                        SecureField("确认密码", text: $confirmPassword)
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.newPassword)
                .focused($focusedField, equals: .confirmPassword)
                .submitLabel(.go)
                .onSubmit {
                    register()
                }
                .accessibilityLabel("确认密码")
                .onChange(of: confirmPassword) { _, _ in
                    errorMessage = nil
                }

                Toggle("显示密码", isOn: $showPassword)
                    .tint(Theme.accentText)
            } header: {
                Text("设置密码")
            } footer: {
                Text("至少 8 位，需同时包含字母和数字。")
            }
            .disabled(isSubmitting)

            Section {
                Button {
                    register()
                } label: {
                    HStack(spacing: 8) {
                        if isSubmitting {
                            ProgressView()
                                .controlSize(.small)
                                .tint(Theme.onAccentFill)
                        }
                        Text(isSubmitting ? "正在创建…" : "验证并创建账号")
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.onAccentFill)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(Theme.accentFill)
                .disabled(isSubmitting || isSendingCode)
                .accessibilityLabel(isSubmitting ? "正在创建账号" : "验证并创建账号")
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(Theme.danger)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityElement(children: .combine)
                    }

                    Text("注册后会直接用当前账号登录。")
                        .font(.footnote)
                }
            }
        }
        .navigationTitle("创建账号")
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
        .sensoryFeedback(.error, trigger: errorMessage) { _, newValue in
            newValue != nil
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
                focusedField = .password
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
                let value = try await auth.sendCode(phone: sentPhone)
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

    private func register() {
        guard !isSubmitting, !isSendingCode else { return }

        if let usernameAccount, !AuthInput.isValidUsername(usernameAccount) {
            errorMessage = "登录账号格式不正确，请返回修改。"
            return
        }
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
            errorMessage = "密码至少 8 位，并同时包含字母和数字"
            focusedField = .password
            return
        }
        guard password == confirmPassword else {
            errorMessage = "两次输入的密码不一致"
            focusedField = .confirmPassword
            return
        }

        let account = accountForRegistration
        guard account.count >= 4 else {
            errorMessage = "请输入正确的登录账号"
            focusedField = .phone
            return
        }

        focusedField = nil
        errorMessage = nil
        isSubmitting = true
        Task { @MainActor in
            defer { isSubmitting = false }
            do {
                try await auth.registerWithPassword(
                    account: account,
                    password: password,
                    phone: phone,
                    code: code
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

}
