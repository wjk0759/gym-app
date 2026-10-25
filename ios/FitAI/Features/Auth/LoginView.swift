import SwiftUI

struct LoginView: View {
    @Environment(AuthStore.self) private var auth

    private enum Mode: String, CaseIterable, Identifiable {
        case phone = "手机验证码"
        case password = "账号密码"
        var id: String { rawValue }
    }

    enum LegalKind: Identifiable {
        case terms
        case privacy
        var id: Int { self == .terms ? 0 : 1 }
        var title: String { self == .terms ? "用户协议" : "隐私政策" }
    }

    @State private var mode: Mode = .phone
    @State private var phone = ""
    @State private var code = ""
    @State private var account = ""
    @State private var password = ""
    @State private var consent = false
    @State private var showPassword = false
    @State private var countdown = 0
    @State private var isSendingCode = false
    @State private var devCode: String?
    @State private var localError: String?
    @State private var legal: LegalKind?
    @State private var showServerSettings = false

    private var errorText: String? {
        localError ?? auth.errorMessage
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                brand
                loginCard
                socialSection

#if DEBUG
                Button {
                    showServerSettings = true
                } label: {
                    Label("开发服务器：\(AppConfig.apiBaseURLString)", systemImage: "server.rack")
                        .font(.caption2)
                        .foregroundStyle(Theme.tertiaryText)
                }
                .buttonStyle(.plain)
#endif

                Text("登录即代表你同意平台仅将健康数据用于生成训练、饮食与服务改进。我们不会向第三方出售你的个人信息。")
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            }
            .padding(.horizontal, 22)
            .padding(.top, 44)
            .padding(.bottom, 36)
        }
        .background(Theme.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .sheet(item: $legal) { kind in
            LegalDocumentView(kind: kind)
        }
        .sheet(isPresented: $showServerSettings) {
            ServerSettingsView()
        }
        .onChange(of: mode) { _, _ in
            localError = nil
            auth.clearError()
        }
    }

    private var brand: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.accent)
                    .frame(width: 66, height: 66)
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.black)
            }
            .shadow(color: Theme.accent.opacity(0.22), radius: 24, y: 10)

            VStack(spacing: 5) {
                Text("练途")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("会记住你练过什么的 AI 健身教练")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }

    private var loginCard: some View {
        VStack(spacing: 16) {
            Picker("登录方式", selection: $mode) {
                ForEach(Mode.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)

            if mode == .phone {
                phoneFields
            } else {
                passwordFields
            }

            consentRow

            if let errorText {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text(errorText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.caption)
                .foregroundStyle(Theme.danger)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(11)
                .background(
                    Theme.danger.opacity(0.09),
                    in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                )
            }

            Button {
                submit()
            } label: {
                if auth.isWorking {
                    HStack(spacing: 8) {
                        ProgressView().tint(.black)
                        Text(mode == .phone ? "正在登录…" : "正在登录…")
                    }
                } else {
                    Text(mode == .phone ? "登录 / 注册" : "登录 / 自动注册")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(auth.isWorking)

            Text(mode == .phone
                 ? "未注册的手机号验证通过后会自动创建账号，并静默登录。"
                 : "未注册的账号会按你输入的密码自动创建；手机号也是账号。")
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card(padding: 18)
    }

    private var phoneFields: some View {
        VStack(spacing: 11) {
            HStack(spacing: 10) {
                Text("+86")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.leading, 13)

                TextField("手机号", text: $phone)
                    .keyboardType(.numberPad)
                    .textContentType(.telephoneNumber)
                    .onChange(of: phone) { _, newValue in
                        phone = String(newValue.filter(\.isNumber).prefix(11))
                        localError = nil
                    }
            }
            .frame(height: 50)
            .background(
                Theme.surfaceStrong,
                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
            )

            HStack(spacing: 10) {
                TextField("6 位验证码", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .onChange(of: code) { _, newValue in
                        code = String(newValue.filter(\.isNumber).prefix(6))
                        localError = nil
                    }

                Button {
                    sendCode()
                } label: {
                    if isSendingCode {
                        ProgressView().tint(Theme.accent)
                            .frame(width: 92)
                    } else {
                        Text(countdown > 0 ? "\(countdown)s 后重发" : "获取验证码")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(countdown > 0 ? Theme.tertiaryText : Theme.accent)
                            .frame(width: 92)
                    }
                }
                .buttonStyle(.plain)
                .disabled(!isValidPhone || countdown > 0 || isSendingCode)
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(
                Theme.surfaceStrong,
                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
            )

            if let devCode {
                HStack(spacing: 6) {
                    Image(systemName: "hammer.fill")
                    Text("开发环境验证码 \(devCode)，已自动填入")
                }
                .font(.caption2)
                .foregroundStyle(Theme.warning)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var passwordFields: some View {
        VStack(spacing: 11) {
            HStack(spacing: 10) {
                Image(systemName: "person")
                    .foregroundStyle(Theme.tertiaryText)
                    .frame(width: 18)
                TextField("手机号或用户名", text: $account)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.username)
                    .onChange(of: account) { _, _ in localError = nil }
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(
                Theme.surfaceStrong,
                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
            )

            HStack(spacing: 10) {
                Image(systemName: "lock")
                    .foregroundStyle(Theme.tertiaryText)
                    .frame(width: 18)

                Group {
                    if showPassword {
                        TextField("密码", text: $password)
                            .textContentType(.password)
                    } else {
                        SecureField("密码", text: $password)
                            .textContentType(.password)
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: password) { _, _ in localError = nil }

                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .foregroundStyle(Theme.tertiaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showPassword ? "隐藏密码" : "显示密码")
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(
                Theme.surfaceStrong,
                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
            )

            Text("密码需至少 8 位，并同时包含字母和数字。")
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var consentRow: some View {
        VStack(alignment: .leading, spacing: 7) {
            Button {
                consent.toggle()
            } label: {
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: consent ? "checkmark.square.fill" : "square")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(consent ? Theme.accent : Theme.tertiaryText)

                    Text("我已阅读并同意以下协议，且已年满 14 周岁")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 5) {
                Button("《用户协议》") { legal = .terms }
                Text("和")
                Button("《隐私政策》") { legal = .privacy }
            }
            .font(.caption)
            .foregroundStyle(Theme.accent)
            .padding(.leading, 26)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var socialSection: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Rectangle().fill(Theme.stroke).frame(height: 1)
                Text("其他方式登录")
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
                    .fixedSize()
                Rectangle().fill(Theme.stroke).frame(height: 1)
            }

            HStack(spacing: 10) {
                socialButton(
                    title: "微信登录",
                    subtitle: "一键授权",
                    icon: "message.fill",
                    color: Color(red: 0.20, green: 0.78, blue: 0.36),
                    provider: "wechat"
                )
                socialButton(
                    title: "QQ 登录",
                    subtitle: "一键授权",
                    icon: "person.2.fill",
                    color: Color(red: 0.26, green: 0.58, blue: 0.96),
                    provider: "qq"
                )
            }

#if DEBUG
            Text("微信/QQ 未配置开放平台密钥时，开发环境会打开模拟授权页，用于验证完整链路。")
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
#endif
        }
    }

    private func socialButton(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        provider: String
    ) -> some View {
        Button {
            guard ensureConsent() else { return }
            Task {
                do {
                    try await auth.loginWithSocial(provider: provider)
                } catch {
                    localError = error.localizedDescription
                }
            }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(Theme.tertiaryText)
                }
                Spacer(minLength: 0)
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Theme.surface,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Theme.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(auth.isWorking)
    }

    private var isValidPhone: Bool {
        phone.count == 11 && phone.hasPrefix("1")
    }

    private func sendCode() {
        guard isValidPhone else {
            localError = "请输入正确的 11 位手机号"
            return
        }
        isSendingCode = true
        localError = nil
        Task {
            defer { isSendingCode = false }
            do {
                if let code = try await auth.sendCode(phone: phone) {
                    devCode = code
                    self.code = code
                    startCountdown()
                } else {
                    startCountdown()
                }
            } catch {
                localError = error.localizedDescription
            }
        }
    }

    private func startCountdown() {
        countdown = 60
        Task {
            while countdown > 0 {
                try? await Task.sleep(for: .seconds(1))
                if countdown > 0 { countdown -= 1 }
            }
        }
    }

    private func submit() {
        guard ensureConsent() else { return }
        localError = nil
        auth.clearError()
        Task {
            do {
                if mode == .phone {
                    guard code.count == 6 else {
                        localError = "请输入 6 位验证码"
                        return
                    }
                    try await auth.loginWithPhone(phone: phone, code: code)
                } else {
                    try await auth.loginWithPassword(account: account, password: password)
                }
            } catch {
                localError = error.localizedDescription
            }
        }
    }

    private func ensureConsent() -> Bool {
        if consent { return true }
        localError = "请先阅读并同意用户协议与隐私政策"
        return false
    }
}

private struct ServerSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var value = AppConfig.apiBaseURLString

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("真机调试时改成电脑局域网地址。例如：")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                Text("http://192.168.1.4:8000/api/v1")
                    .font(.caption.monospaced())
                    .foregroundStyle(Theme.accent)

                TextField("http://192.168.1.4:8000/api/v1", text: $value)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .padding(12)
                    .background(
                        Theme.surfaceStrong,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )

                Button("保存") {
                    AppConfig.setAPIBaseURL(value)
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("恢复默认") {
                    value = "http://127.0.0.1:8000/api/v1"
                    AppConfig.setAPIBaseURL(nil)
                }
                .buttonStyle(SecondaryButtonStyle())

                Text("仅 Debug 构建显示。Release 使用固定生产域名。")
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
                Spacer()
            }
            .padding(20)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("开发服务器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

private struct LegalDocumentView: View {
    @Environment(\.dismiss) private var dismiss
    let kind: LoginView.LegalKind

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("演示版说明")
                        .font(.headline)
                        .foregroundStyle(Theme.accent)
                    Text("这是登录与数据授权流程的占位协议页。正式上线前必须由法务确认并替换为正式版本，包括账号注销、敏感个人信息单独同意、健康数据处理、第三方共享和未成年人保护条款。")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(kind.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.top, 4)

                    Text("登录前请确认你已年满 14 周岁。未满 18 周岁的用户应在监护人同意和指导下使用。健身与饮食建议不能替代医生或营养师的专业意见。")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}
