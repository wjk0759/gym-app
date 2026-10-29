import AuthenticationServices
import Foundation
import SwiftUI

struct LoginView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private enum Mode: String, CaseIterable, Identifiable, Hashable {
        case phone = "手机验证码"
        case password = "账号密码"

        var id: String { rawValue }
    }

    private enum Field: Hashable {
        case phone
        case code
        case account
        case password
    }

    private enum ActiveAction: Equatable {
        case phoneLogin
        case passwordLogin
        case apple
        case social(String)
        case sendingCode
    }

    private static let consentMessage = "请先勾选同意《用户协议》《隐私政策》和《生成式 AI 服务说明》。"

    @State private var mode: Mode = .phone
    @State private var phone = ""
    @State private var code = ""
    @State private var account = ""
    @State private var password = ""
    @State private var consent = false
    @State private var showPassword = false
    @State private var countdown = 0
    @State private var countdownTask: Task<Void, Never>?
    @State private var activeAction: ActiveAction?
    @State private var devCode: String?
    @State private var localError: String?
    @State private var showConsentError = false
    @State private var registrationHint = false
    @State private var legal: LegalDocumentKind?
    @State private var showServerSettings = false
    @State private var showPasswordReset = false
    @State private var showRegistration = false
    @State private var registrationAccount = ""
    @State private var registrationPhone = ""
    @State private var resetPhone = ""

    @FocusState private var focusedField: Field?

    private var isAuthenticating: Bool {
        guard let activeAction else { return false }
        switch activeAction {
        case .phoneLogin, .passwordLogin, .apple, .social:
            return true
        case .sendingCode:
            return false
        }
    }

    private var isLoggingIn: Bool {
        activeAction == .phoneLogin || activeAction == .passwordLogin
    }

    private var isSendingCode: Bool {
        activeAction == .sendingCode
    }

    private var isValidPhone: Bool {
        AuthInput.isValidPhone(phone)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("登录方式", selection: $mode) {
                        ForEach(Mode.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .tint(Theme.accentFill)
                    .disabled(isAuthenticating || isSendingCode)
                    .listRowInsets(
                        EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
                    )

                    Group {
                        if mode == .phone {
                            phoneFields
                        } else {
                            passwordFields
                        }
                    }
                    .disabled(isAuthenticating)
                    .animation(
                        reduceMotion ? nil : Animation.snappy(duration: 0.2),
                        value: mode
                    )
                } header: {
                    Text("登录方式")
                } footer: {
                    modeFooter
                }

                Section {
                    consentRow
                    loginButton
                } footer: {
                    actionFooter
                }

                Section {
                    appleButton
                    socialButton(
                        provider: "wechat",
                        title: "微信登录",
                        image: Image("WeChatIcon"),
                        tint: Color(red: 0.12, green: 0.72, blue: 0.35)
                    )
                    socialButton(
                        provider: "qq",
                        title: "QQ 登录",
                        image: Image("QQIcon"),
                        tint: Color(red: 0.16, green: 0.62, blue: 0.96)
                    )
                } header: {
                    Text("其他登录方式")
                } footer: {
                    alternativeFooter
                }
            }
            .navigationTitle("登录练途")
            .navigationBarTitleDisplayMode(.large)
            .scrollDismissesKeyboard(.interactively)
            .environment(
                \.openURL,
                OpenURLAction { url in
                    guard url.scheme == "fitai",
                          url.host == "legal",
                          let kind = LegalDocumentKind(rawValue: url.lastPathComponent) else {
                        return .systemAction
                    }
                    legal = kind
                    return .handled
                }
            )
            .toolbar {
                #if DEBUG
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("开发服务器") {
                            showServerSettings = true
                        }
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("开发设置")
                }
                #endif

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") {
                        focusedField = nil
                    }
                }
            }
            .navigationDestination(isPresented: $showPasswordReset) {
                PasswordResetView(
                    prefillPhone: resetPhone,
                    onResetCompleted: { phone in
                        mode = .password
                        account = phone
                        password = ""
                        localError = nil
                        registrationHint = false
                    }
                )
            }
            .navigationDestination(isPresented: $showRegistration) {
                PasswordRegistrationView(
                    suggestedAccount: registrationAccount,
                    prefillPhone: registrationPhone
                )
            }
            .sheet(item: $legal) { kind in
                LegalDocumentView(kind: kind)
            }
            .sheet(isPresented: $showServerSettings) {
                ServerSettingsView()
            }
            .sensoryFeedback(.selection, trigger: mode)
            .sensoryFeedback(.selection, trigger: consent)
            .sensoryFeedback(.error, trigger: localError) { _, newValue in
                newValue != nil
            }
            .announcesAuthError(localError)
            .onChange(of: mode) { _, newMode in
                localError = nil
                registrationHint = false
                guard focusedField != nil else { return }
                focusedField = newMode == .phone ? .phone : .account
            }
            .onChange(of: showRegistration) { _, isShowing in
                guard !isShowing else { return }
                registrationHint = false
                localError = nil
            }
            .onChange(of: auth.isAuthenticated) { _, isAuthenticated in
                if isAuthenticated {
                    countdownTask?.cancel()
                }
            }
        }
        .tint(Theme.accentText)
    }

    // MARK: - Fields

    @ViewBuilder
    private var phoneFields: some View {
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
                    clearFieldError()
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
    }

    private var codeInput: some View {
        TextField("6 位验证码", text: $code)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .focused($focusedField, equals: .code)
            .submitLabel(.go)
            .onSubmit {
                submit()
            }
            .accessibilityLabel("验证码")
            .onChange(of: code) { _, newValue in
                let filtered = AuthInput.codeDigits(newValue)
                if filtered != newValue {
                    code = filtered
                }
                clearFieldError()
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
        .disabled(!isValidPhone || countdown > 0 || isSendingCode || isAuthenticating)
        .accessibilityLabel(
            countdown > 0 ? "\(countdown) 秒后可重新获取验证码" : "获取验证码"
        )
    }

    @ViewBuilder
    private var passwordFields: some View {
        TextField("手机号或用户名", text: $account)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textContentType(.username)
            .focused($focusedField, equals: .account)
            .submitLabel(.next)
            .onSubmit {
                focusedField = .password
            }
            .accessibilityLabel("手机号或用户名")
            .onChange(of: account) { _, _ in
                clearFieldError()
            }

        HStack(spacing: 8) {
            Group {
                if showPassword {
                    TextField("密码", text: $password)
                } else {
                    SecureField("密码", text: $password)
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textContentType(.password)
            .focused($focusedField, equals: .password)
            .submitLabel(.go)
            .onSubmit {
                submit()
            }
            .accessibilityLabel("密码")
            .onChange(of: password) { _, _ in
                clearFieldError()
            }

            Button {
                showPassword.toggle()
                focusedField = .password
            } label: {
                Image(systemName: showPassword ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(showPassword ? "隐藏密码" : "显示密码")
        }
    }

    @ViewBuilder
    private var modeFooter: some View {
        if mode == .phone {
            VStack(alignment: .leading, spacing: 4) {
                Text("未注册的手机号将自动创建账号。验证码仅用于本次登录。")
                #if DEBUG
                if let devCode {
                    Text("开发验证码：\(devCode)")
                        .foregroundStyle(Theme.warning)
                }
                #endif
            }
        } else {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 0) {
                        forgotPasswordButton
                        createAccountButton
                    }
                } else {
                    HStack(spacing: 16) {
                        forgotPasswordButton
                        Spacer(minLength: 8)
                        createAccountButton
                    }
                }
            }
            .font(.footnote.weight(.medium))
            .tint(Theme.accentText)
            .frame(maxWidth: .infinity)
            .disabled(isAuthenticating || isSendingCode)
        }
    }

    private var forgotPasswordButton: some View {
        Button("忘记密码？") {
            openPasswordReset()
        }
        .buttonStyle(.borderless)
        .frame(minHeight: 44, alignment: .leading)
    }

    private var createAccountButton: some View {
        Button("创建账号") {
            openRegistrationForCurrentAccount()
        }
        .buttonStyle(.borderless)
        .frame(minHeight: 44, alignment: .leading)
    }

    // MARK: - Consent and actions

    private var consentRow: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                consent.toggle()
                if consent {
                    showConsentError = false
                    if localError == Self.consentMessage {
                        localError = nil
                    }
                }
            } label: {
                Image(systemName: consent ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(
                        consent
                            ? Theme.accentText
                            : (showConsentError ? Theme.danger : Color.secondary)
                    )
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isAuthenticating)
            .accessibilityLabel("同意用户协议、隐私政策和生成式 AI 服务说明")
            .accessibilityValue(consent ? "已同意" : "未同意")
            .accessibilityHint("登录前必须同意")
            .accessibilityAddTraits(consent ? .isSelected : AccessibilityTraits())

            consentText
                .font(.footnote)
                .foregroundStyle(.secondary)
                .tint(Theme.accentText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 10)
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 16))
        .listRowSeparator(.hidden)
    }

    private var consentText: Text {
        var terms = AttributedString("《用户协议》")
        terms.link = URL(string: "fitai://legal/terms")
        terms.foregroundColor = Theme.accentText

        var privacy = AttributedString("《隐私政策》")
        privacy.link = URL(string: "fitai://legal/privacy")
        privacy.foregroundColor = Theme.accentText

        var ai = AttributedString("《生成式 AI 服务说明》")
        ai.link = URL(string: "fitai://legal/ai")
        ai.foregroundColor = Theme.accentText

        return Text("我已阅读并同意") +
            Text(terms) +
            Text("、") +
            Text(privacy) +
            Text("和") +
            Text(ai) +
            Text("，且已年满 14 周岁")
    }

    private var loginButton: some View {
        Button {
            submit()
        } label: {
            HStack(spacing: 8) {
                if isLoggingIn {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Theme.onAccentFill)
                }
                Text(isLoggingIn ? "正在登录…" : "登录")
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(Theme.onAccentFill)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(Theme.accentFill)
        .disabled(isAuthenticating || isSendingCode)
        .accessibilityLabel(isLoggingIn ? "正在登录" : "登录")
    }

    @ViewBuilder
    private var actionFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let localError {
                Label(localError, systemImage: "exclamationmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(Theme.danger)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .combine)
            }

            if registrationHint {
                Button("创建账号") {
                    openRegistrationForCurrentAccount()
                }
                .buttonStyle(.borderless)
                .font(.footnote.weight(.semibold))
                .tint(Theme.accentText)
                .frame(minHeight: 44, alignment: .leading)
                .disabled(isAuthenticating || isSendingCode)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Other sign-in

    private var appleButton: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName, .email]
            activeAction = .apple
        } onCompletion: { result in
            handleAppleCompletion(result)
        }
        .signInWithAppleButtonStyle(
            colorScheme == .dark
                ? SignInWithAppleButton.Style.white
                : SignInWithAppleButton.Style.black
        )
        .frame(minHeight: 50)
        .frame(maxWidth: .infinity)
        .disabled(!consent || isAuthenticating || isSendingCode)
        .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func socialButton(
        provider: String,
        title: String,
        image: Image,
        tint: Color
    ) -> some View {
        Button {
            performSocialLogin(provider)
        } label: {
            HStack(spacing: 10) {
                if activeAction == .social(provider) {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    image
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(tint)
                }

                Text(title)
                    .foregroundStyle(.primary)
            }
            .font(.body.weight(.medium))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .tint(Theme.accentText)
        .disabled(!consent || isAuthenticating || isSendingCode)
        .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private var alternativeFooter: some View {
        if let activeAction {
            switch activeAction {
            case .apple:
                HStack(spacing: 8) {
                    ProgressView()
                    Text("正在完成 Apple 登录…")
                }
                .font(.footnote)
            case .social(let provider):
                Text("正在完成\(providerTitle(provider))登录…")
                    .font(.footnote)
            case .phoneLogin, .passwordLogin, .sendingCode:
                alternativeHint
            }
        } else {
            alternativeHint
        }
    }

    private var alternativeHint: some View {
        Text(
            consent
                ? "第三方登录会跳转到对应服务完成授权。"
                : "请先勾选上方的协议，再使用其他登录方式。"
        )
        .font(.footnote)
    }

    // MARK: - Logic

    @discardableResult
    private func requireConsent() -> Bool {
        guard consent else {
            localError = Self.consentMessage
            showConsentError = true
            return false
        }
        return true
    }

    private func clearFieldError() {
        localError = nil
        registrationHint = false
    }

    private func submit() {
        guard activeAction == nil else { return }
        guard requireConsent() else { return }

        localError = nil
        registrationHint = false

        switch mode {
        case .phone:
            guard isValidPhone else {
                localError = "请输入正确的 11 位手机号"
                focusedField = .phone
                return
            }
            guard code.count == 6 else {
                localError = "请输入 6 位验证码"
                focusedField = .code
                return
            }

            focusedField = nil
            activeAction = .phoneLogin
            Task { @MainActor in
                defer { activeAction = nil }
                do {
                    try await auth.loginWithPhone(phone: phone, code: code)
                } catch {
                    handleLoginError(error)
                }
            }

        case .password:
            let accountValue = account.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !accountValue.isEmpty else {
                localError = "请输入手机号或用户名"
                focusedField = .account
                return
            }
            guard !password.isEmpty else {
                localError = "请输入密码"
                focusedField = .password
                return
            }

            focusedField = nil
            activeAction = .passwordLogin
            Task { @MainActor in
                defer { activeAction = nil }
                do {
                    try await auth.loginWithPassword(
                        account: accountValue,
                        password: password
                    )
                } catch {
                    handleLoginError(error)
                }
            }
        }
    }

    private func sendCode() {
        guard activeAction == nil else { return }
        guard isValidPhone else {
            localError = "请输入正确的 11 位手机号"
            focusedField = .phone
            return
        }

        localError = nil
        let sentPhone = phone
        activeAction = .sendingCode
        Task { @MainActor in
            defer { activeAction = nil }
            do {
                let value = try await auth.sendCode(phone: sentPhone)
                guard phone == sentPhone else { return }
                if let value {
                    devCode = value
                    code = value
                }
                startCountdown()
                if mode == .phone {
                    focusedField = .code
                }
            } catch {
                localError = error.localizedDescription
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

    private func handleLoginError(_ error: Error) {
        if let authError = error as? AuthError,
           (authError.code == "REGISTRATION_REQUIRED"
            || authError.message.contains("账号未注册")) {
            localError = "该账号尚未注册。"
            registrationHint = true
            return
        }
        localError = error.localizedDescription
    }

    private func performSocialLogin(_ provider: String) {
        guard activeAction == nil else { return }
        guard requireConsent() else { return }

        localError = nil
        activeAction = .social(provider)
        Task { @MainActor in
            defer { activeAction = nil }
            do {
                try await auth.loginWithSocial(provider: provider)
            } catch let error as AuthError where error.code == "CANCELLED" {
                // 用户主动取消，不显示错误。
            } catch {
                localError = error.localizedDescription
            }
        }
    }

    private func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let data = credential.identityToken,
                  let token = String(data: data, encoding: .utf8) else {
                activeAction = nil
                localError = "Apple 登录未返回身份凭证"
                return
            }

            let name = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined()

            activeAction = .apple
            Task { @MainActor in
                defer { activeAction = nil }
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
            activeAction = nil
            if (error as? ASAuthorizationError)?.code == .canceled {
                return
            }
            localError = "Apple 登录失败：\(error.localizedDescription)"
        }
    }

    private func openRegistrationForCurrentAccount() {
        let accountValue = account.trimmingCharacters(in: .whitespacesAndNewlines)
        let phonePrefill = AuthInput.isValidPhone(accountValue)
            ? accountValue
            : (isValidPhone ? phone : "")
        openRegistration(prefillAccount: accountValue, prefillPhone: phonePrefill)
    }

    private func openRegistration(prefillAccount: String, prefillPhone: String) {
        guard activeAction == nil else { return }
        guard requireConsent() else { return }

        focusedField = nil
        localError = nil
        registrationHint = false
        registrationAccount = prefillAccount
        registrationPhone = prefillPhone
        showRegistration = true
    }

    private func openPasswordReset() {
        guard activeAction == nil else { return }
        guard requireConsent() else { return }

        let accountValue = account.trimmingCharacters(in: .whitespacesAndNewlines)
        focusedField = nil
        resetPhone = isValidPhone
            ? phone
            : (AuthInput.isValidPhone(accountValue) ? accountValue : "")
        localError = nil
        registrationHint = false
        showPasswordReset = true
    }

    private func providerTitle(_ provider: String) -> String {
        switch provider {
        case "wechat": return "微信"
        case "qq": return "QQ"
        default: return "第三方"
        }
    }

}
