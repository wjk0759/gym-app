import SwiftUI
import UIKit

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
    @Environment(WeatherStore.self) private var weather
    @Environment(\.openURL) private var openURL

    @State private var serviceState: ServiceState = .checking
    @State private var serviceModel = ""
    @State private var reminderDate = Date()
    @State private var showLogout = false
    @State private var showMessage = false
    @State private var message = ""
    @State private var legalDocument: LegalDocumentKind?
    @State private var showExport = false
    @State private var showBodyCheckIn = false
    @State private var showDeleteAccount = false
    @State private var showAgentMemory = false
    @State private var showWeatherDetail = false

    var body: some View {
        Form {
            accountSection
            serviceSection
            reminderSection
            bodyCheckInSection
            healthSection
            preferenceSection
            weatherSection
            #if DEBUG
            aiSection
            #endif
            privacySection
            accountActionsSection
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .tint(Theme.accentText)
        .onAppear(perform: syncReminder)
        .task {
            await checkService()
            _ = await weather.refreshNotificationAuthorization()
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
        .confirmationDialog(
            "注销账号？",
            isPresented: $showDeleteAccount,
            titleVisibility: .visible
        ) {
            Button("申请注销账号", role: .destructive) {
                Task {
                    do {
                        try await auth.deleteAccount()
                        store.resetAll()
                    } catch {
                        message = "注销失败：\(error.localizedDescription)"
                        showMessage = true
                    }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("账号会进入 15 天冷静期，期间可联系客服恢复；冷静期结束后删除账号及云端数据。本机数据会立即清除。")
        }
        .sheet(isPresented: $showExport) {
            DataExportView()
        }
        .sheet(item: $legalDocument) { kind in
            LegalDocumentView(kind: kind)
        }
        .sheet(isPresented: $showBodyCheckIn) {
            BodyCheckInSheet(manual: true)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showAgentMemory) {
            AgentMemoryView()
        }
        .sheet(isPresented: $showWeatherDetail) {
            WeatherDetailSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.background)
        }
    }

    // MARK: - 账号

    private var accountSection: some View {
        Section {
            LabeledContent("登录账号", value: maskedPhone)

            LabeledContent("用户 ID") {
                Text(String(auth.userID?.prefix(8) ?? ""))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            NavigationLink {
                PasswordSettingsView()
            } label: {
                Label("设置 / 修改登录密码", systemImage: "key")
            }
        } header: {
            Text("账号与安全")
        } footer: {
            Text("登录态已加密保存在本机 Keychain。")
        }
    }

    private var maskedPhone: String {
        guard let phone = auth.phone, phone.count == 11 else {
            return "已登录"
        }
        return "\(phone.prefix(3))****\(phone.suffix(4))"
    }

    // MARK: - 服务状态

    private var serviceSection: some View {
        Section {
            HStack(spacing: 10) {
                Circle()
                    .fill(serviceColor)
                    .frame(width: 9, height: 9)
                Text(serviceText)
                    .font(.subheadline)
                Spacer(minLength: 0)
            }

            LabeledContent("会员", value: subscriptions.isPro ? "Pro" : "免费")
            LabeledContent(
                "AI 服务",
                value: store.canUseRemoteAI ? "远程 DeepSeek" : "本地规则"
            )

            Button("重新检查") {
                Task { await checkService() }
            }
            .buttonStyle(.borderless)

            #if DEBUG
            VStack(alignment: .leading, spacing: 2) {
                Text("API 地址")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(AppConfig.apiBaseURLString)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            #endif
        } header: {
            Text("服务状态")
        } footer: {
            if serviceState == .offline {
                Text("未连接后端时，登录同步、真实 AI、教学视频等功能会不可用；本地训练记录仍可继续使用。")
            }
        }
    }

    private var serviceText: String {
        switch serviceState {
        case .checking: return "正在检查后端连接…"
        case .online: return serviceModel.isEmpty ? "后端已连接，账号与 AI 服务可用" : "后端已连接 · \(serviceModel)"
        case .offline: return "后端未连接，请检查服务地址和网络"
        }
    }

    private var serviceColor: Color {
        switch serviceState {
        case .checking: return Theme.warning
        case .online: return Theme.accentText
        case .offline: return Theme.danger
        }
    }

    private func checkService() async {
        serviceState = .checking
        do {
            let status = try await APIClient.shared.healthStatus()
            serviceState = status.status == "ok" ? .online : .offline
            serviceModel = status.llm ?? ""
        } catch {
            serviceState = .offline
            serviceModel = ""
        }
    }

    // MARK: - 训练设置

    private var reminderSection: some View {
        Section {
            DatePicker(
                "提醒时间",
                selection: $reminderDate,
                displayedComponents: .hourAndMinute
            )

            Button("保存提醒") {
                saveReminder()
            }
            .buttonStyle(.borderless)

            if store.notificationsEnabled {
                Button("关闭训练提醒") {
                    store.disableReminders()
                    message = "已关闭训练提醒。"
                    showMessage = true
                }
                .buttonStyle(.borderless)
            }
        } header: {
            Text("训练提醒")
        } footer: {
            Text(
                store.notificationsEnabled
                    ? "已开启：共 \(store.plan?.firstWeek.count ?? 0) 个训练日。修改计划后会自动更新。"
                    : "未开启。iOS 的静音和专注模式可能影响提醒，请在系统设置中允许通知。"
            )
        }
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

    private var bodyCheckInSection: some View {
        Section {
            Picker(
                "提醒频率",
                selection: Binding(
                    get: { store.bodyCheckInFrequency },
                    set: { store.setBodyCheckInFrequency($0) }
                )
            ) {
                ForEach(BodyCheckInFrequency.allCases) { frequency in
                    Text(frequency.title).tag(frequency)
                }
            }
            .pickerStyle(.menu)

            if store.bodyCheckInFrequency == .weekly
                || store.bodyCheckInFrequency == .biweekly {
                Picker(
                    "提醒日",
                    selection: Binding(
                        get: { store.bodyCheckInWeekday },
                        set: { store.setBodyCheckInWeekday($0) }
                    )
                ) {
                    ForEach(1...7, id: \.self) { weekday in
                        Text(Weekday.shortNames[weekday - 1]).tag(weekday)
                    }
                }
                .pickerStyle(.menu)
            }

            if store.bodyCheckInFrequency == .monthly {
                Picker(
                    "每月几号",
                    selection: Binding(
                        get: { store.bodyCheckInDay },
                        set: { store.setBodyCheckInDay($0) }
                    )
                ) {
                    ForEach(1...28, id: \.self) { day in
                        Text("\(day) 日").tag(day)
                    }
                }
                .pickerStyle(.menu)
            }

            Button("记录今日身体数据") {
                showBodyCheckIn = true
            }
            .buttonStyle(.borderless)
        } header: {
            Text("身体数据提醒")
        } footer: {
            Text("到日期后打开「今日」会弹出体重 / 体脂 / 腰围记录卡；保存或隐藏后本次消失。")
        }
    }

    private var healthSection: some View {
        Section {
            LabeledContent(
                "状态",
                value: store.healthKitEnabled ? "已连接 · 体重会同步" : "未连接"
            )

            if store.healthKitEnabled {
                Button("关闭 Apple 健康同步") {
                    store.disableHealthKit()
                    message = "已关闭 Apple 健康同步。"
                    showMessage = true
                }
                .buttonStyle(.borderless)
            } else {
                Button("连接 Apple 健康") {
                    connectHealthKit()
                }
                .buttonStyle(.borderless)
            }
        } header: {
            Text("Apple 健康")
        } footer: {
            Text("连接后读取最近体重，并把完成的训练写入 Apple 健康。")
        }
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

    private var preferenceSection: some View {
        Section {
            LabeledContent("已记住", value: "\(store.dislikedSlugs.count) 个动作")

            if !store.dislikedSlugs.isEmpty {
                Button("清除训练偏好") {
                    store.clearPreferences()
                    message = "已清除训练偏好，下次生成会重新考虑这些动作。"
                    showMessage = true
                }
                .buttonStyle(.borderless)
            }
        } header: {
            Text("训练偏好")
        } footer: {
            Text("在计划里删除过的动作会被记住，下次生成时尽量避开；重新添加会解除。")
        }
    }

    // MARK: - 天气

    private var weatherSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: weather.snapshot?.symbolName ?? "cloud.sun.fill")
                    .font(.title3)
                    .foregroundStyle(weatherIconTint)
                    .frame(width: 30, height: 30)
                    .background(
                        weatherIconTint.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(weather.snapshot?.placeDisplayName ?? "本地天气")
                        .font(.subheadline.weight(.semibold))
                    Text(
                        weather.snapshot.map {
                            "\($0.conditionLabel) · \($0.temperatureText)"
                        } ?? weather.authorizationLabel
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)

                Button("详情") {
                    showWeatherDetail = true
                }
                .font(.footnote.weight(.semibold))
                .buttonStyle(.borderless)
            }

            Toggle(
                isOn: Binding(
                    get: { weather.alertsEnabled },
                    set: { weather.setWeatherAlerts($0) }
                )
            ) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("恶劣天气出行提醒")
                    Text("有雨雪、大风或降雨概率较高时，每天最多提醒一次；夜间不打扰")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(Theme.accentText)

            if weather.alertsEnabled && !weather.alertsAuthorized {
                Button("开启系统通知权限") {
                    Task {
                        let granted = await weather.requestWeatherAlertPermission()
                        message = granted
                            ? "天气提醒已开启。"
                            : "没有获得通知权限，请到系统设置中允许「练途」通知。"
                        showMessage = true
                    }
                }
                .buttonStyle(.borderless)

                Button("去系统设置") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    openURL(url)
                }
                .buttonStyle(.borderless)
            }
        } header: {
            Text("天气与出行")
        } footer: {
            Text("定位只用于本地天气查询；关闭 App 后不会持续获取位置。")
        }
    }

    private var weatherIconTint: Color {
        weather.snapshot?.isWet == true ? Theme.blue : Theme.accentText
    }

    // MARK: - AI 与连接

    #if DEBUG
    private var aiSection: some View {
        Section {
            Toggle("使用远程 AI", isOn: remoteBinding)
                .tint(Theme.accentText)

            Toggle(
                "开发模式：跳过 Pro 限制",
                isOn: Binding(
                    get: { store.debugForceRemoteAI },
                    set: { store.debugForceRemoteAI = $0 }
                )
            )
            .tint(Theme.accentText)

            VStack(alignment: .leading, spacing: 2) {
                Text("API 地址")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(AppConfig.apiBaseURL.absoluteString)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Button("测试连接") {
                testConnection()
            }
            .buttonStyle(.borderless)
        } header: {
            Text("AI 与连接")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text(
                    store.isPro
                        ? (store.useRemoteAI
                            ? "Pro 已解锁：生成计划、教练对话和视觉识别会请求 DeepSeek/后端；失败时自动回退本地。"
                            : "已开通 Pro，但当前关闭了远程 AI。打开开关后可使用 DeepSeek。")
                        : "AI 能力为 Pro 会员权益。未开通时使用本地规则建议；开通后可调用 DeepSeek 的 AI 私人健身教练。"
                )
                Text("开发模式仅 Debug 生效，用于在没有 StoreKit 商品时预览 DeepSeek；正式版本仍按 Pro 权益限制。")
            }
        }
    }
    #endif

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
                let status = try await APIClient.shared.healthStatus()
                serviceModel = status.llm ?? ""
                message = status.status == "ok"
                    ? "后端连接成功 · \(status.llm ?? "模型未配置")"
                    : "能连上后端，但健康检查返回异常。"
            } catch {
                message = "连接失败：\(error.localizedDescription)"
            }
            showMessage = true
        }
    }

    // MARK: - 数据与隐私

    private var privacySection: some View {
        Section {
            infoRow("隐私政策", icon: "hand.raised") {
                legalDocument = .privacy
            }
            infoRow("用户协议", icon: "doc.text") {
                legalDocument = .terms
            }
            infoRow("AI 记忆", icon: "brain.head.profile") {
                showAgentMemory = true
            }
            infoRow("导出我的数据", icon: "square.and.arrow.up") {
                showExport = true
            }
            infoRow("生成式 AI 备案信息", icon: "checkmark.seal") {
                legalDocument = .ai
            }

            if let repDBURL = URL(string: "https://repdb.co/") {
                Link(destination: repDBURL) {
                    HStack {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .foregroundStyle(Theme.accentText)
                            .frame(width: 22)
                        Text("动作图：Exercise data by RepDB (repdb.co)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
            }
        } header: {
            Text("协议与数据")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("本产品不提供医疗诊断或治疗建议。孕期、术后、心血管疾病或关节急性疼痛，请先咨询医生。")
                Text("版本 \(AppConfig.appVersion)")
            }
        }
    }

    // MARK: - 账号操作

    private var accountActionsSection: some View {
        Section {
            Button("退出登录", role: .destructive) {
                showLogout = true
            }
            Button("注销账号", role: .destructive) {
                showDeleteAccount = true
            }
        } header: {
            Text("账号操作")
        } footer: {
            Text("退出登录不会删除训练计划、训练记录或身体数据。")
        }
    }

    // MARK: - 通用行

    private func infoRow(
        _ title: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(Theme.accentText)
                    .frame(width: 22)
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
