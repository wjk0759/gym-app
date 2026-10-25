import Foundation
import SwiftUI

struct OnboardingView: View {
    @Environment(AppStore.self) private var store

    @State private var draft = UserProfile()
    @State private var alertMessage = ""
    @State private var showAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                basicsCard
                bodyCard
                equipmentCard
                trainingCard
                goalCard
                safetyCard

                Button(action: save) {
                    Text("生成我的计划")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 4)

                Text("继续即表示你已阅读并同意《用户协议》与《隐私政策》。健康数据仅用于生成训练与饮食建议。")
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 30)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
        }
        .background(Theme.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            if !store.profile.nickname.isEmpty {
                draft = store.profile
            }
        }
        .alert("先确认一下", isPresented: $showAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                Text("AI 健身教练")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.accent.opacity(0.12), in: Capsule())

            Text("先花 2 分钟\n让计划适合你")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text("我们会根据你的目标、器械和可用时间编排训练，并随着记录持续调整。")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(.bottom, 4)
    }

    private var basicsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(title: "基础信息", subtitle: "用于计算热量与训练负荷")

            VStack(alignment: .leading, spacing: 8) {
                Text("怎么称呼你")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                TextField("例如：小林", text: $draft.nickname)
                    .textInputAutocapitalization(.never)
                    .padding(12)
                    .background(
                        Theme.surfaceStrong,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
            }

            Picker("性别", selection: $draft.sex) {
                ForEach(Sex.allCases) { item in
                    Text(item.label).tag(item)
                }
            }
            .pickerStyle(.segmented)

            Stepper(value: $draft.age, in: 14...70) {
                HStack {
                    Text("年龄")
                    Spacer()
                    Text("\(draft.age) 岁")
                        .foregroundStyle(Theme.secondaryText)
                }
            }

            MetricSlider(
                title: "身高",
                value: $draft.heightCM,
                range: 140...210,
                step: 1,
                unit: "cm"
            )
        }
        .card()
    }

    private var bodyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(title: "身体数据", subtitle: "三围选填，用于追踪体型变化")

            MetricSlider(
                title: "体重",
                value: $draft.weightKG,
                range: 35...160,
                step: 0.5,
                unit: "kg"
            )

            HStack {
                Text("BMI")
                Spacer()
                Text(String(format: "%.1f", draft.bmi))
                    .foregroundStyle(.white)
                Text(draft.bmiLabel)
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
            }
            .font(.subheadline)

            MetricSlider(
                title: "腰围",
                value: $draft.waistCM,
                range: 50...150,
                step: 1,
                unit: "cm"
            )
            MetricSlider(
                title: "胸围",
                value: $draft.chestCM,
                range: 60...150,
                step: 1,
                unit: "cm"
            )
            MetricSlider(
                title: "臀围",
                value: $draft.hipCM,
                range: 60...150,
                step: 1,
                unit: "cm"
            )
        }
        .card()
    }

    private var equipmentCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "可用器械", subtitle: "只安排你能用上的动作")

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 88), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(Equipment.allCases) { item in
                    Button {
                        toggle(item)
                    } label: {
                        TagChip(
                            text: item.label,
                            selected: draft.equipment.contains(item)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .card()
    }

    private var trainingCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(title: "训练安排", subtitle: "之后可以随时调整")

            Stepper(value: $draft.weeklyDays, in: 1...7) {
                HStack {
                    Text("每周训练")
                    Spacer()
                    Text("\(draft.weeklyDays) 天")
                        .foregroundStyle(Theme.secondaryText)
                }
            }

            Stepper(value: $draft.sessionMinutes, in: 15...120, step: 15) {
                HStack {
                    Text("单次时长")
                    Spacer()
                    Text("\(draft.sessionMinutes) 分钟")
                        .foregroundStyle(Theme.secondaryText)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("训练经验")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                Picker("训练经验", selection: $draft.experience) {
                    ForEach(Experience.allCases) { item in
                        Text(item.label).tag(item)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("伤病或疼痛（选填）")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                TextField("例如：右膝半月板旧伤、腰容易酸", text: $draft.injuries, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(12)
                    .background(
                        Theme.surfaceStrong,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
            }
        }
        .card()
    }

    private var goalCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(title: "你的目标", subtitle: "计划会围绕目标调整组次与负荷")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(GoalType.allCases) { item in
                    Button {
                        draft.goalType = item
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.label)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text(item.detail)
                                .font(.caption2)
                                .foregroundStyle(Theme.secondaryText)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(draft.goalType == item ? Theme.accent.opacity(0.16) : Theme.surfaceStrong)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(draft.goalType == item ? Theme.accent : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            if draft.goalType != .endurance {
                MetricSlider(
                    title: "目标体重",
                    value: $draft.targetWeightKG,
                    range: 35...160,
                    step: 0.5,
                    unit: "kg"
                )
            }

            DatePicker(
                "目标日期",
                selection: $draft.targetDate,
                in: Date()...Calendar.current.date(byAdding: .year, value: 1, to: Date())!,
                displayedComponents: .date
            )
            .font(.subheadline)

            if draft.bmi < 18.5 && draft.goalType == .loseFat {
                Label("当前 BMI 低于 18.5，不建议减脂。请选择重塑体型或增肌。", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.warning)
            }
        }
        .card()
    }

    private var safetyCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "cross.case")
                .foregroundStyle(Theme.accent)
            Text("本产品不提供医疗诊断。孕期、术后、心血管疾病或关节急性疼痛，请先咨询医生。")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
        }
        .card(padding: 14)
    }

    private func toggle(_ item: Equipment) {
        if draft.equipment.contains(item) {
            if item != .bodyweight {
                draft.equipment.remove(item)
            }
        } else {
            draft.equipment.insert(item)
        }
        draft.equipment.insert(.bodyweight)
    }

    private func save() {
        let name = draft.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            alertMessage = "先填一个称呼，方便教练在对话里称呼你。"
            showAlert = true
            return
        }

        if draft.bmi < 18.5 && draft.goalType == .loseFat {
            alertMessage = "当前 BMI 低于 18.5，不建议以减脂为目标。请改为重塑体型或增肌。"
            showAlert = true
            return
        }

        draft.nickname = name
        draft.equipment.insert(.bodyweight)
        store.completeOnboarding(draft)
    }
}

private struct MetricSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                Spacer()
                Text("\(display)\(unit)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            Slider(value: $value, in: range, step: step)
                .tint(Theme.accent)
        }
    }

    private var display: String {
        step < 1 ? String(format: "%.1f", value) : String(format: "%.0f", value)
    }
}
