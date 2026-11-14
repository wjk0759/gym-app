import SwiftUI

/// Reusable inline Pro card used by locked feature pages.
struct ProUpsellCard: View {
    let feature: ProFeature
    var action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: feature.icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.onPrimary)
                    .frame(width: 38, height: 38)
                    .background(Theme.primary, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(feature.title)
                        .font(AppType.headline)
                        .foregroundStyle(Theme.ink)
                    Text(feature.subtitle)
                        .font(AppType.caption)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button(action: action) {
                HStack(spacing: 7) {
                    Text("解锁 Pro")
                    Image(systemName: "arrow.right")
                        .font(AppType.caption.weight(.bold))
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(16)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }
}

/// Gradient lock layer for a feature that has used its free allowance.
struct ProLockedOverlay: View {
    let feature: ProFeature
    var action: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Theme.background.opacity(0.02),
                    Theme.background.opacity(0.92),
                    Theme.background
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.onPrimary)
                    .frame(width: 48, height: 48)
                    .background(Theme.primary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text(feature.title)
                    .font(AppType.headline)
                    .foregroundStyle(Theme.ink)

                Text(feature.subtitle)
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 22)

                Button(action: action) {
                    Text("解锁 Pro")
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(maxWidth: 260)
            }
            .padding(22)
        }
        .accessibilityElement(children: .contain)
    }
}

/// Shared sheet entry point. The detailed products/restore flow stays in
/// PaywallView; this wrapper gives every feature the same presentation.
struct ProPaywallSheet: View {
    let feature: ProFeature

    var body: some View {
        PaywallView()
            .onAppear {
                Telemetry.shared.track(
                    "paywall_shown",
                    properties: ["feature": feature.rawValue]
                )
            }
    }
}
