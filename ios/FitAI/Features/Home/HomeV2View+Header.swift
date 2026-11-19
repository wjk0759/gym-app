import SwiftUI

extension HomeV2View {
    func weatherBanner(_ kind: WeatherAlertKind) -> some View {
        HStack(spacing: 9) {
            Image(systemName: kind == .thunder ? "cloud.bolt.rain.fill" : "cloud.rain.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.secondaryText)
            Text(advisoryTitle(kind))
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    func advisoryTitle(_ kind: WeatherAlertKind) -> String {
        switch kind {
        case .rain: return "今天有雨"
        case .snow: return "今天有雪"
        case .thunder: return "今天有雷雨"
        case .rainLikely: return "今天可能下雨"
        case .typhoon: return "今天风力很大"
        }
    }
}
