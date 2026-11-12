import SwiftUI

extension CoachOnboardingView {
    // MARK: - Welcome

    var welcome: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 40)

            CoachMark(size: 76)
                .padding(.bottom, 28)

            VStack(spacing: 16) {
                if welcomePhase == 0 {
                    TypewriterText(
                        text: "您好，\n我是叫练",
                        charDelay: .milliseconds(90),
                        hapticEvery: 5
                    ) {
                        guard welcomePhase == 0 else { return }
                        withAnimation(Motion.smooth) {
                            welcomePhase = 1
                        }
                    }
                    .font(AppType.editorial)
                    .tracking(-1.4)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.ink)
                } else {
                    TypewriterText(
                        text: "告诉我你的情况，\n我帮你生成起点报告",
                        charDelay: .milliseconds(70),
                        hapticEvery: 7
                    )
                    .font(AppType.hero)
                    .tracking(-0.8)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.ink)
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: 330)

            Spacer(minLength: 30)

            Button {
                Haptics.impact(.light)
                withAnimation(Motion.smooth) {
                    step = 1
                }
            } label: {
                Text("开始")
            }
            .buttonStyle(PrimaryButtonStyle())
            .opacity(welcomePhase == 0 ? 0.42 : 1)
            .disabled(welcomePhase == 0)
            .padding(.horizontal, 26)

            Button("退出登录") {
                showExitConfirm = true
            }
            .font(AppType.caption)
            .foregroundStyle(Theme.tertiaryText)
            .buttonStyle(SubtlePressStyle())
            .padding(.top, 14)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppBackground())
        .onTapGesture {
            if welcomePhase == 0 {
                withAnimation(Motion.quick) { welcomePhase = 1 }
            }
        }
    }

    // MARK: - Main flow

    var mainFlow: some View {
        VStack(spacing: 0) {
            header
            AppScrollView {
                stepContent
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 22)
            }
        }
        .background(AppBackground())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomBar
        }
    }

    var header: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Button {
                    Haptics.tap()
                    if step > 1 {
                        withAnimation(Motion.quick) { step -= 1 }
                    } else {
                        withAnimation(Motion.quick) { step = 0 }
                    }
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 38, height: 38)
                        .background(Theme.paper, in: Circle())
                        .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 1))
                }
                .buttonStyle(SubtlePressStyle(scale: 0.94))

                Spacer()

                Text("\(min(step, inputSteps)) / \(inputSteps)")
                    .font(AppType.micro)
                    .foregroundStyle(Theme.secondaryText)
                    .monospacedDigit()

                Button {
                    showExitConfirm = true
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.tertiaryText)
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(SubtlePressStyle())
                .accessibilityLabel("退出登录")
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.stroke)
                    Capsule()
                        .fill(Theme.cobalt)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 2)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    var progress: CGFloat {
        guard step > 0 else { return 0 }
        return min(1, CGFloat(step - 1) / CGFloat(max(1, inputSteps - 1)))
    }

    @ViewBuilder
    var stepContent: some View {
        switch step {
        case 1: nameStep
        case 2: sexStep
        case 3: ageHeightWeightStep
        case 4: goalStep
        case 5: injuryStep
        case 6: equipmentStep
        case 7: experienceStep
        case 8: frequencyDurationStep
        default: reportStep
        }
    }

    var bottomBar: some View {
        VStack(spacing: 0) {
            InkDivider()
            HStack(spacing: 10) {
                if step > 1 && step <= inputSteps {
                    Button("上一步") {
                        withAnimation(Motion.quick) { step -= 1 }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .frame(maxWidth: 108)
                }

                Button {
                    if step == inputSteps + 1 {
                        save()
                    } else {
                        advance()
                    }
                } label: {
                    Text(step == inputSteps + 1 ? "生成我的计划" : "下一步")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
        .background(Theme.chrome)
    }
}
