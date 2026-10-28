import Foundation

/// WMO 天气代码的本地映射。天气源使用 Open-Meteo，不依赖后端密钥。
enum WeatherKind: String, Codable, CaseIterable, Sendable, Equatable {
    case clear
    case mostlyClear
    case partlyCloudy
    case overcast
    case fog
    case drizzle
    case rain
    case heavyRain
    case freezingRain
    case snow
    case heavySnow
    case thunderstorm
    case unknown

    init(code: Int) {
        switch code {
        case 0:
            self = .clear
        case 1:
            self = .mostlyClear
        case 2:
            self = .partlyCloudy
        case 3:
            self = .overcast
        case 45, 48:
            self = .fog
        case 51, 53, 55, 56, 57:
            self = .drizzle
        case 61, 63:
            self = .rain
        case 65:
            self = .heavyRain
        case 66, 67:
            self = .freezingRain
        case 71, 73, 75, 77:
            self = .snow
        case 80, 81:
            self = .rain
        case 82:
            self = .heavyRain
        case 85:
            self = .snow
        case 86:
            self = .heavySnow
        case 95, 96, 99:
            self = .thunderstorm
        default:
            self = .unknown
        }
    }

    var label: String {
        switch self {
        case .clear: return "晴"
        case .mostlyClear: return "晴间多云"
        case .partlyCloudy: return "多云"
        case .overcast: return "阴"
        case .fog: return "有雾"
        case .drizzle: return "毛毛雨"
        case .rain: return "有雨"
        case .heavyRain: return "大雨"
        case .freezingRain: return "冻雨"
        case .snow: return "有雪"
        case .heavySnow: return "大雪"
        case .thunderstorm: return "雷雨"
        case .unknown: return "天气未知"
        }
    }

    var isRain: Bool {
        switch self {
        case .drizzle, .rain, .heavyRain, .freezingRain, .thunderstorm:
            return true
        default:
            return false
        }
    }

    var isSnow: Bool {
        self == .snow || self == .heavySnow
    }

    var isWet: Bool {
        isRain || isSnow
    }

    var isStorm: Bool {
        self == .thunderstorm
    }

    func symbolName(isDay: Bool) -> String {
        switch self {
        case .clear, .mostlyClear:
            return isDay ? "sun.max.fill" : "moon.stars.fill"
        case .partlyCloudy:
            return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case .overcast:
            return "cloud.fill"
        case .fog:
            return "cloud.fog.fill"
        case .drizzle:
            return "cloud.drizzle.fill"
        case .rain:
            return "cloud.rain.fill"
        case .heavyRain, .freezingRain:
            return "cloud.heavyrain.fill"
        case .snow, .heavySnow:
            return "cloud.snow.fill"
        case .thunderstorm:
            return "cloud.bolt.rain.fill"
        case .unknown:
            return "cloud.fill"
        }
    }
}

enum WeatherAlertKind: String, Codable, Sendable, Equatable {
    case rain
    case snow
    case thunder
    case rainLikely
    case typhoon

    func title(for snapshot: WeatherSnapshot) -> String {
        switch self {
        case .rain:
            return snapshot.kind == .heavyRain ? "大雨出行提醒" : "下雨出行提醒"
        case .snow:
            return "雨雪出行提醒"
        case .thunder:
            return "雷雨出行提醒"
        case .rainLikely:
            return "今天可能下雨"
        case .typhoon:
            return "台风 / 大风出行提醒"
        }
    }

    func body(for snapshot: WeatherSnapshot) -> String {
        let place = snapshot.placeDisplayName
        let temperature = snapshot.temperatureC.formatted(.number.precision(.fractionLength(0)))
        switch self {
        case .rain:
            return "\(place)\(snapshot.conditionLabel)，\(temperature)°C。出门带伞，路面湿滑，训练前后注意保暖。"
        case .snow:
            return "\(place)正在下雪，\(temperature)°C。路面可能结冰，慢走、少急转，注意保暖。"
        case .thunder:
            return "\(place)有雷雨，\(temperature)°C。尽量减少户外停留，避开空旷地带和积水路段。"
        case .rainLikely:
            let probability = snapshot.precipitationProbability ?? 0
            return "\(place)今天降雨概率约 \(probability)%。出门带伞，通勤和训练路上注意湿滑。"
        case .typhoon:
            let wind = (snapshot.windKPH ?? 0).formatted(.number.precision(.fractionLength(0)))
            return "\(place)\(snapshot.conditionLabel)，风力约 \(wind) km/h，\(temperature)°C。尽量避开广告牌、树木和临时搭建物，减少不必要外出。"
        }
    }
}

struct WeatherSnapshot: Codable, Equatable, Sendable {
    var temperatureC: Double
    var apparentTemperatureC: Double?
    var humidity: Int?
    var windKPH: Double?
    var weatherCode: Int
    var isDay: Bool
    var precipitationMM: Double
    var rainMM: Double
    var showersMM: Double
    var snowfallCM: Double
    var cloudCover: Int?
    var highC: Double?
    var lowC: Double?
    var precipitationProbability: Int?
    var timezone: String?
    var placeName: String?
    var latitude: Double
    var longitude: Double
    var updatedAt: Date

    var kind: WeatherKind {
        WeatherKind(code: weatherCode)
    }

    var conditionLabel: String {
        switch weatherCode {
        case 61: return "小雨"
        case 63: return "中雨"
        case 65: return "大雨"
        case 66, 67: return "冻雨"
        case 71: return "小雪"
        case 73: return "中雪"
        case 75: return "大雪"
        case 77: return "米雪"
        case 80: return "小阵雨"
        case 81: return "中阵雨"
        case 82: return "强阵雨"
        case 85: return "小阵雪"
        case 86: return "强阵雪"
        case 95, 96, 99: return "雷雨"
        default: return kind.label
        }
    }

    var placeDisplayName: String {
        guard let placeName, !placeName.isEmpty else { return "当前位置" }
        return placeName
    }

    var symbolName: String {
        kind.symbolName(isDay: isDay)
    }

    var isWet: Bool {
        kind.isWet || precipitationMM > 0 || rainMM > 0 || showersMM > 0 || snowfallCM > 0
    }

    var isSnowing: Bool {
        kind.isSnow || snowfallCM > 0
    }

    var alertKind: WeatherAlertKind? {
        let wind = windKPH ?? 0
        if wind >= 88 || (wind >= 62 && isWet) {
            return .typhoon
        }
        if kind.isStorm {
            return .thunder
        }
        if kind.isSnow || snowfallCM > 0 {
            return .snow
        }
        if kind.isRain || precipitationMM > 0 || rainMM > 0 || showersMM > 0 {
            return .rain
        }
        if let precipitationProbability, precipitationProbability >= 60 {
            return .rainLikely
        }
        return nil
    }

    var dayKey: String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: updatedAt)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    var temperatureText: String {
        "\(temperatureC.formatted(.number.precision(.fractionLength(0))))°"
    }
}
