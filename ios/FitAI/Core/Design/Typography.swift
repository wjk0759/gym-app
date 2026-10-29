import SwiftUI

/// Type scale for the app. Rounded system faces keep the product approachable,
/// while explicit sizes preserve the compact fitness-dashboard density.
enum AppType {
    static let display = Font.system(size: 34, weight: .bold, design: .rounded)
    static let hero = Font.system(size: 26, weight: .bold, design: .rounded)
    static let title = Font.system(size: 22, weight: .bold, design: .rounded)
    static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let body = Font.system(size: 15, weight: .regular, design: .rounded)
    static let callout = Font.system(size: 14, weight: .medium, design: .rounded)
    static let caption = Font.system(size: 12, weight: .medium, design: .rounded)
    static let micro = Font.system(size: 10, weight: .semibold, design: .rounded)
    static let button = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let buttonSecondary = Font.system(size: 15, weight: .semibold, design: .rounded)
    static let chip = Font.system(size: 13, weight: .medium, design: .rounded)
}
