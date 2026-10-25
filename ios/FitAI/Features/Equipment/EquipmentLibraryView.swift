import AVKit
import PhotosUI
import SwiftUI
import UIKit

struct EquipmentLibraryView: View {
    @Environment(AppStore.self) private var store

    private enum EquipmentSheet: Identifiable {
        case search
        case manual(Data?)
        case detail(UUID)

        var id: String {
            switch self {
            case .search: return "search"
            case .manual: return "manual"
            case .detail(let id): return "detail-\(id.uuidString)"
            }
        }
    }

    @State private var activeSheet: EquipmentSheet?
    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                addEquipmentCard

                HStack {
                    Text("已添加的器械")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(store.equipmentLibrary.count) 件")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                .padding(.top, 2)

                if store.equipmentLibrary.isEmpty {
                    EmptyStateView(
                        icon: "dumbbell",
                        title: "器械库还是空的",
                        message: "点上方「搜索」「拍照」或「相册」添加第一件器械，之后就能在这里看教学视频。"
                    )
                } else {
                    ForEach(store.equipmentLibrary) { item in
                        Button {
                            activeSheet = .detail(item.id)
                        } label: {
                            equipmentRow(item)
                        }
                        .buttonStyle(.plain)
                    }
                }

                toggleCard

                Text("器械库会作为 AI 生成计划的可用器械来源。删除器械不会删除历史训练记录。")
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("我的器械库")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    activeSheet = .manual(nil)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .search:
                EquipmentSearchView()
            case .manual(let photoData):
                AddEquipmentView(initialPhotoData: photoData)
            case .detail(let id):
                EquipmentItemDetailView(itemID: id)
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { picked in
                guard let data = picked.jpegData(compressionQuality: 0.7) else { return }
                showCamera = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    activeSheet = .manual(data)
                }
            }
            .ignoresSafeArea()
        }
        .onChange(of: photoItem?.itemIdentifier) { _, _ in
            guard let item = photoItem else { return }
            Task { @MainActor in
                defer { photoItem = nil }
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    return
                }
                activeSheet = .manual(image.jpegData(compressionQuality: 0.7))
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("已录入 \(store.equipmentLibrary.count) 件器械")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            Text("搜索动作库、拍照或上传相册添加器械，添加后集中查看教学视频，并让 AI 按你的器械安排计划。")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var addEquipmentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("添加器械")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("搜索动作库，或拍照/相册上传")
                        .font(.caption2)
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
            }

            HStack(spacing: 8) {
                Button {
                    activeSheet = .search
                } label: {
                    addActionTile("magnifyingglass", "搜索")
                }
                .buttonStyle(.plain)

                Button {
                    showCamera = true
                } label: {
                    addActionTile("camera", "拍照")
                }
                .buttonStyle(.plain)

                PhotosPicker(selection: $photoItem, matching: .images) {
                    addActionTile("photo", "相册")
                }
            }

            Button {
                activeSheet = .manual(nil)
            } label: {
                Label("手动填写名称、视频与备注", systemImage: "square.and.pencil")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)
        }
        .card()
    }

    private func addActionTile(_ icon: String, _ title: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3.weight(.medium))
                .foregroundStyle(Theme.accent)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            Theme.surfaceStrong,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    private var toggleCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(
                "生成计划时优先使用器械库",
                isOn: Binding(
                    get: { store.useEquipmentLibraryForPlans },
                    set: {
                        store.useEquipmentLibraryForPlans = $0
                        store.persist()
                    }
                )
            )
            .font(.subheadline)
            .tint(Theme.accent)

            Text(store.useEquipmentLibraryForPlans
                 ? "下次生成/重新生成计划时，会优先从器械库和徒手动作里选择。"
                 : "已关闭：计划仍按档案里的器械类型生成。")
                .font(.caption2)
                .foregroundStyle(Theme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card(padding: 14)
    }

    private func equipmentRow(_ item: EquipmentItem) -> some View {
        HStack(spacing: 12) {
            equipmentThumbnail(item)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("\(item.muscle?.label ?? "未分类") · \(item.equipment?.label ?? "未设置")")
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryText)
                if item.videoURL != nil {
                    Label("已配置教学视频", systemImage: "play.rectangle")
                        .font(.caption2)
                        .foregroundStyle(Theme.accent)
                } else {
                    Text("未配置视频")
                        .font(.caption2)
                        .foregroundStyle(Theme.tertiaryText)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.tertiaryText)
        }
        .card(padding: 12)
    }

    @ViewBuilder
    private func equipmentThumbnail(_ item: EquipmentItem) -> some View {
        if let data = item.photoData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 58, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.surfaceStrong)
                .frame(width: 58, height: 58)
                .overlay(
                    Image(systemName: "dumbbell")
                        .foregroundStyle(Theme.accent)
                )
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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("输入器械或动作名称，选中后直接加入器械库，并自动带上教学视频。")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    TextField("例如：高位下拉、腿举", text: $query)
                        .focused($searchFocused)
                        .submitLabel(.search)
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
                            message: "换个关键词，或关闭后用「手动填写」添加自定义器械。"
                        )
                    } else {
                        ForEach(results) { exercise in
                            searchRow(exercise)
                        }
                    }

                    Text("找不到自定义器械？关闭搜索后点「手动填写」，可以自己填名称、视频和备注。")
                        .font(.caption2)
                        .foregroundStyle(Theme.tertiaryText)
                        .padding(.top, 4)
                }
                .padding(20)
                .padding(.bottom, 20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("搜索器械")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    searchFocused = true
                }
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
            .padding(12)
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
        store.addEquipment(
            EquipmentItem(
                name: exercise.nameZH,
                slug: exercise.slug,
                muscle: exercise.muscle,
                equipment: exercise.equipment,
                videoURL: exercise.videoURL?.absoluteString,
                notes: "从动作库搜索添加"
            )
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

struct EquipmentItemDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let itemID: UUID

    @State private var showDelete = false

    private var item: EquipmentItem? {
        store.equipmentLibrary.first { $0.id == itemID }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let item {
                    VStack(spacing: 16) {
                        if let data = item.photoData, let image = UIImage(data: data) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 230)
                                .frame(maxWidth: .infinity)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.name)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.white)
                            Text("\(item.muscle?.label ?? "未分类") · \(item.equipment?.label ?? "未设置")")
                                .font(.subheadline)
                                .foregroundStyle(Theme.accent)
                            if !item.notes.isEmpty {
                                Text(item.notes)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card()

                        videoSection(item)

                        Button {
                            store.useEquipmentLibraryForPlans = true
                            store.persist()
                            store.generatePlan()
                            dismiss()
                        } label: {
                            Label("按器械库重新生成计划", systemImage: "wand.and.stars")
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        Button(role: .destructive) {
                            showDelete = true
                        } label: {
                            Text("从器械库删除")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.danger)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Theme.danger.opacity(0.10))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(20)
                    .padding(.bottom, 20)
                } else {
                    EmptyStateView(
                        icon: "dumbbell",
                        title: "器械不存在",
                        message: "它可能已经被删除。"
                    )
                    .padding(20)
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("器械详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .confirmationDialog(
                "从器械库删除？",
                isPresented: $showDelete,
                titleVisibility: .visible
            ) {
                Button("删除", role: .destructive) {
                    store.removeEquipment(itemID)
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("删除后，下次生成计划不会再优先使用这件器械。")
            }
        }
    }

    @ViewBuilder
    private func videoSection(_ item: EquipmentItem) -> some View {
        if let text = item.videoURL, let url = URL(string: text) {
            VStack(alignment: .leading, spacing: 8) {
                Label("教学视频", systemImage: "play.rectangle")
                    .font(.headline)
                VideoPlayer(player: AVPlayer(url: url))
                    .frame(height: 210)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                Text("视频素材需自制或已授权；上线前请确认授权链。")
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
            }
            .card()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Label("教学视频", systemImage: "play.rectangle")
                    .font(.headline)
                Text("还没有视频地址。编辑器械时填入 HLS/MP4 链接后，这里会直接播放。")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
            .card()
        }
    }
}

struct AddEquipmentView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedExercise: Exercise?
    @State private var videoURL = ""
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
            ScrollView {
                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("器械名称")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                        TextField("例如：高位下拉", text: $name)
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
                        Text("教学视频地址（选填）")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                        TextField("https://...m3u8 或 .mp4", text: $videoURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(12)
                            .background(
                                Theme.surfaceStrong,
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                    }
                    .card()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("备注（选填）")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                        TextField("例如：调节座位高度在 3 档", text: $notes, axis: .vertical)
                            .lineLimit(2...4)
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
            .background(Theme.background.ignoresSafeArea())
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
                    if videoURL.isEmpty, let url = exercise.videoURL?.absoluteString {
                        videoURL = url
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
                CameraPicker { picked in
                    photoData = picked.jpegData(compressionQuality: 0.7)
                }
                .ignoresSafeArea()
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
            videoURL: videoURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil
                : videoURL.trimmingCharacters(in: .whitespacesAndNewlines),
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
