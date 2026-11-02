import SwiftUI
import AuthenticationServices

extension LoginView {
    var keyboardDoneBar: some View {
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

    func header(compact: Bool) -> some View {
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

    func headline(compact: Bool) -> some View {
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

    func loginCard(compact: Bool) -> some View {
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

    var modeSwitch: some View {
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

    func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(AppType.caption.weight(.medium))
            .foregroundStyle(Theme.secondaryText)
            .padding(.leading, 2)
    }

    func fieldShell<Content: View>(
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

    var phoneFields: some View {
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

    var passwordFields: some View {
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

    var consentFooter: some View {
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

    func socialSection(compact: Bool) -> some View {
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

    var devServerLink: some View {
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

    func socialButton(
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
}
