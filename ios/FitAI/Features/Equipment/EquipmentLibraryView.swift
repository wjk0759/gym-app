import AVKit
import PhotosUI
import SwiftUI
import UIKit

struct EquipmentLibraryView: View {
    @Environment(AppStore.self) private var store

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

    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                addEntry

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
                        message: "点上方「添加器械」搜索、拍照或从相册上传第一件器械。"
                    )
                } else {
                    LazyVGrid(columns: gridColumns, spacing: 12) {
                        ForEach(store.equipmentLibrary) { item in
                            Button {
                                activeSheet = .detail(item.id)
                            } label: {
                                equipmentTile(item)
                            }
                            .buttonStyle(.plain)
                        }
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
        .navigationTitle("器械")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    activeSheet = .manual
                } label: {
                    Image(systemName: "plus")
                }
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
    }

    private var addEntry: some View {
        NavigationLink {
            EquipmentScanView()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.accent.opacity(0.12))
                        .frame(width: 46, height: 46)
                    Image(systemName: "plus")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Theme.accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("添加器械")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("搜索动作库，或拍照/相册录入")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.tertiaryText)
            }
            .card()
        }
        .buttonStyle(.plain)
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

    private func equipmentTile(_ item: EquipmentItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            equipmentTileImage(item)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text("\(item.muscle?.label ?? "未分类") · \(item.equipment?.label ?? "未设置")")
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)

                Label(
                    item.videoURL != nil ? "教学视频" : "视频准备中",
                    systemImage: item.videoURL != nil ? "play.rectangle.fill" : "play.rectangle"
                )
                .font(.caption2)
                .foregroundStyle(item.videoURL != nil ? Theme.accent : Theme.tertiaryText)
                .padding(.top, 1)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Theme.surface,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.stroke, lineWidth: 1)
        )
    }

    private func equipmentTileImage(_ item: EquipmentItem) -> some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let data = item.photoData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Theme.surfaceStrong
                        Image(systemName: equipmentSymbol(item))
                            .font(.system(size: 30, weight: .light))
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(8)
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

struct EquipmentSearchView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private var results: [Exercise] {
        Array(ExerciseLibrary.search(query).prefix(60))
    }

    var body: some View {
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
        .background(Theme.background.ignoresSafeArea())
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
    @State private var officialVideoURL: URL?

    private var item: EquipmentItem? {
        store.equipmentLibrary.first { $0.id == itemID }
    }

    private var videoURL: URL? {
        officialVideoURL ?? item?.videoURL.flatMap(URL.init(string:))
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

                        videoSection(videoURL)

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
            .task {
                guard store.useRemoteAI, let slug = item?.slug else { return }
                if let url = try? await APIClient.shared.officialVideoURL(slug: slug) {
                    officialVideoURL = url
                }
            }
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
    private func videoSection(_ url: URL?) -> some View {
        if let url {
            VStack(alignment: .leading, spacing: 10) {
                Label("教学视频", systemImage: "play.rectangle.fill")
                    .font(.headline)
                VideoPlayer(player: AVPlayer(url: url))
                    .frame(height: 210)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                Text("教学视频由练途动作库提供。")
                    .font(.caption2)
                    .foregroundStyle(Theme.tertiaryText)
            }
            .card()
        } else {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.accent.opacity(0.10))
                        .frame(width: 46, height: 46)
                    Image(systemName: "play.rectangle")
                        .foregroundStyle(Theme.accent)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("教学视频准备中")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("这件器械的示范视频尚未上线，可先向 AI 教练询问动作要点。")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
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
