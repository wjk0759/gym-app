import SwiftUI

/// Edit the two focus areas that bias plan generation. Stored locally so the
/// next local or remote plan can use it without a profile schema change.
struct FocusAreasSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @AppStorage("fitai_focus_areas") private var storedFocusAreas = ""
    @State private var selected: Set<BodyFocusArea> = []
    @State private var regenerate = true

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    EditorialHeader(
                        eyebrow: "FOCUS / 训练重点",
                        title: "想让计划多照顾哪里？",
                        subtitle: "最多选两个。计划会在每一天优先安排对应动作，但不会破坏训练分化。"
                    )

                    BodyFocusMap(selected: $selected)

                    Toggle(isOn: $regenerate) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("保存后重新生成计划")
                                .font(AppType.callout.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                            Text("当前计划会归档，训练记录保留。")
                                .font(AppType.micro)
                                .foregroundStyle(Theme.tertiaryText)
                        }
                    }
                    .tint(Theme.cobalt)
                    .padding(14)
                    .background(Theme.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Theme.stroke, lineWidth: 1)
                    }

                    Text("不选就是全身均衡。重点部位只影响动作优先级，不会绕过伤病与安全限制。")
                        .font(AppType.micro)
                        .foregroundStyle(Theme.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .appPagePadding()
                .padding(.bottom, 24)
            }
            .background(AppBackground())
            .navigationTitle("训练重点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                selected = Set(
                    storedFocusAreas
                        .split(separator: ",")
                        .compactMap { BodyFocusArea(rawValue: String($0)) }
                )
            }
        }
    }

    private func save() {
        storedFocusAreas = BodyFocusArea.allCases
            .filter { selected.contains($0) }
            .map(\.rawValue)
            .joined(separator: ",")

        if regenerate, store.plan != nil {
            store.generatePlan(force: true)
        }
        Haptics.success()
        dismiss()
    }
}
