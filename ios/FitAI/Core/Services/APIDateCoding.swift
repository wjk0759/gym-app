import Foundation

/// Shared API date parsing/formatting.
///
/// The backend accepts/returns several date shapes. Keeping the fallbacks in
/// one place prevents each endpoint (and each new service) from growing its own
/// formatter stack.
enum APIDateCoding {
    static let iso8601WithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// Used for profile birth dates and goal dates (server expects local date).
    static let dateOnlyLocal: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// Used for query parameters that the server interprets as UTC dates.
    static let dateOnlyUTC: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let naiveDateFormatters: [DateFormatter] = {
        ["yyyy-MM-dd'T'HH:mm:ss.SSSSSS", "yyyy-MM-dd'T'HH:mm:ss.SSS", "yyyy-MM-dd'T'HH:mm:ss"].map { format in
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
            formatter.dateFormat = format
            return formatter
        }
    }()

    static func date(from text: String) -> Date? {
        if let date = iso8601WithFractionalSeconds.date(from: text) {
            return date
        }
        if let date = iso8601.date(from: text) {
            return date
        }
        for formatter in naiveDateFormatters {
            if let date = formatter.date(from: text) {
                return date
            }
        }
        return nil
    }

    static func birthDateString(age: Int, now: Date = Date()) -> String {
        let date = Calendar.current.date(byAdding: .year, value: -age, to: now) ?? now
        return dateOnlyLocal.string(from: date)
    }
}
