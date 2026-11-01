import SwiftUI
import UIKit

struct BodyCheckInSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let manual: Bool

    @State private var weightText = ""
    @State private var bodyFatText = ""
    @State private var waistText = ""
    @State private var didLoad = false
    @State private var errorMessage = ""

    init(manual: Bool = false) {
        self.manual = manual
    }

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    fields

                    if let latest = store.latestBodyMetric {
                        Text("上次记录：\(FitnessDate.key(latest.date))")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(Theme.tertiaryText)
                    }

                    if !errorMessage.isEmpty {
                        HStack(spacing: 7) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text(errorMessage)
                                .font(AppType.caption.weight(.semibold))
                        }
                        .foregroundStyle(Theme.coral)
                        .padding(11)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            Theme.coral.opacity(0.07),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Theme.coral.opacity(0.22), lineWidth: 1)
                        }
                    }

                    Button("保存身体数据") {
                        save()
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    HStack(spacing: 10) {
                        Button("今天隐藏") {
                            store.dismissBodyCheckIn()
                            dismiss()
                        }
                        .buttonStyle(SecondaryButtonStyle())

                        Button("关闭自动提醒") {
                            store.disableBodyCheckIn()
                            dismiss()
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }

                    Text("建议早上空腹、同一时间测量。数据用于体重、体脂和围度趋势，不会自动改变训练计划。")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .appPagePadding()
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(AppBackground())
            .navigationTitle(manual ? "记录今日数据" : "更新身体数据")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onAppear(perform: load)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("BODY / 身体数据")
                .font(AppType.overline)
                .tracking(1.5)
                .foregroundStyle(Theme.cobalt)

            Text(manual ? "今天记录一次" : "更新身体数据")
                .font(AppType.display)
                .tracking(-0.9)
                .foregroundStyle(Theme.ink)

            Text("体重、体脂和腰围是目标进度与复盘的核心数据。围度可以在编辑资料里继续补充。")
                .font(AppType.body)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var fields: some View {
        VStack(spacing: 10) {
            inputRow(title: "体重", text: $weightText, unit: "kg", keyboard: .decimalPad)
            inputRow(title: "体脂率", text: $bodyFatText, unit: "%", keyboard: .decimalPad)
            inputRow(title: "腰围", text: $waistText, unit: "cm", keyboard: .decimalPad)
        }
        .card()
    }

    private func inputRow(
        title: String,
        text: Binding<String>,
        unit: String,
        keyboard: UIKeyboardType
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(Theme.tertiaryText)

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                TextField("0", text: text)
                    .keyboardType(keyboard)
                    .multilineTextAlignment(.leading)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.ink)
                    .tint(Theme.cobalt)

                Text(unit)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.tertiaryText)

                Spacer(minLength: 0)
            }
        }
        .padding(11)
        .background(
            Theme.ink.opacity(0.03),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        let latest = store.latestBodyMetric
        weightText = String(format: "%.1f", latest?.weightKG ?? store.profile.weightKG)
        bodyFatText = String(format: "%.1f", latest?.bodyFatPCT ?? store.profile.bodyFatPCT)
        waistText = String(format: "%.1f", latest?.waistCM ?? store.profile.waistCM)
    }

    private func save() {
        guard let weight = Double(weightText.replacingOccurrences(of: ",", with: ".")),
              (30...300).contains(weight) else {
            errorMessage = "体重填写 30–300 kg"
            return
        }
        guard let bodyFat = Double(bodyFatText.replacingOccurrences(of: ",", with: ".")),
              (3...60).contains(bodyFat) else {
            errorMessage = "体脂填写 3–60%"
            return
        }
        guard let waist = Double(waistText.replacingOccurrences(of: ",", with: ".")),
              (50...150).contains(waist) else {
            errorMessage = "腰围填写 50–150 cm"
            return
        }
        store.saveBodyCheckIn(weightKG: weight, bodyFatPCT: bodyFat, waistCM: waist)
        dismiss()
    }
}
