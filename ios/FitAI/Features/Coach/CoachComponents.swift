import SwiftUI

/// Shared coach panel surface.
///
/// Coach proposals, action confirmations and result cards all need the same
/// inset/border treatment. Keeping it here prevents each capability card from
/// growing its own slightly different surface.
struct CoachCard<Content: View>: View {
    var padding: CGFloat = 14
    var cornerRadius: CGFloat = 16
    var surface: Color = Theme.surface
    var border: Color = Color.white.opacity(0.10)
    var horizontalPadding: CGFloat = 16
    var verticalPadding: CGFloat = 8
    private let content: Content

    init(
        padding: CGFloat = 14,
        cornerRadius: CGFloat = 16,
        surface: Color = Theme.surface,
        border: Color = Color.white.opacity(0.10),
        horizontalPadding: CGFloat = 16,
        verticalPadding: CGFloat = 8,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.surface = surface
        self.border = border
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background {
                SoftSurface(
                    cornerRadius: cornerRadius,
                    tint: surface,
                    stroke: border
                )
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
    }
}

struct CoachEyebrow: View {
    let text: String
    var tint: Color = Theme.accent

    var body: some View {
        Text(text)
            .font(AppType.micro)
            .tracking(1.4)
            .foregroundStyle(tint)
    }
}

struct CoachStatusText: View {
    let text: String
    var tint: Color = Theme.warning

    var body: some View {
        Text(text)
            .font(AppType.micro)
            .tracking(0.8)
            .foregroundStyle(tint)
    }
}

struct CoachCardHeader: View {
    let eyebrow: String
    var status: String?

    var body: some View {
        HStack {
            CoachEyebrow(text: eyebrow)
            Spacer()
            if let status {
                CoachStatusText(text: status)
            }
        }
    }
}

/// Reusable transient/result banner: retry, undo and similar one-line actions.
struct CoachInlineBanner: View {
    let icon: String
    var tint: Color = Theme.accent
    let title: String
    let message: String
    var actionTitle: String?
    var isBusy: Bool = false
    var action: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
            }

            Spacer(minLength: 6)

            if let actionTitle, let action {
                Button(actionTitle) {
                    action()
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.accent)
                .disabled(isBusy)
                .buttonStyle(SubtlePressStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Theme.surfaceStrong)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.stroke)
                .frame(height: 1)
        }
    }
}

struct CoachLoadingLabel: View {
    let title: String
    let isLoading: Bool

    var body: some View {
        if isLoading {
            ProgressView()
                .tint(.black)
        } else {
            Text(title)
        }
    }
}

struct CoachQuickActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Theme.accent.opacity(0.09), in: Capsule())
                .overlay(Capsule().stroke(Theme.accent.opacity(0.18), lineWidth: 0.8))
        }
        .buttonStyle(SubtlePressStyle(scale: 0.95))
    }
}

/// Shared bubble chrome so user/assistant/safety states stay consistent.
struct CoachChatBubble<Content: View>: View {
    let isUser: Bool
    let isSafety: Bool
    private let content: Content

    init(isUser: Bool, isSafety: Bool, @ViewBuilder content: () -> Content) {
        self.isUser = isUser
        self.isSafety = isSafety
        self.content = content()
    }

    var body: some View {
        HStack {
            if isUser {
                Spacer(minLength: 40)
            }

            content
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(background)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            isSafety ? Theme.warning.opacity(0.5) : Color.clear,
                            lineWidth: 1
                        )
                )

            if !isUser {
                Spacer(minLength: 40)
            }
        }
    }

    private var background: Color {
        if isUser {
            return Theme.accent
        }
        return isSafety ? Theme.warning.opacity(0.12) : Theme.surface
    }
}
