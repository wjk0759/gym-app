import SwiftUI

enum EquipmentBrowserMode {
    case addToLibrary
    case selectType((EquipmentTypeInfo?) -> Void)
}

/// 器械目录浏览：左侧部位，右侧图片网格。通用器械不在这里出现。
struct EquipmentBrowserView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let mode: EquipmentBrowserMode

    @State private var selectedBodyPart: String?
    @State private var query = ""
    @State private var showCustomAdd = false

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var filtered: [EquipmentTypeInfo] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if text.isEmpty {
            return EquipmentCatalog.types(for: selectedBodyPart)
        }
        return EquipmentCatalog.all.filter { info in
            let haystack = (
                [info.nameZH, info.nameEN ?? "", info.bodyPartLabel]
                    + (info.aliases ?? [])
                    + info.targetMuscleList
            )
            .joined(separator: " ")
            .lowercased()
            return haystack.contains(text)
        }
    }

    private var navigationTitle: String {
        switch mode {
        case .addToLibrary: return "器械库"
        case .selectType: return "选择器械"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                HStack(alignment: .top, spacing: 9) {
                    bodyPartSidebar
                    catalogGrid
                }
                .padding(.horizontal, 16)
            }
            .background(AppBackground())
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("自定义") { handleCustom() }
                }
            }
            .keyboardDoneToolbar()
            .sheet(isPresented: $showCustomAdd) {
                AddEquipmentView()
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.tertiaryText)
            TextField("搜索器械或训练部位", text: $query)
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
        .padding(.horizontal, 16)
        .padding(.top, 9)
        .padding(.bottom, 9)
    }

    private var bodyPartSidebar: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 1) {
                sideButton(nil, title: "全部", count: EquipmentCatalog.all.count)
                ForEach(EquipmentCatalog.bodyParts, id: \.self) { part in
                    sideButton(
                        part,
                        title: part,
                        count: EquipmentCatalog.count(for: part)
                    )
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 5)
        }
        .frame(width: 82)
        .background(
            Theme.paper,
            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }

    private func sideButton(_ part: String?, title: String, count: Int) -> some View {
        let active = selectedBodyPart == part && !isSearching

        return Button {
            Haptics.select()
            withAnimation(Motion.quick) {
                selectedBodyPart = part
                if isSearching {
                    query = ""
                }
            }
        } label: {
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: active ? .bold : .medium))
                    .foregroundStyle(active ? Theme.onPrimary : Theme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("\(count)")
                    .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(active ? Theme.onPrimary.opacity(0.72) : Theme.tertiaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                active ? Theme.primary : Color.clear,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title)器械")
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    private var catalogGrid: some View {
        ScrollView(showsIndicators: false) {
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
                        NavigationLink {
                            EquipmentCatalogDetailView(
                                info: info,
                                mode: mode,
                                onClose: { dismiss() }
                            )
                        } label: {
                            card(info)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
                .padding(.bottom, 24)
            }
        }
    }

    private func card(_ info: EquipmentTypeInfo) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            EquipmentTypeImageView(info: info)
                .frame(height: 108)
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(info.nameZH)
                .font(AppType.callout.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)

            Text(info.targetSummary)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1)

            HStack(spacing: 4) {
                Text(info.categoryLabel)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Theme.ink.opacity(0.045), in: Capsule())

                Spacer(minLength: 2)

                if isAdded(info) {
                    Text("已添加")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Theme.cobalt)
                }
            }
        }
        .padding(9)
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
            Text("换个器械名或清空搜索。")
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(
            Theme.paper,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.stroke, style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
        }
        .padding(.top, 4)
    }

    private func isAdded(_ info: EquipmentTypeInfo) -> Bool {
        store.equipmentLibrary.contains { $0.equipmentType == info.slug }
    }

    private func handleCustom() {
        switch mode {
        case .addToLibrary:
            showCustomAdd = true
        case .selectType(let onSelect):
            onSelect(nil)
            dismiss()
        }
    }
}
