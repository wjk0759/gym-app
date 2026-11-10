import ImageIO
import PhotosUI
import SwiftUI
import UIKit

struct EquipmentLibraryView: View {
    @Environment(AppStore.self) private var store
    @AppStorage("pinnedEquipmentIDs") private var pinnedEquipmentIDsRaw = ""

    private enum EquipmentSheet: Identifiable {
        case manual
        case detail(UUID)
        case physical(UUID)

        var id: String {
            switch self {
            case .manual: return "manual"
            case .detail(let id): return "detail-\(id.uuidString)"
            case .physical(let id): return "physical-\(id.uuidString)"
            }
        }
    }

    @State private var activeSheet: EquipmentSheet?
    @State private var query = ""
    @State private var openRowID: UUID?
    @State private var pendingDelete: EquipmentItem?
    @State private var showScanner = false
    @State private var showCatalog = false

    private var pinnedIDs: Set<String> {
        Set(pinnedEquipmentIDsRaw.split(separator: ",").map(String.init))
    }

    private var filteredItems: [EquipmentItem] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let items = text.isEmpty
            ? store.equipmentLibrary
            : store.equipmentLibrary.filter { item in
                item.name.localizedCaseInsensitiveContains(text)
                    || (item.muscle?.label.localizedCaseInsensitiveContains(text) ?? false)
                    || (item.equipment?.label.localizedCaseInsensitiveContains(text) ?? false)
            }

