import Foundation
import SwiftUI
import UIKit

enum WorkoutPickerOptions {
    static let sets = Array(1...10)
    static let reps = (1...30).map(String.init)

    static func rests(including current: Int) -> [Int] {
        let base = [0, 30, 45, 60, 75, 90, 120, 150, 180]
        return base.contains(current) ? base : (base + [current]).sorted()
    }

    static func normalizedReps(_ value: String) -> String {
        let first = value.components(separatedBy: "-").first ?? value
        let digits = first.filter(\.isNumber)
        guard let number = Int(digits.prefix(2)), (1...30).contains(number) else {
            return "10"
        }
        return String(number)
    }
}

/// A compact field that opens a native wheel picker sheet.
/// Reused by both the workout composer and the in-session adjust sheet.
struct WheelPickerField<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [Value]
    let display: (Value) -> String

    @State private var showPicker = false
    @State private var draft: Value

    init(
        title: String,
        selection: Binding<Value>,
        options: [Value],
        display: @escaping (Value) -> String
    ) {
        self.title = title
        _selection = selection
        self.options = options
        self.display = display
        _draft = State(initialValue: selection.wrappedValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.tertiaryText)
                .lineLimit(1)

            Button {
                Haptics.tap()
                draft = selection
                showPicker = true
            } label: {
                HStack(spacing: 4) {
                    Text(display(selection))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.tertiaryText)
                }
                .padding(.horizontal, 9)
                .frame(height: 46)
                .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.075), lineWidth: 1)
                )
            }
            .buttonStyle(SubtlePressStyle(scale: 0.98))
            .accessibilityLabel("选择\(title)")
            .sheet(isPresented: $showPicker) {
                WheelPickerSheet(
                    title: title,
                    options: options,
                    selection: $draft,
                    display: display
                ) {
                    selection = draft
                }
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.background)
            }
        }
    }
}

private struct WheelPickerSheet<Value: Hashable>: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let options: [Value]
    @Binding var selection: Value
    let display: (Value) -> String
    let onConfirm: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("取消") { dismiss() }
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)

                Spacer()

                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.primaryText)

                Spacer()

                Button("确认") {
                    onConfirm()
                    dismiss()
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.accent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Rectangle()
                .fill(Theme.stroke)
                .frame(height: 1)

            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(display(option))
                        .tag(option)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.background)
    }
}

/// 统一的滑动分段选择器：选中块用 matchedGeometry 滑动，带触感反馈。
struct AnimatedSegmentedControl<Item: Hashable>: View {
    let items: [Item]
    @Binding var selection: Item
    let label: (Item) -> String

    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 3) {
            ForEach(items, id: \.self) { item in
                Button {
                    guard selection != item else { return }
                    Haptics.select()
                    withAnimation(Motion.quick) {
                        selection = item
                    }
                } label: {
                    Text(label(item))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(selection == item ? Theme.accent : Theme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background {
                            if selection == item {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Theme.accent.opacity(0.16))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(Theme.accent.opacity(0.38), lineWidth: 0.8)
                                    )
                                    .matchedGeometryEffect(id: "segment", in: namespace)
                            }
                        }
                }
                .buttonStyle(SubtlePressStyle(scale: 0.96))
                .accessibilityAddTraits(selection == item ? .isSelected : [])
            }
        }
        .padding(3)
        .background(
            Color.white.opacity(0.035),
            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Theme.stroke, lineWidth: 0.8)
        )
    }
}

/// Weight remains directly editable because users need arbitrary loads.
struct WeightInputField: View {
    let title: String
    @Binding var weight: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.tertiaryText)
                .lineLimit(1)

            HStack(spacing: 4) {
                TextField("0", value: $weight, format: .number.precision(.fractionLength(0...1)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.primaryText)

                Text("kg")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.tertiaryText)
                    .padding(.trailing, 9)
            }
            .frame(height: 46)
            .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.075), lineWidth: 1)
            )
        }
    }
}

/// 训练中的精确数值输入页：点大号数值后打开。
/// 使用系统数字键盘，避免在训练中反复点加减。
struct WorkoutValueEntrySheet: View {
    let title: String
    let unit: String
    let footnote: String
    let allowsDecimal: Bool
    let range: ClosedRange<Double>
    let onSave: (Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    @State private var text = ""

    init(
        title: String,
        unit: String,
        footnote: String,
        allowsDecimal: Bool,
        range: ClosedRange<Double>,
        onSave: @escaping (Double) -> Void
    ) {
        self.title = title
        self.unit = unit
        self.footnote = footnote
        self.allowsDecimal = allowsDecimal
        self.range = range
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Text(footnote)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    TextField("0", text: $text)
                        .keyboardType(allowsDecimal ? .decimalPad : .numberPad)
                        .focused($isFocused)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 54, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(Theme.primaryText)
                        .tint(Theme.accent)
                        .frame(maxWidth: 220)
                        .onSubmit { save() }

                    Text(unit)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.tertiaryText)
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(
                    Theme.surfaceStrong,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Theme.stroke, lineWidth: 1)
                )
                .padding(.horizontal, 20)

                Text("有效范围 \(rangeText)")
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)

                Spacer(minLength: 0)
            }
            .padding(.top, 22)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppBackground())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(Theme.secondaryText)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.accent)
                        .disabled(!isValid)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { save() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
            .task {
                try? await Task.sleep(nanoseconds: 180_000_000)
                guard !Task.isCancelled else { return }
                isFocused = true
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.background)
    }

    private var parsedValue: Double? {
        let normalized = text
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, let value = Double(normalized), value.isFinite else {
            return nil
        }
        return value
    }

    private var isValid: Bool {
        guard let value = parsedValue, range.contains(value) else { return false }
        return allowsDecimal || value.rounded() == value
    }

    private var rangeText: String {
        "\(Self.format(range.lowerBound, allowsDecimal: allowsDecimal))–\(Self.format(range.upperBound, allowsDecimal: allowsDecimal)) \(unit)"
    }

    private func save() {
        guard isValid, let value = parsedValue else { return }
        onSave(value)
        dismiss()
    }

    private static func format(_ value: Double, allowsDecimal: Bool) -> String {
        guard allowsDecimal else { return String(Int(value.rounded())) }
        if value.rounded() == value {
            return String(Int(value))
        }
        if (value * 10).rounded() == value * 10 {
            return String(format: "%.1f", value)
        }
        return String(format: "%.2f", value)
    }
}

enum KeyboardDismiss {
    static func dismiss() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

extension View {
    func keyboardDoneToolbar() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") {
                    KeyboardDismiss.dismiss()
                }
            }
        }
    }
}
