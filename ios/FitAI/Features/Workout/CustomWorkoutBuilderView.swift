import Foundation
import SwiftUI
import UIKit

enum CustomWorkoutMode: Equatable {
    case plan
    case custom
}

/// 训练编排页。今日计划和已选动作共用同一套排序、组数、次数和重量编辑。
struct CustomWorkoutBuilderView: View {
    @Environment(\.dismiss) private var dismiss

    let initialExercises: [PlanExercise]
    let onStart: (PlanDay) -> Void
    let mode: CustomWorkoutMode
    let title: String

    @State private var exercises: [PlanExercise]

    init(
        title: String? = nil,
        mode: CustomWorkoutMode = .custom,
        initialExercises: [PlanExercise],
        onStart: @escaping (PlanDay) -> Void
    ) {
        self.initialExercises = initialExercises
        self.onStart = onStart
        self.mode = mode
        self.title = title ?? (mode == .plan ? "今日训练" : "自选训练")
        _exercises = State(initialValue: initialExercises)
    }

    private var totalSets: Int {
        exercises.reduce(0) { $0 + max(1, $1.sets) }
    }

    private var estimatedMinutes: Int {
        let work = exercises.reduce(0.0) { partial, item in
            partial + Double(max(1, item.sets)) * Double(max(1, item.restSec)) / 60 + 3
        }
        return max(15, Int(work.rounded()))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AppScrollView {
                    VStack(spacing: AppLayout.sectionSpacing) {
                        summaryCard

                        HStack {
                            Text("训练顺序")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                            Spacer(minLength: 8)
                            Text("↑ ↓ 调整")
                                .font(.system(size: 9.5))
                                .foregroundStyle(Theme.tertiaryText)
                        }
                        .padding(.horizontal, 2)

                        if exercises.isEmpty {
                            EmptyStateView(
                                icon: "dumbbell",
                                title: "还没有动作",
                                message: "返回动作库重新选择。"
                            )
                        } else {
                            ForEach(Array(exercises.enumerated()), id: \.element.id) { index, _ in
                                exerciseEditor(index: index)
                            }
                        }
                    }
                    .appPagePadding()
                    .padding(.vertical, 16)
                    .padding(.bottom, 24)
                    .appReadableContent()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                footer
            }
            .background(AppBackground())
            .navigationTitle("安排训练")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(mode == .plan ? "今日训练" : "自选训练")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.accent)
            Text(mode == .plan ? title : "先排顺序，再开始")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
            Text(mode == .plan
                 ? "今天的动作顺序、组数和重量都可以先调整；开始后仍可随时修改本次目标。"
                 : "动作顺序、组数、次数、重量都可以先改；开始后仍可在训练页临时调整。")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 14) {
                stat("\(exercises.count)", "个动作")
                stat("\(totalSets)", "组")
                stat("约 \(estimatedMinutes)", "分钟")
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RadialGradient(
                colors: [Theme.accent.opacity(0.16), .clear],
                center: .topLeading,
                startRadius: 2,
                endRadius: 260
            ),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .background(
            Theme.surface,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func metaText(_ info: Exercise?) -> String {
        guard let info else { return "" }
        return "\(info.muscle.label) · \(info.equipment.label)"
    }

    private func stat(_ value: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 9.5))
                .foregroundStyle(Theme.tertiaryText)
        }
    }

    private func exerciseEditor(index: Int) -> some View {
        let item = exercises[index]
        let info = item.exercise

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                Text(String(format: "%02d", index + 1))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 30, height: 30)
                    .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Theme.accent.opacity(0.16), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(info?.nameZH ?? item.slug)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(metaText(info))
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.tertiaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                HStack(spacing: 4) {
                    iconButton("arrow.up", label: "上移", disabled: index == 0) {
                        move(index, by: -1)
                    }
                    iconButton("arrow.down", label: "下移", disabled: index == exercises.count - 1) {
                        move(index, by: 1)
                    }
                    iconButton("trash", label: "移除", destructive: true) {
                        remove(index)
                    }
                }
            }

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 7),
                GridItem(.flexible(), spacing: 7)
            ], spacing: 8) {
                fieldTile("组数", text: intBinding(index, \.sets, fallback: 3, range: 1...10), keyboard: .numberPad)
                fieldTile("每组次数", text: $exercises[index].reps, keyboard: .numbersAndPunctuation)
                fieldTile("目标重量 kg", text: weightBinding(index), keyboard: .decimalPad)
                fieldTile("组间休息 秒", text: intBinding(index, \.restSec, fallback: 60, range: 0...300), keyboard: .numberPad)
            }
        }
        .padding(11)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.05), Color.white.opacity(0.018)],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 17, style: .continuous)
        )
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(Color.white.opacity(0.075), lineWidth: 1)
        )
    }

    private func iconButton(
        _ systemName: String,
        label: String,
        disabled: Bool = false,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(destructive ? Theme.danger : Theme.secondaryText)
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.075), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.26 : 1)
        .accessibilityLabel(label)
    }

    private func fieldTile(_ title: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 9.5))
                .foregroundStyle(Theme.tertiaryText)
                .lineLimit(1)
            TextField("", text: text)
                .keyboardType(keyboard)
                .multilineTextAlignment(.center)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(height: 36)
                .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.075), lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func intBinding(
        _ index: Int,
        _ keyPath: WritableKeyPath<PlanExercise, Int>,
        fallback: Int,
        range: ClosedRange<Int>
    ) -> Binding<String> {
        Binding(
            get: { "\(exercises[index][keyPath: keyPath])" },
            set: { value in
                let parsed = Int(value.filter(\.isNumber)) ?? fallback
                exercises[index][keyPath: keyPath] = min(max(parsed, range.lowerBound), range.upperBound)
            }
        )
    }

    private func weightBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: {
                guard let weight = exercises[index].weightKG, weight > 0 else { return "0" }
                return weight.formatted(.number.precision(.fractionLength(0...1)))
            },
            set: { value in
                let weight = Double(value.replacingOccurrences(of: ",", with: ".")) ?? 0
                exercises[index].weightKG = weight > 0 ? weight : nil
            }
        )
    }

    private var footer: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(totalSets) 组 · 约 \(estimatedMinutes) 分钟")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer(minLength: 8)
                Text("开始后仍可调整")
                    .font(.system(size: 9.5))
                    .foregroundStyle(Theme.tertiaryText)
            }

            Button("开始本次训练") {
                start()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(exercises.isEmpty)
            .opacity(exercises.isEmpty ? 0.45 : 1)
        }
        .appPagePadding()
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.stroke)
                .frame(height: 1)
        }
    }

    private func move(_ index: Int, by offset: Int) {
        let target = index + offset
        guard exercises.indices.contains(target) else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
            exercises.swapAt(index, target)
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func remove(_ index: Int) {
        guard exercises.indices.contains(index) else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
            exercises.remove(at: index)
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func start() {
        guard !exercises.isEmpty else { return }
        let normalized = exercises.map { item in
            var item = item
            item.sets = min(max(item.sets, 1), 10)
            item.reps = item.reps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "10-12"
                : item.reps
            item.restSec = min(max(item.restSec, 0), 300)
            return item
        }
        let focus = Array(Set(normalized.compactMap { $0.exercise?.muscle }))
        onStart(
            PlanDay(
                weekday: Weekday.today,
                title: title,
                focus: focus,
                exercises: normalized
            )
        )
        dismiss()
    }
}
