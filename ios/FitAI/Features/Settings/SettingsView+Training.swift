import SwiftUI

extension SettingsView {
    // MARK: - 训练设置

    var reminderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("训练提醒")
                        .font(AppType.headline)
                    Text("按每周训练日发送本地通知")
                        .font(AppType.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                Image(systemName: store.notificationsEnabled ? "bell.badge.fill" : "bell.slash")
                    .foregroundStyle(store.notificationsEnabled ? Theme.cobalt : Theme.tertiaryText)
            }

            DatePicker(
                "提醒时间",
                selection: $reminderDate,
                displayedComponents: .hourAndMinute
            )
            .font(AppType.callout)

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
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
        }
        .card()
    }

    var weatherCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: weather.snapshot?.symbolName ?? "cloud.sun.fill")
                    .font(.title3)
                    .foregroundStyle(weather.snapshot?.isWet == true ? Theme.blue : Theme.cobalt)
                    .frame(width: 30, height: 30)
                    .background(
                        (weather.snapshot?.isWet == true ? Theme.blue : Theme.cobalt).opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(weather.snapshot?.placeDisplayName ?? "本地天气")
                        .font(AppType.callout.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text(weather.snapshot.map { "\($0.conditionLabel) · \($0.temperatureText)" } ?? weather.authorizationLabel)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                }

                Spacer(minLength: 4)

                Button("详情") { showWeatherDetail = true }
                    .font(AppType.caption.weight(.semibold))
                    .foregroundStyle(Theme.cobalt)
            }

            Toggle(
                isOn: Binding(
                    get: { weather.alertsEnabled },
                    set: { weather.setWeatherAlerts($0) }
                )
            ) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("恶劣天气出行提醒")
                        .font(AppType.callout)
                        .foregroundStyle(Theme.ink)
                    Text("有雨雪、大风或降雨概率较高时，每天最多提醒一次；夜间不打扰")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                }
            }
            .tint(Theme.primary)

            if weather.alertsEnabled && !weather.alertsAuthorized {
                HStack(spacing: 12) {
                    Button("开启系统通知权限") {
                        Task {
                            let granted = await weather.requestWeatherAlertPermission()
                            message = granted
                                ? "天气提醒已开启。"
                                : "没有获得通知权限，请到系统设置中允许「练途」通知。"
                            showMessage = true
                        }
                    }
                    .font(AppType.caption.weight(.semibold))
                    .foregroundStyle(Theme.cobalt)

                    Button("去系统设置") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        openURL(url)
                    }
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(Theme.tertiaryText)
                }
            }

            Text("定位只用于本地天气查询；关闭 App 后不会持续获取位置。")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
        }
        .card(padding: 14)
        .task {
            await weather.refreshNotificationAuthorization()
        }
    }

    func syncReminder() {
        reminderDate = Calendar.current.date(
            bySettingHour: store.reminderHour,
            minute: store.reminderMinute,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    func saveReminder() {
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

    var bodyCheckInCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("身体数据提醒")
                        .font(AppType.headline)
                    Text(store.bodyCheckInFrequencyLabel)
                        .font(AppType.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                Image(systemName: store.bodyCheckInFrequency == .off ? "bell.slash" : "bell.badge")
                    .foregroundStyle(store.bodyCheckInFrequency == .off ? Theme.tertiaryText : Theme.cobalt)
            }

            Text("到日期后打开「今日」会弹出体重 / 体脂 / 腰围记录卡；保存或隐藏后本次消失。")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 7) {
                ForEach(BodyCheckInFrequency.allCases) { frequency in
                    Button {
                        store.setBodyCheckInFrequency(frequency)
                    } label: {
                        Text(frequency.title)
                            .font(AppType.caption.weight(.semibold))
                            .foregroundStyle(store.bodyCheckInFrequency == frequency ? Theme.onAccent : Theme.secondaryText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                Capsule().fill(store.bodyCheckInFrequency == frequency ? Theme.cobalt : Theme.ink.opacity(0.035))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            if store.bodyCheckInFrequency == .weekly || store.bodyCheckInFrequency == .biweekly {
                VStack(alignment: .leading, spacing: 7) {
                    Text("选择星期")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                    HStack(spacing: 5) {
                        ForEach(1...7, id: \.self) { weekday in
                            Button {
                                store.setBodyCheckInWeekday(weekday)
                            } label: {
                                Text(Weekday.shortNames[weekday - 1])
                                    .font(.system(size: 9.5, weight: .semibold))
                                    .foregroundStyle(store.bodyCheckInWeekday == weekday ? Theme.onAccent : Theme.secondaryText)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 7)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(store.bodyCheckInWeekday == weekday ? Theme.cobalt : Theme.ink.opacity(0.035))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if store.bodyCheckInFrequency == .monthly {
                HStack {
                    Text("每月几号")
                        .font(AppType.caption)
                        .foregroundStyle(Theme.secondaryText)
                    Spacer()
                    Picker("每月几号", selection: Binding(
                        get: { store.bodyCheckInDay },
                        set: { store.setBodyCheckInDay($0) }
                    )) {
                        ForEach(1...28, id: \.self) { day in
                            Text("\(day) 日").tag(day)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.cobalt)
                }
            }

            Button("记录今日身体数据") {
                showBodyCheckIn = true
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .card()
    }

    var healthCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Apple 健康")
                        .font(AppType.headline)
                    Text(store.healthKitEnabled ? "已连接 · 体重会同步" : "未连接")
                        .font(AppType.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                Image(systemName: "heart.text.square.fill")
                    .foregroundStyle(
                        store.healthKitEnabled ? Theme.cobalt : Theme.tertiaryText
                    )
            }

            Text("连接后读取最近体重，并把完成的训练写入 Apple 健康。")
                .font(.system(size: 9.5, weight: .medium))
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

    func connectHealthKit() {
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

    var preferenceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("训练偏好")
                    .font(AppType.headline)
                Spacer()
                Text("已记住 \(store.dislikedSlugs.count) 个")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
            }

            Text("在计划里删除过的动作会被记住，下次生成时尽量避开；重新添加会解除。")
                .font(AppType.caption)
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
}
