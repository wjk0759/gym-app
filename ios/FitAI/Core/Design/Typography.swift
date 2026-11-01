import SwiftUI

/// Editorial type scale: heavy, tight display faces for coaching moments and
/// plain system text for forms. Numbers use a monospaced face so data reads
/// like a training log rather than a dashboard.
enum AppType {
    static let display = Font.system(size: 38, weight: .black, design: .default)
    static let editorial = Font.system(size: 44, weight: .black, design: .default)
    static let hero = Font.system(size: 30, weight: .black, design: .default)
    static let title = Font.system(size: 24, weight: .bold, design: .default)
    static let headline = Font.system(size: 18, weight: .semibold, design: .default)
    static let body = Font.system(size: 15, weight: .regular, design: .default)
    static let callout = Font.system(size: 14, weight: .medium, design: .default)
    static let caption = Font.system(size: 12, weight: .medium, design: .default)
    static let micro = Font.system(size: 10, weight: .bold, design: .default)
    static let button = Font.system(size: 16, weight: .bold, design: .default)
    static let buttonSecondary = Font.system(size: 15, weight: .semibold, design: .default)
    static let chip = Font.system(size: 12, weight: .semibold, design: .default)
    static let overline = Font.system(size: 11, weight: .bold, design: .default)
    static let number = Font.system(size: 36, weight: .black, design: .monospaced)
    static let numberSmall = Font.system(size: 22, weight: .bold, design: .monospaced)
}
