import SwiftUI

/// Lightweight, non-blocking feedback for operations that used to write to a
/// dead `toast` property. It stays above the tab content and never blocks taps.
struct ToastBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.cobalt)
                .accessibilityHidden(true)

            Text(message)
                .font(AppType.caption.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(3)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.paper)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.ink.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: Theme.ink.opacity(0.10), radius: 0, x: 3, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}
