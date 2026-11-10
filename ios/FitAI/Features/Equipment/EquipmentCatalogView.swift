import SwiftUI

/// 器械库浏览：从 94 类目录里挑器械加入个人器械库。
struct EquipmentCatalogView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: String?
    @State private var query = ""

    private var filtered: [EquipmentTypeInfo] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return EquipmentCatalog.all
            .filter { info in
                if let selectedCategory,
                   EquipmentCatalog.browseCategory(of: info) != selectedCategory {
                    return false
                }
                guard !text.isEmpty else { return true }
                let haystack = ([info.nameZH, info.nameEN ?? ""] + (info.aliases ?? []))
                    .joined(separator: " ")
                    .lowercased()
                return haystack.contains(text)
            }
            .sorted { $0.nameZH < $1.nameZH }
    }

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    searchBar
                    categoryChips

                    if filtered.isEmpty {
                        emptyCard
                    } else {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 9),
                                GridItem(.flexible(), spacing: 9)
                            ],
                            spacing: 9
                        ) {
                            ForEach(filtered) { info in
                                card(info)
                            }
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .background(AppBackground())
            .navigationTitle("器械库")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
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

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip("全部", selected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(EquipmentCatalog.browseCategories, id: \.self) { category in
                    chip(category, selected: selectedCategory == category) {
                        selectedCategory = category
                    }
                }
            }
        }
    }

    private func chip(
        _ title: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.select()
            action()
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(selected ? Theme.onPrimary : Theme.secondaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    selected ? Theme.primary : Theme.paper,
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(
                            selected ? Theme.ink.opacity(0.12) : Theme.stroke,
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(.plain)
    }

    private func card(_ info: EquipmentTypeInfo) -> some View {
        let added = isAdded(info)
        let count = trainableExercises(for: info).count

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: info.symbolName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.cobalt)
                    .frame(width: 36, height: 36)
                    .background(
                        Theme.cobalt.opacity(0.10),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )

                Spacer()

                if info.universal {
                    Text("通用")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Theme.cobalt)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.cobalt.opacity(0.10), in: Capsule())
                }
            }

            Text(info.nameZH)
                .font(AppType.callout.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)

            Text("\(info.categoryLabel) · \(count) 个动作")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
                .lineLimit(1)

            Button {
                Haptics.tap()
                add(info)
            } label: {
                Text(added ? "已添加" : "添加")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(added ? Theme.tertiaryText : Theme.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        added ? Theme.ink.opacity(0.05) : Theme.cobalt,
                        in: Capsule(style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .disabled(added)
        }
        .padding(12)
        .background(
            Theme.paper,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }

    private var emptyCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(Theme.tertiaryText)
            Text("没有匹配的器械")
                .font(AppType.callout.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text("换个分类或清空搜索。")
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(
            Theme.paper,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    Theme.stroke,
                    style: StrokeStyle(lineWidth: 1, dash: [5, 5])
                )
        }
    }

    private func trainableExercises(for info: EquipmentTypeInfo) -> [Exercise] {
        ExerciseLibrary.all.filter {
            $0.planEligible && $0.equipmentTypes.contains(info.exerciseGroup)
        }
    }

    private func isAdded(_ info: EquipmentTypeInfo) -> Bool {
        if info.universal {
            return store.selectedUniversalSlugs.contains(info.slug)
        }
        return store.equipmentLibrary.contains { $0.equipmentType == info.slug }
    }

    private func add(_ info: EquipmentTypeInfo) {
        if info.universal {
            guard !store.selectedUniversalSlugs.contains(info.slug) else { return }
            store.setUniversalEquipment(store.selectedUniversalSlugs + [info.slug])
            return
        }
        guard !isAdded(info) else { return }
        _ = store.addEquipment(
            equipmentType: info.slug,
            name: info.nameZH,
            category: info.category,
            enabledExerciseSlugs: trainableExercises(for: info).map(\.slug),
            source: "catalog"
        )
    }
}
