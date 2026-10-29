import SwiftUI

/// Shared responsive layout tokens.
///
/// Keep semantic control sizes inside components, but page gutters, readable
/// widths and section spacing must come from this file so compact and regular
/// size classes stay consistent.
enum AppLayout {
    static let readableMaxWidth: CGFloat = 720
    static let compactPadding: CGFloat = 16
    static let regularPadding: CGFloat = 24
    static let sectionSpacing: CGFloat = 16
    static let actionBarSpacing: CGFloat = 10

    /// Native grouped-card rhythm.
    static let cardPadding: CGFloat = 16
    static let cardCornerRadius: CGFloat = 16
    static let heroCornerRadius: CGFloat = 20
    static let controlCornerRadius: CGFloat = 10
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

    /// Centers page content at a readable width on iPad and landscape.
    func appReadableContent() -> some View {
        modifier(AppReadableContent())
    }
}
