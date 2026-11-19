import SwiftUI

extension CoachOnboardingView {
    // MARK: - Welcome

    var welcome: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 40)

            CoachMark(size: 76)

            Text("叫练")
                .font(AppType.display)
                .foregroundStyle(Theme.ink)

            Spacer(minLength: 24)

            Button("开始") {
                Haptics.impact(.light)
                withAnimation(Motion.smooth) {
                    step = 1
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 26)

            Button("恢复档案") {
                Task { @MainActor in
                    isRestoringProfile = true
                    defer { isRestoringProfile = false }
                    await store.hydrateProfileFromServer()
                    let nickname = store.profile.nickname
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    let hasExistingData = store.profile.isOnboarded
                        || !nickname.isEmpty
                    if hasExistingData {
                        store.profile.isOnboarded = true
                        await store.pushProfileAndGoal()
                        auth.onboardingRequired = false
                    } else {
                        alertMessage = "这个账号还没有已保存的档案，请继续填写。"
                        showAlert = true
                    }
                }
            }
            .font(AppType.body)
            .foregroundStyle(Theme.secondaryText)
            .buttonStyle(.plain)
            .disabled(isRestoringProfile)

            Button("退出登录") {
                showExitConfirm = true
            }
            .font(AppType.body)
            .foregroundStyle(Theme.secondaryText)
            .buttonStyle(.plain)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppBackground())
    }

    // MARK: - Main flow

    var mainFlow: some View {
        // Keep the action bar in the layout instead of overlaying the scroll
        // content. The body-fat grid's last row must stay tappable above it.
        VStack(spacing: 0) {
            header
            AppScrollView {
                stepContent
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, isOptionalBodyStep ? 12 : 22)
            }
            bottomBar
        }
        .background(AppBackground())
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

                Text(stepIndicatorText)
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

    var stepIndicatorText: String {
        if isOptionalBodyStep { return "可选" }
        if isReportStep { return "报告" }
        return "\(min(step, inputSteps)) / \(inputSteps)"
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
        case bodyTypeStepIndex: bodyTypeStep
        case bodyFatStepIndex: bodyFatStep
        default: reportStep
        }
    }

    var bottomBar: some View {
        VStack(spacing: 0) {
            InkDivider()
            if isOptionalBodyStep {
                VStack(spacing: 8) {
                    Button("下一步") {
                        advance()
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button(
                        step == bodyTypeStepIndex
                            ? "跳过，使用默认参考"
                            : "跳过体脂"
                    ) {
                        if step == bodyTypeStepIndex {
                            skipBodyType()
                        } else {
                            skipBodyFat()
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 8)
            } else {
                HStack(spacing: 10) {
                    if step > 1 && step <= inputSteps {
                        Button("上一步") {
                            withAnimation(Motion.quick) { step -= 1 }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .frame(maxWidth: 108)
                    }

                    Button {
                        if isReportStep {
                            save()
                        } else {
                            advance()
                        }
                    } label: {
                        Text(isReportStep ? "生成我的计划" : "下一步")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 8)
            }
        }
        .background(Theme.chrome)
    }
}
