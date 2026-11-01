import Foundation
import SwiftUI

enum WeatherPhase: String, CaseIterable, Sendable, Equatable {
    case morning
    case noon
    case evening
    case night

    var label: String {
        switch self {
        case .morning: return "早上"
        case .noon: return "中午"
        case .evening: return "傍晚"
        case .night: return "晚上"
        }
    }
}

struct WeatherAtmosphere: Equatable, Sendable {
    var kind: WeatherKind
    var phase: WeatherPhase
    var isDaylight: Bool
    var precipitationMM: Double
    var rainProbability: Int?
    var windKPH: Double?
    var cloudCover: Int?

    static let neutral = WeatherAtmosphere(
        kind: .clear,
        phase: .noon,
        isDaylight: true,
        precipitationMM: 0,
        rainProbability: nil,
        windKPH: nil,
        cloudCover: nil
    )

    var isPrecipitation: Bool {
        kind.isWet || precipitationMM > 0
    }

    var isSnow: Bool {
        kind.isSnow
    }

    var windIntensity: Double {
        let speed = windKPH ?? 0
        return min(1, max(0, (speed - 10) / 80))
    }

    var isWindy: Bool {
        (windKPH ?? 0) >= 30
    }

    var isTyphoon: Bool {
        let speed = windKPH ?? 0
        return speed >= 88 || (speed >= 62 && isPrecipitation)
    }

    func accent(for scheme: ColorScheme) -> Color {
        // Weather changes text and iconography, not the four-color palette.
        Theme.primary
    }

    func glowColor(for scheme: ColorScheme) -> Color {
        Theme.ink.opacity(scheme == .dark ? 0.06 : 0.025)
    }

    static func phase(for date: Date, timeZone: TimeZone = .current) -> WeatherPhase {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<11:
            return .morning
        case 11..<16:
            return .noon
        case 16..<19:
            return .evening
        default:
            return .night
        }
    }

    static func make(snapshot: WeatherSnapshot?, date: Date = Date()) -> WeatherAtmosphere {
        let timeZone = snapshot?.timezone.flatMap { TimeZone(identifier: $0) } ?? .current
        let phase = phase(for: date, timeZone: timeZone)
        let kind = snapshot?.kind ?? .clear
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let hour = calendar.component(.hour, from: date)
        return WeatherAtmosphere(
            kind: kind,
            phase: phase,
            isDaylight: snapshot?.isDay ?? (6..<19).contains(hour),
            precipitationMM: snapshot?.precipitationMM ?? 0,
            rainProbability: snapshot?.precipitationProbability,
            windKPH: snapshot?.windKPH,
            cloudCover: snapshot?.cloudCover
        )
    }
}

private struct WeatherAtmosphereKey: EnvironmentKey {
    static let defaultValue = WeatherAtmosphere.neutral
}

extension EnvironmentValues {
    var weatherAtmosphere: WeatherAtmosphere {
        get { self[WeatherAtmosphereKey.self] }
        set { self[WeatherAtmosphereKey.self] = newValue }
    }
}
