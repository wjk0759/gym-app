import SwiftUI

extension HomeV2View {
    var topBar: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("今天")
                    .font(AppType.display)
                    .tracking(-0.6)
                    .foregroundStyle(Theme.ink)
                Text(Date().formatted(.dateTime.month().day().weekday(.wide)))
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
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
    }

    func weatherBanner(_ kind: WeatherAlertKind) -> some View {
        HStack(spacing: 9) {
            Image(systemName: kind == .thunder ? "cloud.bolt.rain.fill" : "cloud.rain.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.cobalt)
            Text(advisoryTitle(kind))
                .font(AppType.caption.weight(.semibold))
                .foregroundStyle(Theme.ink)
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
        case .rain: return "今天有雨"
        case .snow: return "雨雪天气"
        case .thunder: return "今天有雷雨"
        case .rainLikely: return "今天可能下雨"
        case .typhoon: return "风力很大"
        }
    }
}
