import SwiftUI
import UIKit

// MARK: - Coach identity

/// The brand mark used across onboarding, the coach header and Today.
/// The supplied logo already includes its dark tile; clip it to an iOS-style
/// rounded square and keep a hairline edge so it stays defined in dark mode.
struct CoachMark: View {
    var size: CGFloat = 44

    var body: some View {
        let cornerRadius = size * 0.235
        Image("BrandLogo")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.ink.opacity(0.12), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Typewriter

/// Character-by-character reveal with a haptic tick every few characters.
/// Text is pre-measured with a hidden copy so lines never jump while typing.
struct TypewriterText: View {
    let text: String
    var charDelay: Duration = .milliseconds(28)
    var hapticEvery: Int = 3
    var onComplete: (() -> Void)? = nil

    @State private var count = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .topLeading) {
            Text(text)
                .opacity(0)
                .accessibilityHidden(true)
            Text(String(text.prefix(count)))
                .contentTransition(.opacity)
        }
        .accessibilityLabel(text)
        .task(id: text) {
            count = reduceMotion ? text.count : 0
            guard !reduceMotion else {
                onComplete?()
                return
            }

            for index in text.indices {
                if Task.isCancelled { return }
                try? await Task.sleep(for: charDelay)
                count = text.distance(from: text.startIndex, to: index) + 1

                if text[index] == "\n" {
                    try? await Task.sleep(for: .milliseconds(220))
                } else if "，。！？；：".contains(text[index]) {
                    try? await Task.sleep(for: .milliseconds(280))
                }
            }
            onComplete?()
        }
        .sensoryFeedback(.impact(weight: .light), trigger: count / max(1, hapticEvery))
        .onTapGesture {
            count = text.count
            onComplete?()
        }
    }
}

// MARK: - Week strip

/// Shared week strip for Today, Nutrition and Progress. It keeps the week in
/// the user's field of view without the weight of a full month calendar.
struct WeekStrip: View {
    @Binding var selectedDate: Date
    var markedKeys: Set<String> = []
    var completedKeys: Set<String> = []

    private let calendar = Calendar.current

    private var days: [Date] {
        let start = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: start)
        let mondayOffset = weekday == 1 ? -6 : 2 - weekday
        guard let monday = calendar.date(byAdding: .day, value: mondayOffset, to: start) else {
            return [start]
        }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(days, id: \.self) { day in
                let key = FitnessDate.key(day)
                let selected = calendar.isDate(day, inSameDayAs: selectedDate)
                let isToday = calendar.isDateInToday(day)
                Button {
                    Haptics.select()
                    selectedDate = day
                } label: {
                    VStack(spacing: 6) {
                        Text(weekdayLabel(day))
                            .font(AppType.micro)
                            .foregroundStyle(selected ? Theme.onPrimary : Theme.tertiaryText)
                        Text("\(calendar.component(.day, from: day))")
                            .font(.system(size: 17, weight: .bold, design: .monospaced))
                            .foregroundStyle(selected ? Theme.onPrimary : Theme.primaryText)
                        Circle()
                            .fill(
                                completedKeys.contains(key)
                                    ? Theme.lime
                                    : (markedKeys.contains(key) ? Theme.cobalt : Color.clear)
                            )
                            .frame(width: 5, height: 5)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(selected ? Theme.primary : Theme.paper)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                isToday && !selected ? Theme.cobalt : Theme.stroke,
                                lineWidth: isToday && !selected ? 1.5 : 1
                            )
                    }
                }
                .buttonStyle(SubtlePressStyle(scale: 0.96))
                .accessibilityLabel("\(weekdayLabel(day)) \(calendar.component(.day, from: day))")
            }
        }
    }

    private func weekdayLabel(_ date: Date) -> String {
        let weekday = calendar.component(.weekday, from: date)
        let index = (weekday + 5) % 7
        return ["一", "二", "三", "四", "五", "六", "日"][max(0, min(6, index))]
    }
}

// MARK: - Rings and badges

struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 8
    var color: Color = Theme.primary
    var track: Color = Theme.stroke

    var body: some View {
        ZStack {
            Circle()
                .stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(Motion.smooth, value: progress)
        }
        .accessibilityHidden(true)
    }
}

struct RecommendationBadge: View {
    enum Style: Equatable {
        case success
        case loading
        case warning
    }

    let text: String
    var style: Style = .success

    var body: some View {
        HStack(spacing: 5) {
            icon
            Text(text)
                .font(AppType.micro)
                .tracking(0.2)
        }
        .foregroundStyle(style == .warning ? Theme.onAccent : Theme.onPrimary)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            style == .warning ? Theme.ink : Theme.primary,
            in: Capsule(style: .continuous)
        )
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(
                    (style == .warning ? Theme.onAccent : Theme.ink)
                        .opacity(0.14),
                    lineWidth: 0.8
                )
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch style {
        case .success:
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 10, weight: .bold))
        case .loading:
            ProgressView()
                .controlSize(.mini)
                .tint(Theme.onPrimary)
        case .warning:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10, weight: .bold))
        }
    }
}

struct InkDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.stroke)
            .frame(height: 1)
    }
}

// MARK: - Editorial header

struct EditorialHeader: View {
    let eyebrow: String?
    let title: String
    let subtitle: String?

    init(eyebrow: String? = nil, title: String, subtitle: String? = nil) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let eyebrow {
                Text(eyebrow.uppercased())
                    .font(AppType.overline)
                    .tracking(1.6)
                    .foregroundStyle(Theme.cobalt)
            }
            Text(title)
                .font(AppType.display)
                .tracking(-0.9)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle)
                    .font(AppType.body)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Metrics and floating actions

struct EditorialMetric: View {
    let title: String
    let value: String
    var unit: String? = nil
    var accent: Color = Theme.primary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(AppType.numberSmall)
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let unit {
                    Text(unit)
                        .font(AppType.micro)
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                }
            }
            Text(title)
                .font(AppType.micro)
                .foregroundStyle(Theme.tertiaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }
}
