import SwiftUI

/// Password registration is only entered after the password login endpoint
/// reports `REGISTRATION_REQUIRED`. Phone ownership must be verified by SMS.
struct PasswordRegistrationView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.dismiss) private var dismiss

    let account: String
    let password: String

    @State private var phone: String
    @State private var code = ""
    @State private var devCode: String?
    @State private var errorMessage: String?
    @State private var isSendingCode = false
    @State private var isSubmitting = false
    @State private var countdown = 0

    init(account: String, password: String) {
        self.account = account
        self.password = password
        _phone = State(initialValue: account.count == 11 && account.hasPrefix("1") ? account : "")
    }

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    accountCard
                    verificationCard
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(Theme.danger)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Button {
                        register()
                    } label: {
                        if isSubmitting {
                            HStack(spacing: 8) {
                                ProgressView().tint(.black)
                                Text("正在创建账号…")
                            }
                        } else {
                            Text("验证手机号并完成注册")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isSubmitting || isSendingCode || phone.count != 11 || code.count != 6)

                    Text("注册后会直接用当前账号登录；手机号只用于账号验证和找回密码。")
                        .font(.caption2)
                        .foregroundStyle(Theme.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .background(AppBackground())
            .navigationTitle("完成注册")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("这个账号还没有注册")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("先用手机号验证码确认手机号，再创建账号并登录。")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("注册账号")
                .font(.headline)
                .foregroundStyle(.white)
            HStack {
                Text("账号")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                Spacer()
                Text(account)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            Text("密码已按你刚才输入的内容保留，注册成功后直接登录。")
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
        }
        .card()
    }

    private var verificationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("验证手机号")
                .font(.headline)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 7) {
                Text("手机号")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                fieldShell {
                    Text("+86")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.secondaryText)
                    Rectangle()
                        .fill(Theme.stroke)
                        .frame(width: 1, height: 18)
                    TextField("请输入手机号", text: $phone)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .keyboardType(.numberPad)
                        .textContentType(.telephoneNumber)
                        .onChange(of: phone) { _, value in
                            phone = String(value.filter(\.isNumber).prefix(11))
                            errorMessage = nil
                        }
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("验证码")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                fieldShell {
                    TextField("请输入 6 位验证码", text: $code)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .onChange(of: code) { _, value in
                            code = String(value.filter(\.isNumber).prefix(6))
                            errorMessage = nil
                        }
                    Button {
                        sendCode()
                    } label: {
                        if isSendingCode {
                            ProgressView().tint(Theme.accent)
                                .frame(width: 82)
                        } else {
                            Text(countdown > 0 ? "\(countdown)s 后重发" : "获取验证码")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(countdown > 0 || phone.count != 11 ? Theme.tertiaryText : Theme.accent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(
                                    Theme.accent.opacity(countdown > 0 || phone.count != 11 ? 0 : 0.10),
                                    in: Capsule()
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(phone.count != 11 || countdown > 0 || isSendingCode)
                }
            }

            Text(devCode.map { "开发验证码 \($0)，已自动填入" } ?? "验证码仅用于本次注册，请勿转发。")
                .font(.caption2)
                .foregroundStyle(devCode == nil ? Theme.tertiaryText : Theme.warning)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
        .card()
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
        guard phone.count == 11, phone.hasPrefix("1") else {
            errorMessage = "请输入正确的 11 位手机号"
            return
        }
        isSendingCode = true
        errorMessage = nil
        Task {
            defer { isSendingCode = false }
            do {
                if let value = try await auth.sendCode(phone: phone) {
                    devCode = value
                    code = value
                }
                startCountdown()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func register() {
        guard phone.count == 11 else {
            errorMessage = "请输入正确的手机号"
            return
        }
        guard code.count == 6 else {
            errorMessage = "请输入 6 位验证码"
            return
        }
        isSubmitting = true
        errorMessage = nil
        Task {
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

    private func startCountdown() {
        countdown = 60
        Task {
            while countdown > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                countdown -= 1
            }
        }
    }
}
