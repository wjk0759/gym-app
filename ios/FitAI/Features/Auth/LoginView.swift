import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @Environment(AuthStore.self) private var auth

    private enum Mode: String, CaseIterable, Identifiable {
        case phone = "手机验证码"
        case password = "账号密码"
        var id: String { rawValue }
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
    @State private var legal: LegalDocumentKind?
    @State private var showServerSettings = false
    @State private var showPasswordReset = false
    @State private var showRegistration = false
    @State private var registrationAccount = ""
    @State private var registrationPassword = ""
    @State private var showConsentPrompt = false
    @State private var pendingConsentAction: PendingConsentAction?
    @Namespace private var modeNamespace

    /// 微信/QQ 登录暂时隐藏，后端能力保留；恢复时改为 true 即可。
    private let showWeChatQQLogin = false

    private enum PendingConsentAction {
        case login
        case social(String)
    }

    private enum Field: Hashable {
        case phone
        case code
        case account
        case password
    }

    @FocusState private var focusedField: Field?

    private var errorText: String? {
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
                        socialSection(compact: compact)
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

    private var keyboardDoneBar: some View {
        HStack {
            Spacer()
            Button("完成") {
                focusedField = nil
            }
            .font(AppType.callout.weight(.semibold))
            .foregroundStyle(Theme.cobalt)
            .frame(minWidth: 64, minHeight: 44)
        }
        .padding(.horizontal, 12)
        .background(Theme.chrome)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.stroke)
                .frame(height: 1)
        }
    }

    private func header(compact: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: compact ? 13 : 15, style: .continuous)
                    .fill(Theme.primary)
                    .frame(width: compact ? 42 : 48, height: compact ? 42 : 48)
                RoundedRectangle(cornerRadius: compact ? 13 : 15, style: .continuous)
                    .strokeBorder(Theme.inkSolid, lineWidth: 2)
                    .frame(width: compact ? 42 : 48, height: compact ? 42 : 48)
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: compact ? 19 : 22, weight: .bold))
                    .foregroundStyle(Theme.onPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("练途")
                    .font(AppType.title)
                    .foregroundStyle(Theme.ink)
                Text("AI 健身教练")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
            }

            Spacer(minLength: 0)

            if !compact {
                Text("训练 · 饮食 · 复盘")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.cobalt)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Theme.cobalt.opacity(0.08), in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(Theme.cobalt.opacity(0.16), lineWidth: 1)
                    )
            }
        }
    }

    private func headline(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("登录练途")
                .font(.system(size: compact ? 27 : 34, weight: .bold, design: .default))
                .tracking(-0.5)
                .foregroundStyle(Theme.ink)
            Text("同步训练计划、记录和 AI 复盘")
                .font(compact ? AppType.caption : AppType.body)
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func loginCard(compact: Bool) -> some View {
        VStack(spacing: compact ? 12 : 14) {
            modeSwitch

            Group {
                if mode == .phone {
                    phoneFields
                } else {
                    passwordFields
                }
            }
            .transition(.opacity.combined(with: .offset(y: 6)))

            if let errorText {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text(errorText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(AppType.caption)
                .foregroundStyle(Theme.coral)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(11)
                .background(
                    Theme.coral.opacity(0.09),
                    in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                )
                .transition(.opacity.combined(with: .offset(y: -6)))
            }

            Button {
                focusedField = nil
                submit()
            } label: {
                HStack(spacing: 8) {
                    if auth.isWorking {
                        ProgressView().tint(Theme.onAccent)
                        Text("正在登录…")
                    } else {
                        Text("登录并继续")
                        Image(systemName: "arrow.right")
                            .font(AppType.callout.weight(.bold))
                    }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(auth.isWorking)

            Text(mode == .phone
                 ? "未注册手机号将自动创建账号"
                 : "未注册账号会引导完成注册")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(compact ? 16 : 18)
        .background {
            RoundedRectangle(cornerRadius: AppLayout.heroCornerRadius, style: .continuous)
                .fill(Theme.paper)
        }
        .overlay {
            RoundedRectangle(cornerRadius: AppLayout.heroCornerRadius, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
        .motionAnimation(Motion.quick, value: mode)
        .motionAnimation(Motion.quick, value: errorText)
    }

    private var modeSwitch: some View {
        HStack(spacing: 4) {
            ForEach(Mode.allCases) { item in
                Button {
                    guard mode != item else { return }
                    Haptics.select()
                    withAnimation(Motion.quick) {
                        mode = item
                    }
                } label: {
                    Text(item.rawValue)
                        .font(AppType.callout.weight(.semibold))
                        .foregroundStyle(mode == item ? Theme.paper : Theme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background {
                            if mode == item {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(Theme.ink)
                                    .matchedGeometryEffect(id: "modePill", in: modeNamespace)
                            }
                        }
                }
                .buttonStyle(SubtlePressStyle(scale: 0.97))
            }
        }
        .padding(4)
        .background(
            Theme.paper,
            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Theme.stroke, lineWidth: 1)
        )
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(AppType.caption.weight(.medium))
            .foregroundStyle(Theme.secondaryText)
            .padding(.leading, 2)
    }

    private func fieldShell<Content: View>(
        focused: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 10) {
            content()
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .background {
            SoftSurface(
                cornerRadius: 14,
                tint: focused ? Theme.cobalt.opacity(0.06) : Theme.ink.opacity(0.035),
                stroke: focused ? Theme.cobalt.opacity(0.38) : Theme.stroke
            )
        }
    }

    private var phoneFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                fieldLabel("手机号")

                fieldShell(focused: focusedField == .phone) {
                    Image(systemName: "iphone")
                        .font(AppType.callout)
                        .foregroundStyle(focusedField == .phone ? Theme.cobalt : Theme.tertiaryText)
                        .frame(width: 18)

                    Text("+86")
                        .font(AppType.callout.weight(.semibold))
                        .foregroundStyle(Theme.secondaryText)

                    Rectangle()
                        .fill(Theme.stroke)
                        .frame(width: 1, height: 18)

                    TextField("请输入手机号", text: $phone)
                        .font(AppType.callout)
                        .foregroundStyle(Theme.ink)
                        .keyboardType(.numberPad)
                        .textContentType(.telephoneNumber)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .phone)
                        .onSubmit { focusedField = .code }
                        .onChange(of: phone) { _, newValue in
                            phone = String(newValue.filter(\.isNumber).prefix(11))
                            localError = nil
                        }
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                fieldLabel("验证码")

                fieldShell(focused: focusedField == .code) {
                    Image(systemName: "number")
                        .font(AppType.callout)
                        .foregroundStyle(focusedField == .code ? Theme.cobalt : Theme.tertiaryText)
                        .frame(width: 18)

                    TextField("请输入 6 位验证码", text: $code)
                        .font(AppType.callout)
                        .foregroundStyle(Theme.ink)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .submitLabel(.done)
                        .focused($focusedField, equals: .code)
                        .onSubmit {
                            focusedField = nil
                            submit()
                        }
                        .onChange(of: code) { _, newValue in
                            code = String(newValue.filter(\.isNumber).prefix(6))
                            localError = nil
                        }

                    Button {
                        sendCode()
                    } label: {
                        if isSendingCode {
                            ProgressView().tint(Theme.cobalt)
                                .frame(width: 78)
                        } else {
                            Text(countdown > 0 ? "\(countdown)s 后重发" : "获取验证码")
                                .font(AppType.caption.weight(.semibold))
                                .foregroundStyle(
                                    countdown > 0 || !isValidPhone ? Theme.tertiaryText : Theme.cobalt
                                )
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(
                                    Theme.cobalt.opacity(
                                        countdown > 0 || !isValidPhone ? 0 : 0.10
                                    ),
                                    in: Capsule()
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!isValidPhone || countdown > 0 || isSendingCode)
                }
            }

            Text(devCode.map { "开发验证码 \($0)，已自动填入" } ?? "验证码仅用于本次登录，请勿转发")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(devCode == nil ? Theme.tertiaryText : Theme.warning)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .frame(maxWidth: .infinity, minHeight: 16, alignment: .leading)
                .padding(.leading, 2)
        }
    }

    private var passwordFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                fieldLabel("手机号或用户名")

                fieldShell(focused: focusedField == .account) {
                    Image(systemName: "person")
                        .foregroundStyle(focusedField == .account ? Theme.cobalt : Theme.tertiaryText)
                        .frame(width: 18)

                    TextField("请输入手机号或用户名", text: $account)
                        .font(AppType.callout)
                        .foregroundStyle(Theme.ink)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.username)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .account)
                        .onSubmit { focusedField = .password }
                        .onChange(of: account) { _, _ in localError = nil }
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                fieldLabel("密码")

                fieldShell(focused: focusedField == .password) {
                    Image(systemName: "lock")
                        .foregroundStyle(focusedField == .password ? Theme.cobalt : Theme.tertiaryText)
                        .frame(width: 18)

                    Group {
                        if showPassword {
                            TextField("请输入密码", text: $password)
                                .textContentType(.password)
                                .focused($focusedField, equals: .password)
                        } else {
                            SecureField("请输入密码", text: $password)
                                .textContentType(.password)
                                .focused($focusedField, equals: .password)
                        }
                    }
                    .font(AppType.callout)
                    .foregroundStyle(Theme.ink)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .onSubmit {
                        focusedField = nil
                        submit()
                    }
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
            }

            HStack(spacing: 8) {
                Text("密码至少 8 位，含字母和数字")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)

                Spacer(minLength: 4)

                Button("忘记密码？") {
                    showPasswordReset = true
                }
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(Theme.cobalt)
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, minHeight: 16, alignment: .leading)
            .padding(.leading, 2)
        }
    }

    private var consentFooter: some View {
        HStack(alignment: .top, spacing: 7) {
            Button {
                Haptics.select()
                withAnimation(Motion.quick) {
                    consent.toggle()
                }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(consent ? Theme.cobalt : Color.clear)
                        .frame(width: 18, height: 18)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(
                                    consent ? Theme.cobalt : Theme.tertiaryText.opacity(0.55),
                                    lineWidth: 1.2
                                )
                        )
                    if consent {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.onAccent)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(SubtlePressStyle(scale: 0.9))
            .accessibilityLabel("同意用户协议、隐私政策与健康免责声明")
            .accessibilityValue(consent ? "已同意" : "未同意")

            VStack(alignment: .leading, spacing: 2) {
                Text("我已阅读并同意以下文件")
                HStack(spacing: 6) {
                    Button {
                        legal = .terms
                    } label: {
                        Text("《用户协议》").underline().foregroundStyle(Theme.cobalt)
                    }
                    Button {
                        legal = .privacy
                    } label: {
                        Text("《隐私政策》").underline().foregroundStyle(Theme.cobalt)
                    }
                    Button {
                        legal = .health
                    } label: {
                        Text("《健康免责声明》").underline().foregroundStyle(Theme.cobalt)
                    }
                }
                .buttonStyle(.plain)

                Text("且已年满 14 周岁")
            }
            .font(.system(size: 10.5))
            .foregroundStyle(Theme.tertiaryText)
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
    }

    private func socialSection(compact: Bool) -> some View {
        VStack(spacing: compact ? 8 : 10) {
            HStack(spacing: 10) {
                Rectangle().fill(Theme.stroke).frame(height: 1)
                Text("或使用第三方账号")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
                    .fixedSize()
                Rectangle().fill(Theme.stroke).frame(height: 1)
            }

            if showWeChatQQLogin {
                HStack(spacing: 8) {
                    socialButton(
                        title: "微信登录",
                        icon: "message.fill",
                        color: Theme.secondary,
                        provider: "wechat"
                    )
                    socialButton(
                        title: "QQ 登录",
                        icon: "person.2.fill",
                        color: Theme.primary,
                        provider: "qq"
                    )
                }
            }

            if consent {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                              let data = credential.identityToken,
                              let token = String(data: data, encoding: .utf8) else {
                            localError = "Apple 登录未返回身份凭证"
                            return
                        }
                        let name = [credential.fullName?.givenName, credential.fullName?.familyName]
                            .compactMap { $0 }
                            .joined()
                        Task {
                            do {
                                try await auth.loginWithApple(
                                    identityToken: token,
                                    fullName: name.isEmpty ? nil : name
                                )
                            } catch {
                                localError = error.localizedDescription
                            }
                        }
                    case .failure(let error):
                        if (error as? ASAuthorizationError)?.code != .canceled {
                            localError = "Apple 登录失败：\(error.localizedDescription)"
                        }
                    @unknown default:
                        break
                    }
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: compact ? 44 : 48)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .disabled(auth.isWorking)
            } else {
                Text("勾选下方协议后可使用 Apple 登录")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.tertiaryText)
                    .frame(maxWidth: .infinity, minHeight: compact ? 44 : 48)
                    .background(
                        Theme.ink.opacity(0.035),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
            }
        }
    }

    private var devServerLink: some View {
#if DEBUG
        Button {
            Haptics.tap()
            showServerSettings = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "server.rack")
                Text("开发服务器")
                Text(AppConfig.apiBaseURLString)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .font(.system(size: 9.5))
            .foregroundStyle(Theme.tertiaryText.opacity(0.85))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(SubtlePressStyle(scale: 0.98))
#else
        EmptyView()
#endif
    }

    private func socialButton(
        title: String,
        icon: String,
        color: Color,
        provider: String
    ) -> some View {
        Button {
            Haptics.tap()
            guard consent else {
                pendingConsentAction = .social(provider)
                showConsentPrompt = true
                return
            }
            performSocialLogin(provider)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(AppType.callout.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 20)
                Text(title)
                    .font(AppType.callout.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                color.opacity(0.10),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(color.opacity(0.24), lineWidth: 0.8)
            )
        }
        .buttonStyle(SubtlePressStyle(scale: 0.97))
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

    private func performSocialLogin(_ provider: String) {
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
    @State private var value = AppConfig.apiBaseURLString

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
                        Text("练途 · 协议与隐私")
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
