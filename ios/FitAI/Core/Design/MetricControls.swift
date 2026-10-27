import Foundation
import SwiftUI

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
                .font(.system(size: 9.5))
                .foregroundStyle(Theme.tertiaryText)
                .lineLimit(1)

            Button {
                Haptics.tap()
                draft = selection
                showPicker = true
            } label: {
                HStack(spacing: 4) {
                    Text(display(selection))
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Theme.tertiaryText)
                }
                .padding(.horizontal, 9)
                .frame(height: 38)
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
                    .foregroundStyle(.white)

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

/// Weight remains directly editable because users need arbitrary loads.
struct WeightInputField: View {
    let title: String
    @Binding var weight: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 9.5))
                .foregroundStyle(Theme.tertiaryText)
                .lineLimit(1)

            HStack(spacing: 4) {
                TextField("0", value: $weight, format: .number.precision(.fractionLength(0...1)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white)

                Text("kg")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(Theme.tertiaryText)
                    .padding(.trailing, 9)
            }
            .frame(height: 38)
            .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.075), lineWidth: 1)
            )
        }
    }
}
