import SwiftUI

/// Lightweight, non-blocking feedback for operations that used to write to a
/// dead `toast` property. It stays above the tab content and never blocks taps.
struct ToastBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "info.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)

            Text(message)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(3)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            GlassSurface(cornerRadius: 16, material: true)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 0.8)
        }
        .shadow(color: Theme.shadow.opacity(0.28), radius: 12, y: 5)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}
