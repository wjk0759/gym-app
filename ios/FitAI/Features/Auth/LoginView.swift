import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @Environment(AuthStore.self) var auth

    enum Mode: String, CaseIterable, Identifiable {
        case phone = "手机验证码"
        case password = "账号密码"
        var id: String { rawValue }
    }

    @State var mode: Mode = .phone
    @State var phone = ""
    @State var code = ""
    @State var account = ""
    @State var password = ""
    @State var consent = false
    @State var showPassword = false
    @State var countdown = 0
    @State var isSendingCode = false
    @State var devCode: String?
    @State var localError: String?
    @State var legal: LegalDocumentKind?
    @State var showServerSettings = false
    @State var showPasswordReset = false
    @State var showRegistration = false
    @State var registrationAccount = ""
    @State var registrationPassword = ""
    @State var showConsentPrompt = false
    @State var pendingConsentAction: PendingConsentAction?
    @Namespace var modeNamespace

    /// 微信/QQ 登录暂时隐藏，后端能力保留；恢复时改为 true 即可。
    let showWeChatQQLogin = false

    enum PendingConsentAction {
        case login
        case social(String)
    }

    enum Field: Hashable {
        case phone
        case code
        case account
        case password
    }

    @FocusState var focusedField: Field?

    var errorText: String? {
        localError ?? auth.errorMessage
    }

    var body: some View {
        GeometryReader { proxy in
            // Width, unlike height, does not change when the keyboard
            // appears. This keeps the compact/regular layout stable during
            // the keyboard animation.
            let compact = proxy.size.width < AppLayout.compactWidthThreshold

            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: compact ? 12 : 16) {
                        header(compact: compact)
                        headline(compact: compact)
                        loginCard(compact: compact)
                        if AppConfig.appleSignInEnabled {
                            socialSection(compact: compact)
                        }
                        consentFooter
                        devServerLink
                            .padding(.top, 2)
                    }
                    .padding(.horizontal, compact ? 18 : 22)
                    .padding(.top, compact ? 12 : 24)
                    .padding(.bottom, 24)
                    .frame(maxWidth: 480)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .scrollBounceBehavior(.always)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if focusedField != nil {
                    keyboardDoneBar
                }
            }
            .sheet(item: $legal) { kind in
                LegalDocumentView(kind: kind)
            }
            .sheet(isPresented: $showServerSettings) {
                ServerSettingsView()
            }
            .sheet(isPresented: $showPasswordReset) {
                PasswordResetView(prefillPhone: account.count == 11 ? account : phone)
            }
            .sheet(isPresented: $showRegistration) {
                PasswordRegistrationView(
                    account: registrationAccount,
                    password: registrationPassword
                )
            }
            .confirmationDialog(
                "登录前确认",
                isPresented: $showConsentPrompt,
                titleVisibility: .visible
            ) {
                Button("同意并继续") {
                    consent = true
                    let action = pendingConsentAction
                    pendingConsentAction = nil
                    switch action {
                    case .some(.login):
                        performLogin()
                    case .some(.social(let provider)):
                        performSocialLogin(provider)
                    case .none:
                        break
                    }
                }
                Button("取消", role: .cancel) {
                    pendingConsentAction = nil
                }
            } message: {
                Text("登录需要使用你的账号标识，并可能同步训练资料。请确认已阅读并同意《用户协议》《隐私政策》和《健康免责声明》。")
            }
            .onChange(of: mode) { _, _ in
                focusedField = nil
                localError = nil
                auth.clearError()
            }
        }
    }

    var isValidPhone: Bool {
        phone.count == 11 && phone.hasPrefix("1")
    }

    func sendCode() {
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

    func submit() {
        guard consent else {
            pendingConsentAction = .login
            showConsentPrompt = true
            return
        }
        performLogin()
    }

    private func performLogin() {
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
                if mode == .password, error.localizedDescription.contains("账号未注册") {
                    registrationAccount = account
                    registrationPassword = password
                    showRegistration = true
                    localError = nil
                } else {
                    localError = error.localizedDescription
                }
            }
        }
    }

    func performSocialLogin(_ provider: String) {
        localError = nil
        auth.clearError()
        Task {
            do {
                try await auth.loginWithSocial(provider: provider)
            } catch {
                localError = error.localizedDescription
            }
        }
    }
}

private struct ServerSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State var value = AppConfig.apiBaseURLString

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("真机调试时改成电脑局域网地址。例如：")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
                Text("http://192.168.1.4:8000/api/v1")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.cobalt)

                TextField("http://192.168.1.4:8000/api/v1", text: $value)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .padding(12)
                    .background(
                        Theme.ink.opacity(0.035),
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
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
                Spacer()
            }
            .padding(20)
            .background(AppBackground())
            .navigationTitle("开发服务器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .keyboardDoneToolbar()
        }
    }
}

struct LegalDocumentView: View {
    @Environment(\.dismiss) private var dismiss
    let kind: LegalDocumentKind

    private var document: LegalDocument { kind.document }

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("叫练 · 协议与隐私")
                            .font(AppType.caption.weight(.semibold))
                            .foregroundStyle(Theme.cobalt)
                        Spacer()
                        Text("更新于 \(LegalMeta.updatedAt)")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(Theme.tertiaryText)
                    }

                    Text(document.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Theme.ink)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("运营者：\(LegalMeta.operatorName)")
                        if let mailURL = URL(string: "mailto:\(LegalMeta.contactEmail)") {
                            HStack(spacing: 2) {
                                Text("联系邮箱：")
                                Link(LegalMeta.contactEmail, destination: mailURL)
                                    .foregroundStyle(Theme.cobalt)
                            }
                        } else {
                            Text("联系邮箱：\(LegalMeta.contactEmail)")
                        }
                        Text("适用范围：\(LegalMeta.scope)")
                    }
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        Theme.ink.opacity(0.035),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )

                    Text(document.intro)
                        .font(AppType.callout)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(document.sections) { section in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(section.title)
                                .font(AppType.headline)
                                .foregroundStyle(Theme.ink)
                            Text(section.body)
                                .font(AppType.callout)
                                .foregroundStyle(Theme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .background(AppBackground())
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
            .presentationDragIndicator(.visible)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}
