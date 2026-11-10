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

    private var useLibraryBinding: Binding<Bool> {
        Binding(
            get: { store.useEquipmentLibraryForPlans },
            set: {
                store.useEquipmentLibraryForPlans = $0
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
                personalLibraryLink
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
                Button {
                    activeSheet = .manual
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("手动添加器械")
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

            Toggle(isOn: useLibraryBinding) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("计划优先使用")
                        .font(AppType.callout.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text(store.useEquipmentLibraryForPlans
                         ? "生成计划时优先匹配我的器械"
                         : "已关闭，按档案器械生成")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                }
            }
            .tint(Theme.primary)
        }
        .card(padding: 18)
    }

    private var personalLibraryLink: some View {
        NavigationLink {
            PersonalExerciseLibraryView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.cobalt)
                    .frame(width: 42, height: 42)
                    .background(
                        Theme.cobalt.opacity(0.10),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("个人动作库")
                        .font(AppType.callout.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text("\(store.personalExerciseSlugs.count) 个动作 · 生成计划优先使用")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.tertiaryText)
            }
            .padding(14)
            .background(
                Theme.paper,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("打开个人动作库")
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
                 ? "从动作库选第一件器械，生成计划时会优先使用它。"
                 : "换个名称、肌群或器械类型试试。")
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if store.equipmentLibrary.isEmpty {
                VStack(spacing: 8) {
                    NavigationLink {
                        EquipmentPickerView()
                    } label: {
                        Text("从动作库选择")
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
