import SwiftUI

struct SettingsToolbarButton: View {
    var body: some View {
        NavigationLink {
            SettingsView()
        } label: {
            Image(systemName: "gearshape")
        }
        .accessibilityLabel("设置")
    }
}

struct SettingsView: View {
    private enum ServiceState {
        case checking
        case online
        case offline
    }

    @Environment(AppStore.self) private var store
    @Environment(AuthStore.self) private var auth
    @Environment(SubscriptionManager.self) private var subscriptions

    @State private var serviceState: ServiceState = .checking
    @State private var reminderDate = Date()
    @State private var showLogout = false
    @State private var showMessage = false
    @State private var message = ""
    @State private var legalDocument: LegalDocumentKind?
    @State private var showExport = false
    @State private var showPasswordSettings = false

    var body: some View {
        AppScrollView {
            VStack(spacing: 16) {
                accountCard

                sectionLabel("服务状态")
                serviceCard

                sectionLabel("训练设置")
                reminderCard
                healthCard
                preferenceCard

#if DEBUG
                sectionLabel("AI 与连接")
                aiCard
#endif

                sectionLabel("数据与隐私")
                privacyCard

                sectionLabel("账号操作")
                logoutCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(AppBackground())
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.large)
        .onAppear(perform: syncReminder)
        .task {
            await checkService()
        }
        .alert("提示", isPresented: $showMessage) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(message)
        }
        .confirmationDialog(
            "退出当前账号？",
            isPresented: $showLogout,
            titleVisibility: .visible
        ) {
            Button("退出登录", role: .destructive) {
                Task { await auth.logout() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("退出后本机训练数据会保留，下次登录可继续使用。")
        }
        .sheet(isPresented: $showExport) {
            DataExportView()
        }
        .sheet(item: $legalDocument) { kind in
            LegalDocumentView(kind: kind)
        }
        .sheet(isPresented: $showPasswordSettings) {
            PasswordSettingsView()
        }
    }

    // MARK: - 账号

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("账号与安全")
                        .font(.headline)
                    Text("登录态已加密保存在本机 Keychain")
                        .font(.caption2)
                        .foregroundStyle(Theme.tertiaryText)
                }
                Spacer()
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(Theme.accent)
            }

            HStack {
                Text("登录账号")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                Spacer()
                Text(maskedPhone)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
            }

            HStack {
                Text("用户 ID")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                Spacer()
                Text(String(auth.userID?.prefix(8) ?? ""))
                    .font(.caption.monospaced())
                    .foregroundStyle(Theme.tertiaryText)
            }

            infoRow("设置 / 修改登录密码", icon: "key") {
                showPasswordSettings = true
            }
        }
        .card()
    }

    private var logoutCard: some View {
        VStack(spacing: 10) {
            Button {
                showLogout = true
            } label: {
                Text("退出登录")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.danger)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Theme.danger.opacity(0.10))
                    )
            }
            .buttonStyle(.plain)

            Text("退出登录不会删除训练计划、训练记录或身体数据。")
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    private var maskedPhone: String {
        guard let phone = auth.phone, phone.count == 11 else {
            return "已登录"
        }
        return "\(phone.prefix(3))****\(phone.suffix(4))"
    }

    private var serviceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("服务连接")
                        .font(.headline)
                    Text(serviceText)
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                Circle()
                    .fill(serviceColor)
                    .frame(width: 9, height: 9)
            }

#if DEBUG
            Text(AppConfig.apiBaseURLString)
                .font(.caption2.monospaced())
                .foregroundStyle(Theme.tertiaryText)
