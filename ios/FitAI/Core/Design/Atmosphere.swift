import Foundation
import SwiftUI

enum WeatherPhase: String, CaseIterable, Sendable, Equatable {
    case dawn
    case day
    case evening
    case night

    var label: String {
        switch self {
        case .dawn: return "清晨"
        case .day: return "白天"
        case .evening: return "傍晚"
        case .night: return "夜间"
        }
    }
}

struct WeatherAtmosphere: Equatable, Sendable {
    var kind: WeatherKind
    var phase: WeatherPhase
    var isDaylight: Bool
    var precipitationMM: Double
    var rainProbability: Int?

    static let neutral = WeatherAtmosphere(
        kind: .clear,
        phase: .day,
        isDaylight: true,
        precipitationMM: 0,
        rainProbability: nil
    )

    var isPrecipitation: Bool {
        kind.isWet || precipitationMM > 0
    }

    var isSnow: Bool {
        kind.isSnow
    }

    var precipitationIntensity: Double {
        guard isPrecipitation else { return 0 }
        var value = min(1, max(0.28, precipitationMM / 6))
        if kind.isStorm {
            value = max(value, 0.85)
        }
        if kind.isSnow {
            value = max(value, 0.48)
        }
        return value
    }

    func accent(for scheme: ColorScheme) -> Color {
        let light = scheme == .light

        if isSnow {
            return light
                ? Color(red: 0.18, green: 0.47, blue: 0.68)
                : Color(red: 0.48, green: 0.80, blue: 0.96)
        }
        if isPrecipitation {
            return light
                ? Color(red: 0.10, green: 0.42, blue: 0.66)
                : Color(red: 0.36, green: 0.72, blue: 0.94)
        }
        switch phase {
        case .dawn:
            return light
                ? Color(red: 0.78, green: 0.32, blue: 0.16)
                : Color(red: 0.97, green: 0.62, blue: 0.45)
        case .day:
            return Theme.accent
        case .evening:
            return light
                ? Color(red: 0.78, green: 0.38, blue: 0.08)
                : Color(red: 0.99, green: 0.67, blue: 0.35)
        case .night:
            return light
                ? Color(red: 0.22, green: 0.36, blue: 0.78)
                : Color(red: 0.45, green: 0.62, blue: 0.98)
        }
    }

    func backgroundColors(for scheme: ColorScheme) -> [Color] {
        let light = scheme == .light

        if isPrecipitation {
            if isSnow {
                return light
                    ? [
                        Color(red: 0.955, green: 0.975, blue: 0.988),
                        Color(red: 0.900, green: 0.940, blue: 0.960)
                    ]
                    : [
                        Color(red: 0.045, green: 0.065, blue: 0.085),
                        Color(red: 0.028, green: 0.042, blue: 0.060)
                    ]
            }
            return light
                ? [
                    Color(red: 0.915, green: 0.945, blue: 0.962),
                    Color(red: 0.855, green: 0.910, blue: 0.932)
                ]
                : [
                    Color(red: 0.025, green: 0.060, blue: 0.078),
                    Color(red: 0.018, green: 0.034, blue: 0.050)
                ]
        }

        if kind == .overcast || kind == .fog {
            return light
                ? [
                    Color(red: 0.925, green: 0.945, blue: 0.950),
                    Color(red: 0.875, green: 0.910, blue: 0.925)
                ]
                : [
                    Color(red: 0.045, green: 0.055, blue: 0.065),
                    Color(red: 0.025, green: 0.035, blue: 0.045)
                ]
        }

        switch phase {
        case .dawn:
            return light
                ? [
                    Color(red: 1.000, green: 0.955, blue: 0.940),
                    Color(red: 0.965, green: 0.925, blue: 0.945)
                ]
                : [
                    Color(red: 0.075, green: 0.045, blue: 0.070),
                    Color(red: 0.045, green: 0.035, blue: 0.060)
                ]
        case .day:
            return light
                ? [
                    Color(red: 0.965, green: 0.985, blue: 0.960),
                    Color(red: 0.915, green: 0.950, blue: 0.945)
                ]
                : [
                    Color(red: 0.035, green: 0.055, blue: 0.055),
                    Color(red: 0.025, green: 0.038, blue: 0.050)
                ]
        case .evening:
            return light
                ? [
                    Color(red: 0.985, green: 0.935, blue: 0.920),
                    Color(red: 0.930, green: 0.910, blue: 0.955)
                ]
                : [
                    Color(red: 0.075, green: 0.045, blue: 0.045),
                    Color(red: 0.035, green: 0.028, blue: 0.055)
                ]
        case .night:
            return light
                ? [
                    Color(red: 0.930, green: 0.945, blue: 0.975),
                    Color(red: 0.900, green: 0.920, blue: 0.955)
                ]
                : [
                    Color(red: 0.018, green: 0.025, blue: 0.045),
                    Color(red: 0.012, green: 0.016, blue: 0.030)
                ]
        }
    }

    func glowColor(for scheme: ColorScheme) -> Color {
        if isPrecipitation {
            return Color(red: 0.34, green: 0.72, blue: 0.96).opacity(scheme == .dark ? 0.16 : 0.12)
        }
        if kind == .overcast || kind == .fog {
            return Color(red: 0.42, green: 0.62, blue: 0.78).opacity(scheme == .dark ? 0.08 : 0.06)
        }
        switch phase {
        case .dawn:
            return Color(red: 1.0, green: 0.56, blue: 0.36).opacity(scheme == .dark ? 0.11 : 0.09)
        case .day:
            return Theme.accent.opacity(scheme == .dark ? 0.08 : 0.08)
        case .evening:
            return Color(red: 1.0, green: 0.50, blue: 0.25).opacity(scheme == .dark ? 0.13 : 0.09)
        case .night:
            return Color(red: 0.36, green: 0.52, blue: 1.0).opacity(scheme == .dark ? 0.11 : 0.08)
        }
    }

    static func phase(for date: Date, timeZone: TimeZone = .current) -> WeatherPhase {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<8:
            return .dawn
        case 8..<17:
            return .day
        case 17..<20:
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
            isDaylight: snapshot?.isDay ?? (8..<18).contains(hour),
            precipitationMM: snapshot?.precipitationMM ?? 0,
            rainProbability: snapshot?.precipitationProbability
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
