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

    init(mode: EquipmentBrowserMode) {
        self.mode = mode
    }

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

    private var screenTitle: String {
        switch mode {
        case .addToLibrary: return "器械库"
        case .selectType: return "选择器械"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                CatalogSearchField(
                    text: $query,
                    placeholder: "搜索器械或训练部位"
                )
                .padding(.horizontal, 16)
                .padding(.top, 9)
                .padding(.bottom, 9)

                CatalogTwoColumnLayout {
                    bodyPartSidebar
                } content: {
                    catalogGrid
                }
                .padding(.horizontal, 16)
            }
            .background(AppBackground())
            .navigationTitle(screenTitle)
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

    private var bodyPartSidebar: some View {
        CatalogSidebarContainer(width: 82) {
            CatalogSidebarButton(
                title: "全部",
                count: EquipmentCatalog.all.count,
                active: selectedBodyPart == nil && !isSearching
            ) {
                selectBodyPart(nil)
            }

            ForEach(EquipmentCatalog.bodyParts, id: \.self) { part in
                CatalogSidebarButton(
                    title: part,
                    count: EquipmentCatalog.count(for: part),
                    active: selectedBodyPart == part && !isSearching
                ) {
                    selectBodyPart(part)
                }
            }
        }
    }

    private func selectBodyPart(_ part: String?) {
        withAnimation(Motion.quick) {
            selectedBodyPart = part
            if isSearching {
                query = ""
            }
        }
    }

    private var catalogGrid: some View {
        ScrollView(showsIndicators: false) {
            if filtered.isEmpty {
                CatalogEmptyCard(
                    icon: "magnifyingglass",
                    title: "没有匹配的器械",
                    message: "换个器械名或清空搜索。"
                )
                .padding(.top, 4)
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 118), spacing: 9)
                    ],
                    alignment: .leading,
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
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 2)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func card(_ info: EquipmentTypeInfo) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            ZStack {
                Theme.paper
                EquipmentTypeImageView(info: info)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 108)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Theme.stroke.opacity(0.8), lineWidth: 1)
            }

            Text(info.nameZH)
                .font(AppType.callout.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(info.targetSummary)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

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
        .frame(maxWidth: .infinity, alignment: .leading)
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
