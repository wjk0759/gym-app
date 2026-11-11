import SwiftUI

/// The "demo" half of the workout pager. The 1:1 native-aspect clip owns the
/// page; cues and the coach tip sit underneath and scroll only when needed.
struct WorkoutSessionDemoPage: View {
    let exercise: PlanExercise
    let medias: [ExerciseMediaItem]
    let isPlaying: Bool
    let lastSet: SetLog?
    @Binding var showInstructions: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if medias.isEmpty {
                    demoPlaceholder
                } else {
                    ExerciseAnimationCard(
                        exercise: exercise,
                        medias: medias,
                        isPlaying: isPlaying
                    )
                }

                mediaCaption

                if let instructions = exercise.exercise?.instructions,
                   !instructions.isEmpty {
                    instructionsCard(instructions)
                }

                WorkoutTrainingTipCard(
                    exercise: exercise,
                    lastSet: lastSet
                )
            }
            .appPagePadding()
            .padding(.top, 10)
            .padding(.bottom, 18)
            .appReadableContent()
        }
        .scrollIndicators(.hidden)
        .id(exercise.id)
    }

    private var mediaCaption: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Theme.primary)
                .frame(width: 5, height: 5)

            Text("自动循环 · 无控制条 · 不可点")

            Spacer(minLength: 4)

            Text("切走自动暂停")
        }
        .font(.system(size: 9, weight: .medium))
        .foregroundStyle(Theme.tertiaryText)
        .padding(.horizontal, 2)
    }

    private func instructionsCard(_ instructions: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                Haptics.tap()
                withAnimation(Motion.quick) {
                    showInstructions.toggle()
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 11, weight: .semibold))

                    Text("动作要点")
                        .font(.system(size: 10.5, weight: .bold))

                    Spacer(minLength: 4)

                    Image(systemName: showInstructions ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.tertiaryText)
                }
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 12)
                .frame(height: 40)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showInstructions {
                Text(instructions)
                    .font(AppType.callout)
                    .foregroundStyle(Theme.secondaryText)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    .transition(
                        .opacity.combined(with: .move(edge: .top))
                    )
            }
        }
        .background(
            Theme.paper,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }

    private var demoPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(Theme.tertiaryText.opacity(0.5))

            Text("动作演示准备中")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(
            Theme.ink.opacity(0.035),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }
}
