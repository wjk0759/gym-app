import PhotosUI
import SwiftUI
import UIKit

struct EquipmentLibraryView: View {
    @Environment(AppStore.self) private var store
    @AppStorage("pinnedEquipmentIDs") private var pinnedEquipmentIDsRaw = ""

    private enum EquipmentSheet: Identifiable {
        case manual
        case detail(UUID)

        var id: String {
            switch self {
            case .manual: return "manual"
            case .detail(let id): return "detail-\(id.uuidString)"
            }
        }
    }

    @State private var activeSheet: EquipmentSheet?
    @State private var query = ""
    @State private var openRowID: UUID?
    @State private var pendingDelete: EquipmentItem?

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
        AppScrollView {
            VStack(spacing: 16) {
                overviewCard
                libraryTools
                librarySectionHeader

                if filteredItems.isEmpty {
                    emptyCard
                } else {
                    libraryList
                }

                Text("器械库会作为 AI 生成计划的可用来源。删除器械不会影响历史训练记录。")
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
                    .lineSpacing(2)
                    .padding(.horizontal, 4)
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
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .manual:
                AddEquipmentView()
            case .detail(let id):
                EquipmentItemDetailView(itemID: id)
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
                        .fill(Theme.accent.opacity(0.12))
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Theme.accent.opacity(0.24), lineWidth: 1)
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
                .frame(width: 50, height: 50)

                VStack(alignment: .leading, spacing: 2) {
                    Text("我的器械")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.secondaryText)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(store.equipmentLibrary.count)")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text("件")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }

                    Text("教学视频与 AI 计划会优先读取这里")
                        .font(.caption2)
                        .foregroundStyle(Theme.tertiaryText)
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
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(store.useEquipmentLibraryForPlans
                         ? "生成计划时优先匹配我的器械"
                         : "已关闭，按档案器械生成")
                        .font(.caption2)
                        .foregroundStyle(Theme.tertiaryText)
                }
            }
            .tint(Theme.accent)
        }
        .card(padding: 18)
    }

    private var libraryTools: some View {
        HStack(spacing: 8) {
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.tertiaryText)

                TextField("搜索我的器械", text: $query)
                    .textInputAutocapitalization(.never)
                    .foregroundStyle(.white)
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
                            .font(.subheadline)
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
                Theme.surfaceStrong,
                in: RoundedRectangle(cornerRadius: 15, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(Theme.stroke, lineWidth: 1)
            )

            NavigationLink {
                EquipmentRecognitionView()
            } label: {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.86))
                    .frame(width: 46, height: 46)
                    .background(
                        LinearGradient(
                            colors: [Theme.accent, Theme.accentDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
                    )
                    .shadow(color: Theme.accent.opacity(0.16), radius: 12, y: 6)
            }
            .accessibilityLabel("拍照或相册添加器械")
        }
    }

    private var librarySectionHeader: some View {
        HStack {
            Text("器械清单")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
            Spacer()
            Text("\(filteredItems.count) 件 · 左滑删除")
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
        }
        .padding(.horizontal, 3)
    }

    private var libraryList: some View {
        VStack(spacing: 0) {
            ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
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
                        } else {
                            activeSheet = .detail(item.id)
                        }
                    },
                    onDelete: {
                        pendingDelete = item
                    }
                ) {
                    libraryRow(item)
                }

                if index < filteredItems.count - 1 {
                    Rectangle()
                        .fill(Theme.stroke.opacity(0.75))
                        .frame(height: 1)
                        .padding(.leading, 71)
                }
            }
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.stroke, lineWidth: 1)
        )
    }

    private func libraryRow(_ item: EquipmentItem) -> some View {
        HStack(spacing: 12) {
            libraryThumbnail(item)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(item.muscle?.label ?? "未分类") · \(item.equipment?.label ?? "未设置")")
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 5)

            if pinnedIDs.contains(item.id.uuidString) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .accessibilityLabel("已置顶")
            }

            Text(item.videoURL != nil ? "视频" : "准备中")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(item.videoURL != nil ? Theme.accent : Theme.tertiaryText)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    item.videoURL != nil ? Theme.accent.opacity(0.10) : Color.white.opacity(0.04),
                    in: Capsule()
                )

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.tertiaryText)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func libraryThumbnail(_ item: EquipmentItem) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Theme.accent.opacity(0.16), Color.white.opacity(0.035)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            if let data = item.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: equipmentSymbol(item))
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(Theme.accent)
            }
        }
        .frame(width: 46, height: 46)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.stroke, lineWidth: 1)
        )
    }

    private var emptyCard: some View {
        VStack(spacing: 10) {
            Image(systemName: store.equipmentLibrary.isEmpty ? "dumbbell" : "magnifyingglass")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Theme.accent)
                .frame(width: 50, height: 50)
                .background(Theme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text(store.equipmentLibrary.isEmpty ? "器械库还是空的" : "没有匹配的器械")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)

            Text(store.equipmentLibrary.isEmpty
                 ? "拍照或从相册识别第一件器械，生成计划时会优先使用它。"
                 : "换个名称、肌群或器械类型试试。")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if store.equipmentLibrary.isEmpty {
                NavigationLink {
                    EquipmentRecognitionView()
                } label: {
                    Text("添加第一件器械")
                }
                .buttonStyle(PrimaryButtonStyle())
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
            Color.white.opacity(0.025),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    Theme.stroke,
                    style: StrokeStyle(lineWidth: 1, dash: [5, 5])
                )
        )
    }

    private func equipmentSymbol(_ item: EquipmentItem) -> String {
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

private struct SwipeDeleteRow<Content: View>: View {
    let isOpen: Bool
    let onOpen: () -> Void
    let onClose: () -> Void
    let onTap: () -> Void
    let onDelete: () -> Void
    let content: Content

    @State private var dragOffset: CGFloat = 0

    private let actionWidth: CGFloat = 84

    init(
        isOpen: Bool,
        onOpen: @escaping () -> Void,
        onClose: @escaping () -> Void,
        onTap: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.isOpen = isOpen
        self.onOpen = onOpen
        self.onClose = onClose
        self.onTap = onTap
        self.onDelete = onDelete
        self.content = content()
    }

    private var offset: CGFloat {
        if dragOffset != 0 {
            return dragOffset
        }
        return isOpen ? -actionWidth : 0
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(action: onDelete) {
                Text("删除")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.danger)
                    .frame(width: actionWidth)
                    .frame(maxHeight: .infinity)
                    .background(Theme.danger.opacity(0.14))
            }
            .buttonStyle(.plain)
            .opacity(isOpen ? 1 : 0)
            .allowsHitTesting(isOpen)

            content
                .contentShape(Rectangle())
                .offset(x: offset)
                .onTapGesture {
                    if isOpen {
                        onClose()
                    } else {
                        onTap()
                    }
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 12, coordinateSpace: .local)
                        .onChanged { value in
                            guard abs(value.translation.width) > abs(value.translation.height) else {
                                return
                            }
                            let base = isOpen ? -actionWidth : 0
                            dragOffset = min(0, max(-actionWidth, base + value.translation.width))
                        }
                        .onEnded { value in
                            guard abs(value.translation.width) > abs(value.translation.height) else {
                                dragOffset = 0
                                return
                            }
                            let base = isOpen ? -actionWidth : 0
                            let projected = base + value.predictedEndTranslation.width
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                dragOffset = 0
                            }
                            if projected < -actionWidth * 0.45 {
                                onOpen()
                            } else {
                                onClose()
                            }
                        }
                )
        }
        .clipped()
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: isOpen)
        .accessibilityAction(named: Text("删除")) {
            onDelete()
        }
    }
}

