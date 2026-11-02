import SwiftUI

extension FoodPhotoAnalysisView {
    var resultCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("识别结果")
                        .font(AppType.headline)
                        .foregroundStyle(Theme.ink)
                }
                Spacer()
                Text("参考置信度 \(Int(confidence * 100))%")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.cobalt)
            }

            ForEach($items) { $item in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 9) {
                        Toggle("", isOn: $item.selected)
                            .labelsHidden()
                            .tint(Theme.primary)

                        Text(item.name)
                            .font(AppType.callout.weight(.semibold))
                            .foregroundStyle(Theme.ink)

                        Spacer()

                        Text("\(Int(item.kcal)) kcal")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.cobalt)
                    }

                    HStack {
                        Stepper(value: $item.grams, in: 10...1000, step: 10) {
                            Text("份量 \(Int(item.grams)) g")
                                .font(AppType.caption)
                                .foregroundStyle(Theme.secondaryText)
                        }
                        .labelsHidden()
                        .tint(Theme.cobalt)
                        Text("\(Int(item.grams)) g")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.ink)
                            .frame(width: 58, alignment: .trailing)
                    }

                    Text("P \(item.protein.formatted(.number.precision(.fractionLength(0))))g · C \(item.carbs.formatted(.number.precision(.fractionLength(0))))g · F \(item.fat.formatted(.number.precision(.fractionLength(0))))g")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                }
                .opacity(item.selected ? 1 : 0.45)
                .padding(10)
                .background(
                    Theme.ink.opacity(0.03),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                }
            }

            VStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("合计")
                        .font(AppType.caption.weight(.semibold))
                        .foregroundStyle(Theme.secondaryText)
                    Spacer()
                    Text("\(Int(totalKcal)) kcal")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.cobalt)
                }

                HStack(spacing: 10) {
                    resultMetric("\(Int(totalProtein))g", "蛋白质")
                    resultMetric("\(Int(totalCarbs))g", "碳水")
                    resultMetric("\(Int(totalFat))g", "脂肪")
                }
            }
            .padding(12)
            .background(
                Theme.ink.opacity(0.035),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            }

            if !analysisModel.isEmpty {
                Text(analysisModel.hasPrefix("local")
                     ? "当前为本地估算模式，结果仅用于演示流程。"
                     : "结果来自远程识别服务，照片未保存。")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
            }

            Text(analysisDisclaimer)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                addToToday()
            } label: {
                Label("加入\(meal.label) · \(Int(totalKcal)) kcal", systemImage: "plus.circle.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(selectedItems.isEmpty)
        }
        .card()
    }

    func resultMetric(_ value: String, _ title: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.ink)
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
