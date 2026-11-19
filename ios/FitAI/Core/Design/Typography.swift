import SwiftUI

/// Editorial type scale for a quiet, notes-like interface.
///
/// Display faces are still recognizable, but weights are lighter than the old
/// poster style. Numbers keep a monospaced face for logs; body copy uses the
/// system face for readability.
enum AppType {
    static let display = Font.system(size: 34, weight: .semibold, design: .default)
    static let editorial = Font.system(size: 40, weight: .semibold, design: .default)
    static let hero = Font.system(size: 26, weight: .semibold, design: .default)
    static let title = Font.system(size: 22, weight: .semibold, design: .default)
    static let headline = Font.system(size: 17, weight: .semibold, design: .default)
    static let body = Font.system(size: 16, weight: .regular, design: .default)
    static let callout = Font.system(size: 15, weight: .medium, design: .default)
    static let caption = Font.system(size: 13, weight: .regular, design: .default)
    static let micro = Font.system(size: 11, weight: .medium, design: .default)
    static let button = Font.system(size: 16, weight: .semibold, design: .default)
    static let buttonSecondary = Font.system(size: 15, weight: .medium, design: .default)
    static let chip = Font.system(size: 12, weight: .medium, design: .default)
    static let overline = Font.system(size: 12, weight: .semibold, design: .default)
    static let number = Font.system(size: 32, weight: .semibold, design: .monospaced)
    static let numberSmall = Font.system(size: 20, weight: .semibold, design: .monospaced)
}
