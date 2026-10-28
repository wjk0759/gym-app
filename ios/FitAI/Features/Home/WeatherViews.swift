import SwiftUI
import UIKit

struct WeatherBadgeView: View {
    @Environment(WeatherStore.self) private var weather
    @Environment(\.weatherAtmosphere) private var atmosphere
    @Environment(\.colorScheme) private var colorScheme

    @State private var showDetail = false

    var body: some View {
        Button {
            Haptics.tap()
            showDetail = true
        } label: {
            HStack(spacing: 7) {
                Image(systemName: symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(atmosphere.isPrecipitation ? atmosphere.accent(for: colorScheme) : Theme.accent)
                    .frame(width: 19)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(primaryText)
                            .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(Theme.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        if weather.isRefreshing {
                            ProgressView()
                                .controlSize(.mini)
                                .tint(Theme.secondaryText)
                        }
                    }

                    Text(secondaryText)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: 104, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Theme.surfaceStrong, in: Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Theme.stroke, lineWidth: 0.8)
            )
        }
        .buttonStyle(SubtlePressStyle(scale: 0.96))
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("打开天气详情和出行提醒设置")
        .sheet(isPresented: $showDetail) {
            WeatherDetailSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.background)
        }
    }

    private var primaryText: String {
        if let snapshot = weather.snapshot {
            return snapshot.temperatureText
        }
        if weather.needsLocationPermission {
            return "开定位"
        }
        switch weather.state {
        case .locating, .loading:
            return "定位中"
        case .permissionDenied:
            return "开定位"
        case .failed:
            return "重试"
        case .idle, .ready:
            return "天气"
        }
    }

    private var secondaryText: String {
        if let snapshot = weather.snapshot {
            if weather.isStale {
                return "\(snapshot.conditionLabel) · 待刷新"
            }
            let condition = atmosphere.isTyphoon ? "台风/大风" : snapshot.conditionLabel
            return "\(condition) · \(snapshot.placeDisplayName)"
        }
        if weather.needsLocationPermission {
            return "允许定位查看天气"
        }
        switch weather.state {
        case .locating, .loading:
            return "获取本地天气"
        case .permissionDenied:
            return "查看天气"
        case .failed:
            return "天气暂不可用"
        case .idle, .ready:
            return "点此查看"
        }
    }

    private var symbolName: String {
        if let snapshot = weather.snapshot {
            return snapshot.symbolName
        }
        if weather.needsLocationPermission {
            return "location.fill"
        }
        switch weather.state {
        case .permissionDenied:
            return "location.slash.fill"
        case .failed:
            return "cloud.slash.fill"
        default:
            return "cloud.sun.fill"
        }
    }

    private var accessibilityText: String {
        guard let snapshot = weather.snapshot else {
            return "天气，\(primaryText)"
        }
        return "\(snapshot.placeDisplayName)，\(snapshot.conditionLabel)，\(snapshot.temperatureText)"
    }
}