        return items.enumerated().sorted { lhs, rhs in
            let lhsPinned = pinnedIDs.contains(lhs.element.id.uuidString)
            let rhsPinned = pinnedIDs.contains(rhs.element.id.uuidString)
            if lhsPinned != rhsPinned { return lhsPinned }
            return lhs.offset < rhs.offset
        }.map(\.element)
    }

    private var strictModeBinding: Binding<Bool> {
        Binding(
            get: { store.strictEquipmentMode },
            set: {
                store.strictEquipmentMode = $0
                store.persist()
            }
        )
    }

    var body: some View {
        let items = filteredItems
        let pinned = pinnedIDs

        return AppScrollView {
            VStack(spacing: 16) {
                overviewCard
                universalEquipmentCard
                libraryTools
                librarySectionHeader(count: items.count)

                if items.isEmpty {
                    emptyCard
                } else {
                    libraryList(items: items, pinned: pinned)
                }

            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .background(AppBackground())
        .navigationTitle("器械库")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showCatalog = true
                    } label: {
                        Label("从器械库添加", systemImage: "list.bullet")
                    }
                    Button {
                        activeSheet = .manual
                    } label: {
                        Label("手动添加", systemImage: "square.and.pencil")
                    }
                    Button {
                        Haptics.tap()
                        if store.requirePro(.equipmentScan) {
                            showScanner = true
                        }
                    } label: {
                        Label("拍照识别", systemImage: "camera")
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("添加器械")
            }
        }
        .keyboardDoneToolbar()
        .navigationDestination(isPresented: $showScanner) {
            EquipmentRecognitionView()
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .manual:
                AddEquipmentView()
            case .detail(let id):
                EquipmentItemDetailView(itemID: id)
            case .physical(let id):
                PhysicalEquipmentDetailView(equipmentID: id)
            }
        }
        .sheet(isPresented: $showCatalog) {
            EquipmentCatalogView()
        }
        .confirmationDialog(
            "从器械库删除？",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let item = pendingDelete {
                    store.removeEquipment(item.id)
                    openRowID = nil
                }
                pendingDelete = nil
            }
            Button("取消", role: .cancel) {
                pendingDelete = nil
            }
        } message: {
            Text("删除后，下次生成计划不会再优先使用这件器械。")
        }
    }

    private var overviewCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.cobalt.opacity(0.12))
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Theme.cobalt.opacity(0.24), lineWidth: 1)
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(Theme.cobalt)
                }
                .frame(width: 50, height: 50)

                VStack(alignment: .leading, spacing: 2) {
                    Text("我的器械")
                        .font(AppType.caption.weight(.semibold))
                        .foregroundStyle(Theme.secondaryText)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(store.equipmentLibrary.count)")
                            .font(.system(size: 34, weight: .bold, design: .default))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        Text("件")
                            .font(AppType.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }

                }

                Spacer(minLength: 0)
            }

            Rectangle()
                .fill(Theme.stroke)
                .frame(height: 1)
                .padding(.vertical, 14)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("计划池")
                        .font(AppType.callout.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text("\(store.planPoolSlugs.count) 个动作")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.cobalt)
                }
                Text(coveredPartsText)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Toggle(isOn: strictModeBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("只用我的器械")
                        .font(AppType.callout.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text(store.strictEquipmentMode
                         ? "缺的部位用已勾选的通用器械补"
                         : "优先我的器械，不足自动补常用动作")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                }
            }
            .tint(Theme.primary)
            .padding(.top, 8)
        }
        .card(padding: 18)
    }

    private var universalEquipmentCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("通用器械")
                    .font(AppType.callout.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(store.selectedUniversalSlugs.count) 项")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 72), spacing: 8)],
                spacing: 8
            ) {
                ForEach(ExerciseLibrary.universalEquipment, id: \.slug) { item in
                    universalChip(item)
                }
            }
        }
        .card(padding: 16)
    }

    private func universalChip(_ item: UniversalEquipment) -> some View {
        let on = store.selectedUniversalSlugs.contains(item.slug)
        return Button {
            Haptics.select()
            store.toggleUniversalEquipment(item.slug)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 12, weight: .semibold))
                Text(item.name)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(on ? Theme.onPrimary : Theme.secondaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(
                on ? Theme.primary : Theme.paper,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(on ? Theme.ink.opacity(0.12) : Theme.stroke, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.name)\(on ? "已勾选" : "未勾选")")
    }

    private var coveredPartsText: String {
        let all = ["胸", "背", "肩", "臂", "腿", "臀", "核心"]
        let covered = store.planPoolBodyParts
        let text = all.map { covered.contains($0) ? "\($0)✓" : "\($0)–" }
            .joined(separator: "  ")
        return "覆盖：\(text)"
    }

    private var libraryTools: some View {
        HStack(spacing: 8) {
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .font(AppType.callout)
                    .foregroundStyle(Theme.tertiaryText)

                TextField("搜索我的器械", text: $query)
                    .textInputAutocapitalization(.never)
                    .foregroundStyle(Theme.ink)
                    .submitLabel(.search)
                    .onChange(of: query) { _, value in
                        if value.count > 60 {
                            query = String(value.prefix(60))
                        }
                    }

                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(AppType.callout)
                            .foregroundStyle(Theme.tertiaryText)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("清空搜索")
                }
            }
            .padding(.leading, 13)
            .padding(.trailing, 10)
            .padding(.vertical, 11)
            .background(
                Theme.ink.opacity(0.035),
                in: RoundedRectangle(cornerRadius: 15, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(Theme.stroke, lineWidth: 1)
            )

            Button {
                Haptics.tap()
                if store.requirePro(.equipmentScan) {
                    showScanner = true
                }
            } label: {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Theme.onAccent)
                    .frame(width: 46, height: 46)
                    .background(
                        Theme.cobalt,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Theme.ink.opacity(0.14), lineWidth: 1)
                    )
            }
            .accessibilityLabel("拍照或相册添加器械")
        }
    }

    private func librarySectionHeader(count: Int) -> some View {
        HStack {
            Text("器械清单")
                .font(AppType.caption.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
            Spacer()
            Text("\(count) 件 · 左滑删除")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(Theme.tertiaryText)
        }
        .padding(.horizontal, 3)
    }

    private func libraryList(items: [EquipmentItem], pinned: Set<String>) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                SwipeDeleteRow(
                    isOpen: openRowID == item.id,
                    onOpen: {
                        openRowID = item.id
                    },
                    onClose: {
                        if openRowID == item.id {
                            openRowID = nil
                        }
                    },
                    onTap: {
                        if openRowID == item.id {
                            openRowID = nil
                        } else if item.equipmentType != nil {
                            activeSheet = .physical(item.id)
                        } else {
                            activeSheet = .detail(item.id)
                        }
                    },
                    onDelete: {
                        pendingDelete = item
                    }
                ) {
                    libraryRow(item, pinned: pinned)
                }

                if index < items.count - 1 {
                    Rectangle()
                        .fill(Theme.stroke.opacity(0.75))
                        .frame(height: 1)
                        .padding(.leading, 71)
                }
            }
        }
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.stroke, lineWidth: 1)
        )
    }



    @ViewBuilder


    private var emptyCard: some View {
        VStack(spacing: 10) {
            if store.equipmentLibrary.isEmpty {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Theme.primary)
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 36, weight: .black))
                        .foregroundStyle(Theme.onPrimary)
                }
                .frame(width: 92, height: 92)
                .rotationEffect(.degrees(2))
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(Theme.cobalt)
                    .frame(width: 50, height: 50)
                    .background(Theme.cobalt.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            Text(store.equipmentLibrary.isEmpty ? "器械库还是空的" : "没有匹配的器械")
                .font(AppType.callout.weight(.semibold))
                .foregroundStyle(Theme.ink)

            Text(store.equipmentLibrary.isEmpty
                 ? "拍照识别或手动添加第一件器械，它关联的动作会进入计划池。"
                 : "换个名称试试。")
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if store.equipmentLibrary.isEmpty {
                VStack(spacing: 8) {
                    Button {
                        Haptics.tap()
                        showCatalog = true
                    } label: {
                        Text("从器械库添加")
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button {
                        Haptics.tap()
                        if store.requirePro(.equipmentScan) {
                            showScanner = true
                        }
                    } label: {
                        Label("拍照识别", systemImage: "camera.fill")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .padding(.top, 4)
            } else {
                Button("清空搜索") {
                    query = ""
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .background(
            Theme.paper,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    Theme.stroke,
                    style: StrokeStyle(lineWidth: 1, dash: [5, 5])
                )
        }
    }

    func equipmentSymbol(_ item: EquipmentItem) -> String {
        if let muscle = item.muscle {
            switch muscle {
            case .legs, .glutes, .core:
                return "figure.strengthtraining.functional"
            case .cardio:
                return "figure.run"
            case .chest, .back, .shoulders:
                return "figure.strengthtraining.traditional"
            case .arms:
                return "dumbbell"
            }
        }
        return item.equipment?.symbolName ?? "dumbbell"
    }
}
