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

/// Native menu picker used by workout and composer forms.
struct WheelPickerField<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [Value]
    let display: (Value) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(display(option)).tag(option)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.horizontal, 12)
            .background(
                Color(.secondarySystemFill),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .accessibilityLabel("选择\(title)")
        }
    }
}

/// Native segmented picker used across forms and filters.
struct AnimatedSegmentedControl<Item: Hashable>: View {
    let items: [Item]
    @Binding var selection: Item
    let label: (Item) -> String

    var body: some View {
        Picker(selection: $selection) {
            ForEach(items, id: \.self) { item in
                Text(label(item)).tag(item)
            }
        } label: {
            EmptyView()
        }
        .pickerStyle(.segmented)
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
            .background {
                SoftSurface(
                    cornerRadius: 10,
                    tint: Theme.surfaceStrong,
                    stroke: Theme.stroke
                )
            }
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
