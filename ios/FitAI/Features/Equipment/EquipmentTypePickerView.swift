import SwiftUI

/// 手动添加器械时，从 94 类目录里选类型；也可以选「自定义器械」。
struct EquipmentTypePickerView: View {
    @Environment(\.dismiss) private var dismiss

    let onSelect: (EquipmentTypeInfo?) -> Void

    @State private var query = ""

    private var filtered: [EquipmentTypeInfo] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // 通用器械（哑铃 / 杠铃 / 徒手…）走器械库首页的勾选，不在这里重复建实物。
        let all = EquipmentCatalog.all
            .filter { !$0.universal }
            .sorted { $0.nameZH < $1.nameZH }
        guard !text.isEmpty else { return all }
        return all.filter { info in
            let haystack = ([info.nameZH, info.nameEN ?? ""] + (info.aliases ?? []))
                .joined(separator: " ")
                .lowercased()
            return haystack.contains(text)
        }
    }

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    searchBar
                    customRow

                    Text("哑铃、杠铃等通用器械在器械库首页勾选，不在这里重复添加。")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                        .padding(.horizontal, 2)
                        .padding(.bottom, 2)

                    ForEach(filtered) { info in
                        row(info)
                    }
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .background(AppBackground())
            .navigationTitle("选择器械类型")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .keyboardDoneToolbar()
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.tertiaryText)
            TextField("搜索器械", text: $query)
                .textInputAutocapitalization(.never)
                .foregroundStyle(Theme.ink)
                .submitLabel(.search)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.tertiaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Theme.ink.opacity(0.035),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }

    private var customRow: some View {
        Button {
            Haptics.select()
            onSelect(nil)
            dismiss()
        } label: {
            rowContent(
                symbol: "square.dashed",
                title: "自定义器械",
                subtitle: "不关联标准类型，保存后手动添加动作",
                trailing: nil
            )
        }
        .buttonStyle(.plain)
    }

    private func row(_ info: EquipmentTypeInfo) -> some View {
        Button {
            Haptics.select()
            onSelect(info)
            dismiss()
        } label: {
            rowContent(
                symbol: info.symbolName,
                title: info.nameZH,
                subtitle: info.categoryLabel,
                trailing: "\(trainableCount(for: info)) 个动作"
            )
        }
        .buttonStyle(.plain)
    }

    private func rowContent(
        symbol: String,
        title: String,
        subtitle: String,
        trailing: String?
    ) -> some View {
        HStack(spacing: 11) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.cobalt)
                .frame(width: 36, height: 36)
                .background(
                    Theme.cobalt.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppType.callout.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            if let trailing {
                Text(trailing)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.tertiaryText)
        }
        .padding(12)
        .background(
            Theme.paper,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }

    private func trainableCount(for info: EquipmentTypeInfo) -> Int {
        ExerciseLibrary.all.filter {
            $0.planEligible && $0.equipmentTypes.contains(info.exerciseGroup)
        }.count
    }
}