#endif

            HStack(spacing: 10) {
                statusPill(
                    "会员",
                    subscriptions.isPro ? "Pro" : "免费",
                    active: subscriptions.isPro
                )
                statusPill(
                    "AI",
                    store.isPro && store.useRemoteAI ? "DeepSeek" : "本地规则",
                    active: store.isPro && store.useRemoteAI
                )
            }

            Button("重新检查") {
                Task { await checkService() }
            }
            .buttonStyle(SecondaryButtonStyle())

            if serviceState == .offline {
                Text("未连接后端时，登录同步、真实 AI、教学视频等功能会不可用；本地训练记录仍可继续使用。")
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
    }

    private var serviceText: String {
        switch serviceState {
        case .checking: return "正在检查后端连接…"
        case .online: return "后端已连接，账号与 AI 服务可用"
        case .offline: return "后端未连接，请检查服务地址和网络"
        }
    }

    private var serviceColor: Color {
        switch serviceState {
        case .checking: return Theme.warning
        case .online: return Theme.accent
        case .offline: return Theme.danger
        }
    }

    private func statusPill(_ title: String, _ value: String, active: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(active ? Theme.accent : Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Theme.surfaceStrong, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func checkService() async {
        serviceState = .checking
        do {
            let ok = try await APIClient.shared.health()
            serviceState = ok ? .online : .offline
        } catch {
            serviceState = .offline
        }
    }

    // MARK: - 训练设置

    private var reminderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("训练提醒")
                        .font(.headline)
                    Text("按每周训练日发送本地通知")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                Image(systemName: store.notificationsEnabled ? "bell.badge.fill" : "bell.slash")
                    .foregroundStyle(store.notificationsEnabled ? Theme.accent : Theme.tertiaryText)
            }

            DatePicker(
                "提醒时间",
                selection: $reminderDate,
                displayedComponents: .hourAndMinute
            )
            .font(.subheadline)

            HStack(spacing: 10) {
                Button("保存提醒") {
                    saveReminder()
                }
                .buttonStyle(PrimaryButtonStyle())

                if store.notificationsEnabled {
                    Button("关闭") {
                        store.disableReminders()
                        message = "已关闭训练提醒。"
                        showMessage = true
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }

            Text(store.notificationsEnabled
                 ? "已开启：共 \(store.plan?.firstWeek.count ?? 0) 个训练日。修改计划后会自动更新。"
                 : "未开启。iOS 的静音和专注模式可能影响提醒，请在系统设置中允许通知。")
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
        }
        .card()
    }

    private func syncReminder() {
        reminderDate = Calendar.current.date(
            bySettingHour: store.reminderHour,
            minute: store.reminderMinute,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    private func saveReminder() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: reminderDate)
        let hour = components.hour ?? 19
        let minute = components.minute ?? 0

        Task { @MainActor in
            let count = await store.enableReminders(hour: hour, minute: minute)
            if count > 0 {
                message = "已为 \(count) 个训练日设置 \(String(format: "%02d:%02d", hour, minute)) 的提醒。"
            } else if store.notificationsEnabled {
                message = "通知权限已开启，但当前还没有训练计划。生成计划后会自动安排提醒。"
            } else {
                message = "没有获得通知权限。请到「设置 → 通知 → 练途」中开启。"
            }
            showMessage = true
        }
    }

    private var healthCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Apple 健康")
                        .font(.headline)
                    Text(store.healthKitEnabled ? "已连接 · 体重会同步" : "未连接")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                Image(systemName: "heart.text.square.fill")
                    .foregroundStyle(
                        store.healthKitEnabled ? Theme.accent : Theme.tertiaryText
                    )
            }

            Text("连接后读取最近体重，并把完成的训练写入 Apple 健康。")
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)

            if store.healthKitEnabled {
                Button("关闭 Apple 健康同步") {
                    store.disableHealthKit()
                    message = "已关闭 Apple 健康同步。"
                    showMessage = true
                }
                .buttonStyle(SecondaryButtonStyle())
            } else {
                Button("连接 Apple 健康") {
                    connectHealthKit()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .card()
    }

    private func connectHealthKit() {
        Task { @MainActor in
            let granted = await store.enableHealthKit()
            if granted {
                message = "已连接 Apple 健康，体重已同步。"
            } else {
                message = "未获得权限，或当前设备不支持 HealthKit。请到系统「健康 → 数据访问」中检查。"
            }
            showMessage = true
        }
    }

    private var preferenceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("训练偏好")
                    .font(.headline)
                Spacer()
                Text("已记住 \(store.dislikedSlugs.count) 个")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }

            Text("在计划里删除过的动作会被记住，下次生成时尽量避开；重新添加会解除。")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if !store.dislikedSlugs.isEmpty {
                Button("清除训练偏好") {
                    store.clearPreferences()
                    message = "已清除训练偏好，下次生成会重新考虑这些动作。"
                    showMessage = true
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .card()
    }

    // MARK: - AI 与连接

    private var aiCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("AI 服务")
                        .font(.headline)
                    Text(store.useRemoteAI ? "远程模式 · 调用后端模型" : "本地模式 · 规则模板")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                Toggle("", isOn: remoteBinding)
                    .labelsHidden()
                    .tint(Theme.accent)
            }

            Text(store.isPro
                 ? (store.useRemoteAI
                    ? "Pro 已解锁：生成计划、教练对话和视觉识别会请求 DeepSeek/后端；失败时自动回退本地。"
                    : "已开通 Pro，但当前关闭了远程 AI。打开开关后可使用 DeepSeek。")
                 : "AI 能力为 Pro 会员权益。未开通时使用本地规则建议；开通后可调用 DeepSeek 的教练、康复师和营养师 Skill。")
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(AppConfig.apiBaseURL.absoluteString)
                .font(.caption2)
                .foregroundStyle(Theme.secondaryText)

            Button("测试连接") {
                testConnection()
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .card()
    }

    private var remoteBinding: Binding<Bool> {
        Binding(
            get: { store.useRemoteAI },
            set: {
                store.useRemoteAI = $0
                store.persist()
            }
        )
    }

    private func testConnection() {
        Task { @MainActor in
            do {
                let ok = try await APIClient.shared.health()
                message = ok ? "后端连接成功。" : "能连上后端，但健康检查返回异常。"
            } catch {
                message = "连接失败：\(error.localizedDescription)"
            }
            showMessage = true
        }
    }

    // MARK: - 数据与隐私

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("协议与数据")
                .font(.headline)

            infoRow("隐私政策", icon: "hand.raised") {
                legalDocument = .privacy
            }
            infoRow("用户协议", icon: "doc.text") {
                legalDocument = .terms
            }

            Button {
                showExport = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(Theme.accent)
                        .frame(width: 22)
                    Text("导出我的数据")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(Theme.tertiaryText)
                }
            }
            .buttonStyle(.plain)

            infoRow("生成式 AI 备案信息", icon: "checkmark.seal") {
                legalDocument = .ai
            }

            Text("本产品不提供医疗诊断或治疗建议。孕期、术后、心血管疾病或关节急性疼痛，请先咨询医生。")
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("版本 \(AppConfig.appVersion)")
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
        }
        .card()
    }

    private func infoRow(
        _ title: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 22)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
            }
        }
        .buttonStyle(.plain)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.tertiaryText)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
            .padding(.horizontal, 2)
    }
}
