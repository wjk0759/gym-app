import ActivityKit
import SwiftUI
import WidgetKit

struct RestTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerAttributes.self) { context in
            lockScreen(context)
                .activityBackgroundTint(Color(red: 0.08, green: 0.08, blue: 0.10))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(workoutURL(context))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("休息", systemImage: "timer")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(context)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.exerciseName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        if !context.state.setLabel.isEmpty {
                            Text(context.state.setLabel)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.65))
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(
                        timerInterval: context.state.startDate...context.state.endDate,
                        countsDown: true
                    )
                    .tint(.orange)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(.orange)
            } compactTrailing: {
                countdown(context)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .frame(width: 48)
            } minimal: {
                countdown(context)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
            }
            .keylineTint(.orange)
        }
    }

    private func lockScreen(
        _ context: ActivityViewContext<RestTimerAttributes>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("休息中")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                    Text(context.state.exerciseName)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                countdown(context)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }

            ProgressView(
                timerInterval: context.state.startDate...context.state.endDate,
                countsDown: true
            )
            .tint(.orange)
        }
        .padding(16)
    }

    private func countdown(
        _ context: ActivityViewContext<RestTimerAttributes>
    ) -> Text {
        Text(
            timerInterval: context.state.startDate...context.state.endDate,
            countsDown: true
        )
    }

    private func workoutURL(
        _ context: ActivityViewContext<RestTimerAttributes>
    ) -> URL? {
        URL(string: "fitai://workout?day=\(context.attributes.sessionID)")
    }
}
