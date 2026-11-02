import SwiftUI

extension SettingsView {
    // MARK: - 账号

    var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("SETTINGS / 设置")
                .font(AppType.overline)
                .tracking(1.5)
                .foregroundStyle(Theme.cobalt)

            Text("把偏好调好")
                .font(AppType.display)
                .tracking(-0.9)
                .foregroundStyle(Theme.ink)

            Text("提醒、健康、天气和数据都在这里。")
                .font(AppType.body)
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var accountCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("账号与安全")
                        .font(AppType.headline)
                    Text("登录态已加密保存在本机 Keychain")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                }
                Spacer()
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(Theme.cobalt)
            }

            HStack {
                Text("登录账号")
                    .font(AppType.callout)
                    .foregroundStyle(Theme.secondaryText)
                Spacer()
                Text(maskedPhone)
                    .font(AppType.callout)
                    .foregroundStyle(Theme.ink)
            }

            HStack {
                Text("用户 ID")
                    .font(AppType.callout)
                    .foregroundStyle(Theme.secondaryText)
                Spacer()
                Text(String(auth.userID?.prefix(8) ?? ""))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.tertiaryText)
            }

            infoRow("设置 / 修改登录密码", icon: "key") {
                showPasswordSettings = true
            }
        }
        .card()
    }

    var logoutCard: some View {
        VStack(spacing: 10) {
            Button {
                showLogout = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 10, weight: .semibold))
                    Text("退出登录")
                        .font(AppType.caption.weight(.semibold))
                }
                .foregroundStyle(Theme.coral)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    Theme.coral.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(Theme.coral.opacity(0.22), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)

            Text("退出登录不会删除训练计划、训练记录或身体数据。")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            InkDivider()

            Button {
                showDeleteAccount = true
            } label: {
                Text("注销账号")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(Theme.coral)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
            }
            .buttonStyle(.plain)
        }
        .card()
    }

    var maskedPhone: String {
        guard let phone = auth.phone, phone.count == 11 else {
            return "已登录"
        }
        return "\(phone.prefix(3))****\(phone.suffix(4))"
    }

    var serviceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("服务连接")
                        .font(AppType.headline)
                    Text(serviceText)
                        .font(AppType.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                Circle()
                    .fill(serviceColor)
                    .frame(width: 9, height: 9)
            }

#if DEBUG
            Text(AppConfig.apiBaseURLString)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.tertiaryText)
#endif

            HStack(spacing: 10) {
                statusPill(
                    "会员",
                    store.hasProAccess ? "Pro" : "免费",
                    active: store.hasProAccess
                )
                statusPill(
                    "AI",
                    store.canUseRemoteAI ? "DeepSeek" : "本地规则",
                    active: store.canUseRemoteAI
                )
            }

            Button("重新检查") {
                Task { await checkService() }
            }
            .buttonStyle(SecondaryButtonStyle())

            if serviceState == .offline {
                Text("未连接后端时，登录同步、真实 AI、教学视频等功能会不可用；本地训练记录仍可继续使用。")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
    }

    var serviceText: String {
        switch serviceState {
        case .checking: return "正在检查后端连接…"
        case .online: return serviceModel.isEmpty ? "后端已连接，账号与 AI 服务可用" : "后端已连接 · \(serviceModel)"
        case .offline: return "后端未连接，请检查服务地址和网络"
        }
    }

    var serviceColor: Color {
        switch serviceState {
        case .checking: return Theme.tertiaryText
        case .online: return Theme.primary
        case .offline: return Theme.ink
        }
    }

    func statusPill(_ title: String, _ value: String, active: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
            Text(value)
                .font(AppType.caption.weight(.semibold))
                .foregroundStyle(active ? Theme.cobalt : Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Theme.ink.opacity(0.035), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    func checkService() async {
        serviceState = .checking
        do {
            let status = try await BackendHealthService.status()
            serviceState = status.status == "ok" ? .online : .offline
            serviceModel = status.llm ?? ""
        } catch {
            serviceState = .offline
            serviceModel = ""
        }
    }
}
