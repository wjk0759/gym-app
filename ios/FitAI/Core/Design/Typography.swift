import SwiftUI

/// Semantic text styles so Dynamic Type, accessibility sizes and the system
/// font all work automatically.
enum AppType {
    static let display = Font.largeTitle.weight(.bold)
    static let hero = Font.title.weight(.bold)
    static let title = Font.title2.weight(.bold)
    static let headline = Font.headline.weight(.semibold)
    static let body = Font.body
    static let callout = Font.callout
    static let caption = Font.caption
    static let micro = Font.caption2.weight(.semibold)
    static let button = Font.body.weight(.semibold)
    static let buttonSecondary = Font.callout.weight(.semibold)
    static let chip = Font.callout
}
