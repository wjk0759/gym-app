import SwiftUI

extension HomeV2View {
    // MARK: - Header

    var topBar: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(timeGreeting)
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
                Text(store.profile.nickname.isEmpty ? "今天" : store.profile.nickname)
                    .font(AppType.title)
                    .tracking(-0.4)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            WeatherBadgeView()
            Button {
                store.selectedTab = 2
            } label: {
                CoachMark(size: 38)
            }
            .buttonStyle(SubtlePressStyle(scale: 0.94))
            .accessibilityLabel("找教练")
        }
        .padding(.top, 4)
    }

    var timeGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "早上好，今天只做一件事"
        case 12..<18: return "下午好，先把今天练明白"
        default: return "晚上好，练完就好好恢复"
        }
    }

    func weatherBanner(_ kind: WeatherAlertKind) -> some View {
        HStack(spacing: 9) {
            Image(systemName: kind == .thunder ? "cloud.bolt.rain.fill" : "cloud.rain.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.cobalt)
            VStack(alignment: .leading, spacing: 2) {
                Text(advisoryTitle(kind))
                    .font(AppType.caption.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text(advisoryDetail(kind))
                    .font(AppType.micro)
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(Theme.cobalt.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.cobalt.opacity(0.18), lineWidth: 1)
        }
    }

    func advisoryTitle(_ kind: WeatherAlertKind) -> String {
        switch kind {
        case .rain: return "今天有雨，出门带伞"
        case .snow: return "雨雪天气，慢一点走"
        case .thunder: return "雷雨天气，减少户外停留"
        case .rainLikely: return "今天可能下雨"
        case .typhoon: return "风力很大，减少外出"
        }
    }

    func advisoryDetail(_ kind: WeatherAlertKind) -> String {
        switch kind {
        case .rain: return "路面湿滑，训练前后注意保暖；如果通勤绕路，优先保证安全。"
        case .snow: return "路面可能结冰，避开急转和湿滑台阶，热身多花 3 分钟。"
        case .thunder: return "尽量避开空旷地带和积水路段，必要时把训练改到室内。"
        case .rainLikely: return "降雨概率较高，包里备好雨具，出门前再看一眼天气。"
        case .typhoon: return "远离广告牌、树木和临时搭建物，训练改到室内，别在风口停留。"
        }
    }
}
