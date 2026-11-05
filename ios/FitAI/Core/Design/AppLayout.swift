import SwiftUI

/// Shared responsive layout tokens.
///
/// Keep semantic control sizes inside components, but page gutters, readable
/// widths and section spacing must come from this file so compact and regular
/// size classes stay consistent.
enum AppLayout {
    static let readableMaxWidth: CGFloat = 720
    /// Devices narrower than this use the compact form rhythm. Width is stable
    /// while the keyboard animates, unlike window height.
    static let compactWidthThreshold: CGFloat = 390
    static let compactPadding: CGFloat = 18
    static let regularPadding: CGFloat = 28
    static let sectionSpacing: CGFloat = 18
    static let actionBarSpacing: CGFloat = 12
    /// Standard gap between the navigation bar or safe area and page content.
    static let pageTopPadding: CGFloat = 16

    /// Card rhythm. More generous than control spacing so content breathes.
    static let cardPadding: CGFloat = 20
    static let cardCornerRadius: CGFloat = 22
    static let heroCornerRadius: CGFloat = 28
    static let controlCornerRadius: CGFloat = 14
}

private struct AppPagePadding: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        content.padding(
            .horizontal,
            horizontalSizeClass == .compact
                ? AppLayout.compactPadding
                : AppLayout.regularPadding
        )
    }
}

private struct AppPageTopPadding: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(.top, AppLayout.pageTopPadding)
    }
}

private struct AppReadableContent: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: AppLayout.readableMaxWidth)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    /// Responsive page gutter for compact and regular widths.
    func appPagePadding() -> some View {
        modifier(AppPagePadding())
    }

    /// Consistent breathing room below navigation bars and safe areas.
    func appPageTopPadding() -> some View {
        modifier(AppPageTopPadding())
    }

    /// Centers page content at a readable width on iPad and landscape.
    func appReadableContent() -> some View {
        modifier(AppReadableContent())
    }
}