struct EquipmentSearchView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private var results: [Exercise] {
        Array(ExerciseLibrary.search(query).prefix(60))
    }

    var body: some View {
        AppScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("输入器械或动作名称，选中后直接加入器械库，并自动带上教学视频。")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                TextField("例如：高位下拉、腿举", text: $query)
                    .focused($searchFocused)
                    .submitLabel(.search)
                    .onChange(of: query) { _, value in
                        if value.count > 60 {
                            query = String(value.prefix(60))
                        }
                    }
                    .padding(12)
                    .background(
                        Theme.surfaceStrong,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )

                HStack {
                    Text("搜索结果")
                        .font(.headline)
                    Spacer()
                    Text("\(results.count) 个")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                .padding(.top, 2)

                if results.isEmpty {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "没有找到",
                        message: "换个关键词，或返回器械库后用右上角「+」手动填写。"
                    )
                } else {
                    LazyVStack(spacing: 18) {
                        ForEach(results) { exercise in
                            searchRow(exercise)
                        }
                    }
                }

                Text("找不到自定义器械？返回器械库后点右上角「+」，可以自己填名称、视频和备注。")
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
                    .padding(.top, 4)
            }
            .padding(20)
            .padding(.bottom, 20)
        }
        .background(AppBackground())
        .navigationTitle("搜索器械")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                searchFocused = true
            }
        }
    }

    private func searchRow(_ exercise: Exercise) -> some View {
        let added = store.equipmentLibrary.contains { $0.slug == exercise.slug }
        return Button {
            add(exercise)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.nameZH)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("\(exercise.muscle.label) · \(exercise.equipment.label)")
                        .font(.caption2)
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer()

                if added {
                    Text("已添加")
                        .font(.caption)
                        .foregroundStyle(Theme.tertiaryText)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(14)
            .background(
                Theme.surfaceStrong,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .disabled(added)
    }

    private func add(_ exercise: Exercise) {
        guard !store.equipmentLibrary.contains(where: { $0.slug == exercise.slug }) else {
            return
        }
        store.addExercisesToEquipmentLibrary(
            [exercise],
            note: "从动作库搜索添加"
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

struct AddEquipmentView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedExercise: Exercise?
    @State private var notes = ""
    @State private var photoData: Data?
    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showExercisePicker = false
    @State private var message = ""
    @State private var showAlert = false

    init(initialPhotoData: Data? = nil) {
        _photoData = State(initialValue: initialPhotoData)
    }

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("器械名称")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                        TextField("例如：高位下拉", text: $name)
                            .onChange(of: name) { _, value in
                                if value.count > 30 {
                                    name = String(value.prefix(30))
                                }
                            }
                            .padding(12)
                            .background(
                                Theme.surfaceStrong,
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                    }
                    .card()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("对应动作")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                        Button {
                            showExercisePicker = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(selectedExercise?.nameZH ?? "选择动作")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.white)
                                    Text(selectedExercise.map {
                                        "\($0.muscle.label) · \($0.equipment.label)"
                                    } ?? "用于匹配计划与教学视频")
                                        .font(.caption2)
                                        .foregroundStyle(Theme.secondaryText)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(Theme.tertiaryText)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .card()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("备注（选填）")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                        TextField("例如：调节座位高度在 3 档", text: $notes, axis: .vertical)
                            .lineLimit(2...4)
                            .onChange(of: notes) { _, value in
                                if value.count > 120 {
                                    notes = String(value.prefix(120))
                                }
                            }
                            .padding(12)
                            .background(
                                Theme.surfaceStrong,
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                    }
                    .card()

                    photoCard

                    Button("保存到器械库") {
                        save()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(20)
                .padding(.bottom, 20)
            }
            .background(AppBackground())
            .navigationTitle("添加器械")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerView(equipment: store.profile.availableEquipment) { exercise in
                    selectedExercise = exercise
                    if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        name = exercise.nameZH
                    }
                }
            }
            .onChange(of: photoItem?.itemIdentifier) { _, _ in
                guard let item = photoItem else { return }
                Task { @MainActor in
                    await load(item)
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                PhotoCaptureView(
                    title: "拍摄器械",
                    hint: "让器械完整进入画面，避免只拍到局部或边缘。",
                    onImage: { picked in
                        photoData = picked.jpegData(compressionQuality: 0.7)
                        showCamera = false
                    },
                    onCancel: {
                        showCamera = false
                    }
                )
            }
            .alert("提示", isPresented: $showAlert) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(message)
            }
        }
    }

    private var photoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("器械照片（选填）")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)

            if let data = photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 160)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            HStack(spacing: 10) {
                Button("拍照") { showCamera = true }
                    .buttonStyle(SecondaryButtonStyle())
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Text("相册")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Theme.accent.opacity(0.10))
                        )
                }
            }
        }
        .card()
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            message = "先填一个器械名称，或选择对应动作。"
            showAlert = true
            return
        }

        let exercise = selectedExercise
        let item = EquipmentItem(
            name: trimmed,
            slug: exercise?.slug,
            muscle: exercise?.muscle,
            equipment: exercise?.equipment,
            videoURL: exercise?.videoURL?.absoluteString,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            photoData: photoData
        )
        store.addEquipment(item)
        dismiss()
    }

    @MainActor
    private func load(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            return
        }
        photoData = image.jpegData(compressionQuality: 0.7)
    }
}
