import SwiftUI
import AuthenticationServices
import UIKit

enum LegalDocumentKind: String, Identifiable {
    case terms
    case privacy
    case ai

    var id: String { rawValue }

    var title: String {
        switch self {
        case .terms: return "用户协议"
        case .privacy: return "隐私政策"
        case .ai: return "生成式 AI 服务说明"
        }
    }
}

struct LoginView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Mode: String, CaseIterable, Identifiable, Hashable {
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
    @State private var appleSignIn = AppleSignInCoordinator()

    private enum PendingConsentAction {
        case login
        case apple
        case social(String)
    }

    private enum Field: Hashable {
        case phone
        case code
        case account
        case password
    }

    @FocusState private var focusedField: Field?
    @State private var isFocusMode = false

    private var errorText: String? {
        localError ?? auth.errorMessage
    }

    var body: some View {
        ZStack {
            AppBackground()

            Color.black
                .opacity(isFocusMode ? 0.72 : 0)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissLoginFocus()
                }
                .allowsHitTesting(isFocusMode)

            VStack(spacing: 14) {
                if !isFocusMode {
                    brandHeader
                }

                loginCard
                    .scaleEffect(isFocusMode ? 1.02 : 1)
                    .offset(y: isFocusMode ? -10 : 0)
                    .shadow(
                        color: .black.opacity(isFocusMode ? 0.55 : 0),
                        radius: 34,
                        y: 14
                    )

                if !isFocusMode {
                    consentFooter
                    otherLoginSection
                }
            }
            .frame(maxWidth: 420)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .animation(
            Motion.resolved(
                .spring(response: 0.65, dampingFraction: 0.93),
                reduceMotion: reduceMotion
            ),
            value: isFocusMode
        )
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
                case .some(.apple):
                    startAppleSignIn()
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
            Text("登录需要使用你的账号标识，并可能同步训练资料。请确认已阅读并同意《用户协议》和《隐私政策》。")
        }
        .onChange(of: focusedField) { _, newValue in
            if newValue != nil {
                isFocusMode = true
            }
        }
        .onChange(of: mode) { _, newMode in
            localError = nil
            auth.clearError()
            guard isFocusMode else {
                focusedField = nil
                return
            }
            let nextField: Field = newMode == .phone ? .phone : .account
            DispatchQueue.main.async {
                focusedField = nextField
            }
        }
    }

    private func dismissLoginFocus() {
        focusedField = nil
        isFocusMode = false
    }

    private var brandHeader: some View {
        HStack(spacing: 11) {
            HeroGlyph(
                symbol: "figure.strengthtraining.traditional",
                size: 44,
                tint: Theme.accent
            )

            VStack(alignment: .leading, spacing: 2) {
                Text("练途")
                    .font(AppType.title)
                    .foregroundStyle(Theme.primaryText)
                Text("AI 私人健身教练")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.tertiaryText)
            }

            Spacer(minLength: 0)

#if DEBUG
            Menu {
                Button("开发服务器") {
                    showServerSettings = true
                }
            } label: {
                Image(systemName: "gearshape")
                    .foregroundStyle(Theme.secondaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("开发设置")
#endif
        }
    }

    private var loginCard: some View {
        VStack(spacing: 12) {
            AnimatedSegmentedControl(
                items: Mode.allCases,
                selection: $mode,
                label: { $0.rawValue }
            )
            .controlSize(.large)

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
                .foregroundStyle(Theme.danger)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(
                    Theme.danger.opacity(0.09),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
            }

            Button {
                dismissLoginFocus()
                submit()
            } label: {
                HStack(spacing: 8) {
                    if auth.isWorking {
                        ProgressView().tint(Theme.onAccent)
                        Text("正在登录…")
                    } else {
                        Text("登录")
                        Image(systemName: "arrow.right")
                            .font(.subheadline.weight(.bold))
                    }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(auth.isWorking)
        }
        .frame(maxWidth: .infinity)
        .glassCard(padding: 14, cornerRadius: 18, material: true)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Theme.stroke.opacity(0.35),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
        .shadow(
            color: .black.opacity(isFocusMode ? 0 : 0.14),
            radius: 18,
            y: 8
        )
    }

    private func fieldShell<Content: View>(
        focused: Bool,
        field: Field,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 10) {
            content()
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded {
                focusedField = field
            }
        )
        .background {
            SoftSurface(
                cornerRadius: 14,
                tint: focused ? Theme.accent.opacity(0.06) : Theme.surfaceStrong,
                stroke: focused ? Theme.accent.opacity(0.55) : Theme.stroke
            )
        }
        .animation(Motion.quick, value: focused)
    }

    private var phoneFields: some View {
        VStack(spacing: 12) {
            fieldShell(focused: focusedField == .phone, field: .phone) {
                Image(systemName: "iphone")
                    .font(AppType.caption)
                    .foregroundStyle(focusedField == .phone ? Theme.accent : Theme.tertiaryText)
                    .frame(width: 18)

                Text("+86")
                    .font(AppType.body.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)

                Rectangle()
                    .fill(Theme.stroke)
                    .frame(width: 1, height: 18)

                TextField("手机号", text: $phone)
                    .font(AppType.body)
                    .foregroundStyle(Theme.primaryText)
                    .keyboardType(.numberPad)
                    .textContentType(.telephoneNumber)
                    .focused($focusedField, equals: .phone)
                    .accessibilityLabel("手机号")
                    .onChange(of: phone) { _, newValue in
                        phone = String(newValue.filter(\.isNumber).prefix(11))
                        localError = nil
                    }
            }

            fieldShell(focused: focusedField == .code, field: .code) {
                Image(systemName: "number")
                    .font(AppType.caption)
                    .foregroundStyle(focusedField == .code ? Theme.accent : Theme.tertiaryText)
                    .frame(width: 18)

                TextField("6 位验证码", text: $code)
                    .font(AppType.body)
                    .foregroundStyle(Theme.primaryText)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .focused($focusedField, equals: .code)
                    .accessibilityLabel("验证码")
                    .onChange(of: code) { _, newValue in
                        code = String(newValue.filter(\.isNumber).prefix(6))
                        localError = nil
                    }

                Button {
                    sendCode()
                } label: {
                    Group {
                        if isSendingCode {
                            ProgressView()
                                .tint(Theme.accent)
                        } else {
                            Text(countdown > 0 ? "\(countdown)s 后重发" : "获取验证码")
                                .font(AppType.caption.weight(.semibold))
                                .foregroundStyle(
                                    countdown > 0 || !isValidPhone ? Theme.tertiaryText : Theme.accent
                                )
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .background(
                                    Theme.accent.opacity(
                                        countdown > 0 || !isValidPhone ? 0 : 0.10
                                    ),
                                    in: Capsule()
                                )
                        }
                    }
                    .frame(minWidth: 86, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!isValidPhone || countdown > 0 || isSendingCode)
            }

            Text(devCode.map { "开发验证码 \($0)，已自动填入" } ?? "验证码仅用于本次登录")
                .font(AppType.micro)
                .foregroundStyle(devCode == nil ? Theme.tertiaryText : Theme.warning)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                .padding(.leading, 2)
        }
    }

    private var passwordFields: some View {
        VStack(spacing: 12) {
            fieldShell(focused: focusedField == .account, field: .account) {
                Image(systemName: "person")
                    .font(AppType.caption)
                    .foregroundStyle(focusedField == .account ? Theme.accent : Theme.tertiaryText)
                    .frame(width: 18)

                TextField("手机号或用户名", text: $account)
                    .font(AppType.body)
                    .foregroundStyle(Theme.primaryText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.username)
                    .focused($focusedField, equals: .account)
                    .accessibilityLabel("手机号或用户名")
                    .onChange(of: account) { _, _ in localError = nil }
            }

            fieldShell(focused: focusedField == .password, field: .password) {
                Image(systemName: "lock")
                    .font(AppType.caption)
                    .foregroundStyle(focusedField == .password ? Theme.accent : Theme.tertiaryText)
                    .frame(width: 18)

                Group {
                    if showPassword {
                        TextField("密码", text: $password)
                            .textContentType(.password)
                            .focused($focusedField, equals: .password)
                    } else {
                        SecureField("密码", text: $password)
                            .textContentType(.password)
                            .focused($focusedField, equals: .password)
                    }
                }
                .font(AppType.body)
                .foregroundStyle(Theme.primaryText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityLabel("密码")
                .onChange(of: password) { _, _ in localError = nil }

                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .foregroundStyle(Theme.tertiaryText)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showPassword ? "隐藏密码" : "显示密码")
            }

            HStack {
                Spacer(minLength: 0)
                Button("忘记密码？") {
                    showPasswordReset = true
                }
                .font(AppType.caption)
                .foregroundStyle(Theme.accent)
                .buttonStyle(.plain)
                .frame(minHeight: 28)
                .contentShape(Rectangle())
            }
            .frame(minHeight: 28)
        }
    }

    private var consentFooter: some View {
        HStack(spacing: 6) {
            Button {
                Haptics.select()
                withAnimation(Motion.quick) {
                    consent.toggle()
                }
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: consent ? "checkmark.circle.fill" : "circle")
                        .font(.subheadline)
                        .foregroundStyle(consent ? Theme.accent : Theme.tertiaryText)

                    Text("我已阅读并同意《用户协议》和《隐私政策》，且已年满 14 周岁")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("同意用户协议与隐私政策")
            .accessibilityValue(consent ? "已同意" : "未同意")

            Menu {
                Button("用户协议") { legal = .terms }
                Button("隐私政策") { legal = .privacy }
            } label: {
                Image(systemName: "doc.text")
                    .font(.subheadline)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("查看协议")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
    }

    private var otherLoginSection: some View {
        HStack(spacing: 10) {
            socialIconButton(
                image: Image(systemName: "apple.logo"),
                tint: .black,
                background: .white,
                label: "Apple 登录"
            ) {
                startAppleSignIn()
            }

            socialIconButton(
                image: Image("WeChatIcon"),
                tint: Color(red: 0.20, green: 0.78, blue: 0.36),
                background: Color(red: 0.20, green: 0.78, blue: 0.36).opacity(0.12),
                label: "微信登录"
            ) {
                performSocialLoginAfterConsent("wechat")
            }

            socialIconButton(
                image: Image("QQIcon"),
                tint: Color(red: 0.26, green: 0.58, blue: 0.96),
                background: Color(red: 0.26, green: 0.58, blue: 0.96).opacity(0.12),
                label: "QQ 登录"
            ) {
                performSocialLoginAfterConsent("qq")
            }
        }
        .padding(.horizontal, 2)
        .offset(y: -6)
    }

    private func socialIconButton(
        image: Image,
        tint: Color,
        background: Color,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            image
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(background, in: Circle())
                .overlay(Circle().stroke(Theme.stroke, lineWidth: 0.5))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
        .disabled(auth.isWorking)
        .accessibilityLabel(label)
    }

    private func startAppleSignIn() {
        guard consent else {
            pendingConsentAction = .apple
            showConsentPrompt = true
            return
        }

        appleSignIn.onCredential = { credential in
            guard let data = credential.identityToken,
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
        }
        appleSignIn.onError = { error in
            if (error as? ASAuthorizationError)?.code != .canceled {
                localError = "Apple 登录失败：\(error.localizedDescription)"
            }
        }
        appleSignIn.start()
    }

    private func performSocialLoginAfterConsent(_ provider: String) {
        guard consent else {
            pendingConsentAction = .social(provider)
            showConsentPrompt = true
            return
        }
        performSocialLogin(provider)
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

/// Retained controller wrapper for the icon-only Sign in with Apple button.
private final class AppleSignInCoordinator: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {
    var onCredential: ((ASAuthorizationAppleIDCredential) -> Void)?
    var onError: ((Error) -> Void)?
    private var controller: ASAuthorizationController?

    func start() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        self.controller = controller
        controller.performRequests()
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        defer { self.controller = nil }
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            return
        }
        onCredential?(credential)
        onCredential = nil
        onError = nil
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        defer { self.controller = nil }
        onError?(error)
        onCredential = nil
        onError = nil
    }

    func presentationAnchor(
        for controller: ASAuthorizationController
    ) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
            ?? UIWindow(frame: UIScreen.main.bounds)
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
            .background(AppBackground())
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

struct LegalDocumentView: View {
    @Environment(\.dismiss) private var dismiss
    let kind: LegalDocumentKind

    private struct Section: Identifiable {
        let title: String
        let body: String
        var id: String { title }
    }

    private var intro: String {
        switch kind {
        case .terms:
            return "欢迎使用练途。本协议约定你与练途之间关于账号、训练计划、AI 教练、饮食记录和订阅服务的使用规则。请在使用前完整阅读。"
        case .privacy:
            return "练途重视你的个人信息与身体数据。本政策说明我们收集哪些信息、为什么收集、如何保护，以及你可以如何管理这些信息。"
        case .ai:
            return "本说明介绍练途中的生成式 AI 能力、内容边界和数据使用方式。"
        }
    }

    private var sections: [Section] {
        switch kind {
        case .terms:
            return [
                Section(title: "1. 服务内容与边界", body: "练途提供训练计划、动作说明、训练记录、饮食估算和 AI 对话等功能。这些内容用于一般健身与生活方式参考，不构成医疗诊断、治疗或营养处方。出现胸痛、眩晕、呼吸困难、急性损伤，或处于孕期、术后恢复期时，请先咨询医生。"),
                Section(title: "2. 账号注册与安全", body: "手机号验证通过，或使用微信/QQ 授权后，系统可能为你自动创建账号。请妥善保管验证码、密码与登录设备；发现异常登录时及时退出并修改密码。"),
                Section(title: "3. 订阅与自动续费", body: "练途 Pro 通过 Apple App Store 销售。价格、周期和试用条件以下单页面为准；订阅会自动续期，可在系统设置中取消。取消后，已付费周期内仍可使用 Pro 功能。"),
                Section(title: "4. AI 生成内容", body: "AI 计划与建议基于你填写的档案、器械、训练记录和对话内容生成，可能存在不准确或不适用的情况。请根据身体反应调整，不要将 AI 输出作为医疗依据。"),
                Section(title: "5. 使用规范", body: "不得利用本服务发布违法信息、侵犯他人权益、干扰系统运行或绕过安全限制。因违规导致的账号限制或终止，由用户承担相应责任。"),
                Section(title: "6. 知识产权", body: "App 界面、文本、图形和训练内容的知识产权归练途或授权方所有。未经许可不得复制、出售或用于商业培训。你上传的照片仅用于你主动选择的对应功能。"),
                Section(title: "7. 服务变更与终止", body: "我们可能因产品升级、合规要求或不可抗力调整服务，重大变更会通过 App 内提示。你可以随时停止使用。账号注销与数据删除需由运营方按法律法规和账号安全流程处理。"),
                Section(title: "8. 协议更新与联系", body: "协议更新后会在登录页或 App 内公示。继续使用视为接受更新内容；如不同意，可停止使用。对协议有疑问，可通过 App 内反馈渠道联系我们。")
            ]
        case .privacy:
            return [
                Section(title: "1. 我们收集的信息", body: "账号信息（手机号、微信/QQ 标识）；你主动填写的性别、年龄、身高、体重、围度、目标与训练偏好；训练记录、饮食记录、对话内容和器械库；你上传的器械照片、体型照片和食物照片；以及用于安全和故障排查的设备与日志信息。"),
                Section(title: "2. 敏感个人信息", body: "体型照片、食物照片、健康与身体数据可能属于敏感个人信息。我们仅在你主动使用对应功能并同意后处理；你可以拒绝或撤回同意，但相关功能将无法使用。"),
                Section(title: "3. 使用目的", body: "用于生成和调整训练/饮食计划、记录与复盘、提供 AI 教练回答、器械识别、保障账号与服务安全、处理订阅和客服问题。我们不会将健康数据用于广告定向。"),
                Section(title: "4. 存储与安全", body: "数据存储在中华人民共和国境内。我们采用访问控制、传输保护、权限隔离和日志审计等措施，仅在实现目的所需期限内保留；注销或删除后，按法律要求处理。"),
                Section(title: "5. 共享与委托处理", body: "我们不会出售个人信息。为提供短信验证、云托管、AI 推理、支付与登录服务，可能委托合作方处理必要信息，并通过协议约束其用途。除法律要求或取得单独同意外，不向第三方提供。"),
                Section(title: "6. 设备权限", body: "相机和相册用于器械、体型与食物照片；通知用于训练提醒；HealthKit 用于读写你授权的训练与体重数据。你可以在系统设置中随时关闭这些权限。"),
                Section(title: "7. 你的权利", body: "你可以访问、更正和导出个人数据，或撤回授权。账号注销与数据删除需由运营方按法律法规及账号安全流程处理。"),
                Section(title: "8. 未成年人保护", body: "未满 14 周岁的用户应在监护人同意和指导下使用；未满 18 周岁的用户应在监护人知情下使用订阅与训练功能。"),
                Section(title: "9. 更新与联系", body: "隐私政策更新会在 App 内公示。对个人信息处理有疑问，可通过 App 内反馈渠道联系我们。")
            ]
        case .ai:
            return [
                Section(title: "1. 服务说明", body: "生成式 AI 用于训练计划、动作替代、饮食建议和教练对话。当前版本可能使用规则引擎或模拟结果，正式模型接入后会更新本说明。"),
                Section(title: "2. 不提供医疗诊断", body: "AI 输出不能替代医生、康复师或营养师的专业意见。出现疼痛、眩晕、胸闷、呼吸困难，或处于孕期、术后恢复期时，请先就医或咨询专业人士。"),
                Section(title: "3. 内容局限", body: "AI 可能产生不准确、不完整或不适用的建议。请结合器械条件、动作能力和身体反应判断，必要时降低负荷或停止训练。"),
                Section(title: "4. 数据与模型", body: "AI 回答会使用你主动提供的档案、训练、饮食和对话信息。我们不会将你的对话用于公开展示；如使用第三方模型服务，将按最小必要原则传输并约束用途。"),
                Section(title: "5. 备案与公示", body: "正式上线前将完成适用的生成式人工智能服务与算法备案，并在 App 内公示模型提供方、备案信息和处理规则。"),
                Section(title: "6. 安全反馈", body: "如果你发现错误、歧视性内容或其他安全问题，请通过 App 内反馈渠道告诉我们，我们会核查并改进。")
            ]
        }
    }

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("练途 · 协议与隐私")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                        Spacer()
                        Text("更新于 2026-10-25")
                            .font(.caption2)
                            .foregroundStyle(Theme.tertiaryText)
                    }

                    Text(kind.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Theme.primaryText)

                    Text(intro)
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(section.title)
                                .font(.headline)
                                .foregroundStyle(Theme.primaryText)
                            Text(section.body)
                                .font(.subheadline)
                                .foregroundStyle(Theme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Text("本页为应用内公示文本。正式上线版本将在 App Store 页面与 App 内同步更新，并由法务复核。")
                        .font(.caption2)
                        .foregroundStyle(Theme.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            Theme.surfaceStrong,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .background(AppBackground())
            .navigationTitle(kind.title)
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
