import Foundation
import SwiftUI

struct ProfileView: View {
    @Environment(AppStore.self) private var store

    @State private var reminderDate = Date()
    @State private var showReset = false
    @State private var showMessage = false
    @State private var message = ""
    @State private var showPlaceholder = false
    @State private var showExport = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    profileCard
                    metricsCard
                    goalCard
                    reminderCard
                    healthCard
                    planCard
                    aiCard
                    preferenceCard
                    complianceCard
                    resetCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.large)
            .onAppear(perform: syncReminder)
            .alert("提醒设置", isPresented: $showMessage) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(message)
            }
            .confirmationDialog(
                "注销并删除全部数据？",
                isPresented: $showReset,
                titleVisibility: .visible
            ) {
                Button("注销并删除", role: .destructive) {
                    store.resetAll()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("档案、计划、训练记录、饮食记录和对话都会被删除，无法恢复。")
            }
            .sheet(isPresented: $showExport) {
                DataExportView()
            }
        }
    }

    // MARK: - 档案

    private var profileCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.18))
                    .frame(width: 58, height: 58)
                Text(String(store.profile.nickname.prefix(1)))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(store.profile.nickname)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Text("\(store.profile.goalType.label) · \(store.profile.experience.label) · 每周 \(store.profile.weeklyDays) 练")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }

            Spacer()

            Button("编辑") {
                store.editProfile()
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Theme.accent)
        }
        .card()
    }

    private var metricsCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                metric("体重", String(format: "%.1f kg", store.profile.weightKG))
                metric("BMI", String(format: "%.1f", store.profile.bmi) + " · " + store.profile.bmiLabel)
            }
            HStack(spacing: 12) {
                metric("腰围", String(format: "%.0f cm", store.profile.waistCM))
                metric("身高", String(format: "%.0f cm", store.profile.heightCM))
            }
            HStack(spacing: 12) {
                metric("累计训练", "\(store.sessions.count) 次")
                metric("总容量", "\(Int(store.totalVolume / 1000))k kg")
            }
        }
        .card()
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.surfaceStrong, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var goalCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("当前目标")
                    .font(.headline)
                Spacer()
                Text(store.profile.goalType.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.accent.opacity(0.12), in: Capsule())
            }

            if store.profile.goalType != .endurance {
                HStack {
                    Text("目标体重")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                    Spacer()
                    Text("\(store.profile.targetWeightKG, specifier: "%.1f") kg")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }

            if let targetWaist = store.profile.targetWaistCM {
                HStack {
                    Text("目标腰围")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                    Spacer()
                    Text(String(format: "%.0f cm", targetWaist))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }

            HStack {
                Text("目标日期")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                Spacer()
                Text(store.profile.targetDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
            }

            Text("目标仅作方向，不追求极端速度。减重建议不超过 0.5kg/周。")
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
        }
        .card()
    }

    // MARK: - 提醒

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

    // MARK: - 计划与合规

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

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("训练计划")
                .font(.headline)

            if let plan = store.plan {
                Text(plan.title)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                Text("第 \(plan.version) 版 · \(plan.days.count) 个训练日")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)

                Button {
                    store.generatePlan()
                    message = "正在重新生成计划，完成后可在「计划」页查看。"
                    showMessage = true
                } label: {
                    Label("重新生成", systemImage: "arrow.clockwise")
                }
                .buttonStyle(SecondaryButtonStyle())
            } else {
                Text("还没有计划。")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                Button("生成计划") {
                    store.generatePlan()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .card()
    }

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

            Text(store.useRemoteAI
                 ? "生成计划、教练对话、器械识别会请求后端；请求失败会自动回退到本地。"
                 : "当前不联网，使用内置规则生成计划。切到远程需要先启动 backend。")
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

    private var complianceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("关于与合规")
                .font(.headline)

            infoRow("隐私政策", icon: "hand.raised")
            infoRow("用户协议", icon: "doc.text")

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

            infoRow("生成式 AI 备案信息", icon: "checkmark.seal")

            Text("本产品不提供医疗诊断或治疗建议。孕期、术后、心血管疾病或关节急性疼痛，请先咨询医生。")
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text("版本 \(AppConfig.appVersion)")
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
        }
        .card()
        .alert("功能占位", isPresented: $showPlaceholder) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("上线前需要替换为正式的隐私政策、用户协议与备案信息。")
        }
    }

    private func infoRow(_ title: String, icon: String) -> some View {
        Button {
            showPlaceholder = true
        } label: {
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

    private var resetCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("注销与本地数据")
                .font(.headline)
            Text("当前版本没有账号体系，数据只在这台设备上。注销即删除本机全部数据，无法恢复。")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
            Button(role: .destructive) {
                showReset = true
            } label: {
                Text("注销并删除全部数据")
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
        }
        .card()
    }
}