struct WeatherDetailSheet: View {
    @Environment(WeatherStore.self) private var weather
    @Environment(\.weatherAtmosphere) private var atmosphere
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var alertMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    currentCard
                    metricsCard
                    alertCard
                    locationCard
                    privacyCard
                }
                .appPagePadding()
                .padding(.vertical, 16)
                .padding(.bottom, 24)
                .appReadableContent()
            }
            .background(AppBackground())
            .navigationTitle("本地天气")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .task {
                await weather.refreshNotificationAuthorization()
                weather.refreshIfNeeded()
            }
        }
    }

    private var currentCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(weather.snapshot?.placeDisplayName ?? "当前位置")
                        .font(.headline)
                        .foregroundStyle(Theme.primaryText)
                        .lineLimit(1)

                    if let snapshot = weather.snapshot {
                        let condition = atmosphere.isTyphoon ? "台风/大风" : snapshot.conditionLabel
                        Text("\(atmosphere.phase.label) · \(condition)")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                    } else {
                        Text("正在获取本地实时天气")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: weather.snapshot?.symbolName ?? "cloud.sun.fill")
                    .font(.system(size: 42, weight: .medium))
                    .foregroundStyle(
                        weather.snapshot?.isWet == true
                            ? atmosphere.accent(for: colorScheme)
                            : Theme.accent
                    )
            }

            if let snapshot = weather.snapshot {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(snapshot.temperatureText)
                        .font(.system(size: 54, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(Theme.primaryText)
                    Text("C")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.tertiaryText)
                }

                HStack(spacing: 12) {
                    if let high = snapshot.highC, let low = snapshot.lowC {
                        Label(
                            "\(high.formatted(.number.precision(.fractionLength(0))))° / \(low.formatted(.number.precision(.fractionLength(0))))°",
                            systemImage: "thermometer.medium"
                        )
                    }
                    if let probability = snapshot.precipitationProbability {
                        Label("降雨 \(probability)%", systemImage: "umbrella.fill")
                    }
                    if weather.isRefreshing {
                        ProgressView()
                            .controlSize(.mini)
                            .tint(Theme.secondaryText)
                    }
                }
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
            } else {
                stateContent
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    @ViewBuilder
    private var stateContent: some View {
        if weather.needsLocationPermission {
            Text("允许定位后，会在这里显示当前位置的实时天气。")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
        } else {
            switch weather.state {
            case .locating, .loading:
                HStack(spacing: 8) {
                    ProgressView().tint(Theme.accent)
                    Text("正在定位并获取天气…")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
            case .permissionDenied:
                Text("需要定位权限才能显示你所在城市的天气。")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            case .failed(let message):
                VStack(alignment: .leading, spacing: 8) {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(Theme.warning)
                    Button("重试") { weather.refresh() }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
            case .idle, .ready:
                Text("暂无天气数据")
                    .font(.caption)
                    .foregroundStyle(Theme.tertiaryText)
            }
        }
    }

    private var metricsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("体感与出行")
                    .font(.headline)
                    .foregroundStyle(Theme.primaryText)
                Spacer()
                if let updatedAt = weather.snapshot?.updatedAt {
                    Text("更新于 \(updatedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(Theme.tertiaryText)
                }
            }

            if let snapshot = weather.snapshot {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8)
                    ],
                    spacing: 8
                ) {
                    metric("体感", metricValue(snapshot.apparentTemperatureC, suffix: "°C"), icon: "thermometer.variable")
                    metric("湿度", snapshot.humidity.map { "\($0)%" } ?? "—", icon: "humidity.fill")
                    metric("风速", snapshot.windKPH.map { "\($0.formatted(.number.precision(.fractionLength(0)))) km/h" } ?? "—", icon: "wind")
                    metric("云量", snapshot.cloudCover.map { "\($0)%" } ?? "—", icon: "cloud.fill")
                }

                if weather.isStale {
                    Label("天气数据已超过 1 小时，正在等待刷新", systemImage: "clock.arrow.circlepath")
                        .font(.caption2)
                        .foregroundStyle(Theme.warning)
                }
            } else {
                Text("获取到天气后会显示体感温度、湿度、风速和云量。")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .card(padding: 14)
    }

    private var alertCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            Toggle(
                isOn: Binding(
                    get: { weather.alertsEnabled },
                    set: { weather.setWeatherAlerts($0) }
                )
            ) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("恶劣天气出行提醒")
                        .font(.headline)
                        .foregroundStyle(Theme.primaryText)
                    Text("有雨雪、大风或降雨概率较高时，每天最多提醒一次；22:00–07:00 不打扰。")
                        .font(.caption2)
                        .foregroundStyle(Theme.tertiaryText)
                }
            }
            .tint(Theme.accent)

            if weather.alertsEnabled && !weather.alertsAuthorized {
                HStack(spacing: 8) {
                    Image(systemName: "bell.slash.fill")
                        .foregroundStyle(Theme.warning)
                    Text("系统通知未开启")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                    Spacer(minLength: 4)
                    Button("开启") {
                        Task {
                            let granted = await weather.requestWeatherAlertPermission()
                            alertMessage = granted
                                ? "天气提醒已开启。"
                                : "没有获得通知权限，请到系统设置中允许「练途」通知。"
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)

                    Button("去设置") { openSystemSettings() }
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.tertiaryText)
                }
            }

            if let alertMessage {
                Text(alertMessage)
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("提醒会在 App 刷新天气时检查；如果没有后台常驻定位，关闭 App 后不会持续获取位置。")
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card(padding: 14)
    }

    private var locationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(weather.authorizationLabel, systemImage: weather.locationBlocked ? "location.slash.fill" : "location.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(weather.locationBlocked ? Theme.warning : Theme.secondaryText)
                Spacer()
                Button("刷新") { weather.refresh() }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .disabled(weather.isRefreshing)
            }

            switch weather.authorizationStatus {
            case .notDetermined:
                Button("允许定位，获取本地天气") {
                    weather.activate()
                }
                .buttonStyle(PrimaryButtonStyle())
            case .denied, .restricted:
                Button("去系统设置开启定位") {
                    openSystemSettings()
                }
                .buttonStyle(SecondaryButtonStyle())
            case .authorizedAlways, .authorizedWhenInUse:
                Text("定位只在你打开 App 时使用一次，用于查询当地天气。")
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
            @unknown default:
                EmptyView()
            }

            if let lastError = weather.lastError {
                Text(lastError)
                    .font(.caption2)
                    .foregroundStyle(Theme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card(padding: 14)
    }

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("位置与天气隐私", systemImage: "lock.shield.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
            Text("位置不会写入训练记录，也不会经过 FitAI 服务器。天气请求只把四舍五入到约 1 公里的坐标发送给 Open-Meteo；城市名由 iOS 地理编码服务反查。")
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
            Text("天气数据：Open-Meteo")
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
            Text("界面会跟随系统深浅色、清晨/白天/傍晚/夜间和天气自动调整；雨天使用克制的背景雨线，避免高成本材质拖慢滚动。")
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card(padding: 14)
    }

    private func metric(_ title: String, _ value: String, icon: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
                Text(value)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Spacer(minLength: 0)
        }
        .padding(9)
        .background(
            Theme.surfaceStrong,
            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
        )
    }

    private func metricValue(_ value: Double?, suffix: String) -> String {
        guard let value else { return "—" }
        return "\(value.formatted(.number.precision(.fractionLength(0))))\(suffix)"
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}
