import Foundation

enum AuthInput {
    /// Accepts `13800138000`, `+86 138 0013 8000` and `0086...`.
    static func phoneDigits(_ value: String) -> String {
        var digits = String(value.filter(\.isNumber))
        if digits.hasPrefix("0086") {
            digits.removeFirst(4)
        } else if digits.count > 11, digits.hasPrefix("86") {
            digits.removeFirst(2)
        }
        return String(digits.prefix(11))
    }

    static func codeDigits(_ value: String) -> String {
        String(value.filter(\.isNumber).prefix(6))
    }

    static func isValidPhone(_ value: String) -> Bool {
        let digits = phoneDigits(value)
        guard digits.count == 11, digits.first == "1" else { return false }
        let secondIndex = digits.index(digits.startIndex, offsetBy: 1)
        return "3456789".contains(digits[secondIndex])
    }

    static func isValidUsername(_ value: String) -> Bool {
        let allowed = CharacterSet.alphanumerics
            .union(CharacterSet(charactersIn: "_"))
        return (4...32).contains(value.count)
            && value.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}
