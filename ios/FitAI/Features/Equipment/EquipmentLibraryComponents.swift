import SwiftUI

struct SwipeDeleteRow<Content: View>: View {
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
                    .font(AppType.callout.weight(.semibold))
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

struct AddEquipmentView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private let editingItem: EquipmentItem?

    @State private var name = ""
    @State private var selectedType: EquipmentTypeInfo?
    @State private var targetMuscles: [String] = []
    @State private var notes = ""
    @State private var photoData: Data?
    @State private var showTypePicker = false
    @State private var showBodyPartPicker = false
    @State private var message = ""
    @State private var showAlert = false

    init(initialPhotoData: Data? = nil, editingItem: EquipmentItem? = nil) {
        self.editingItem = editingItem
        _name = State(initialValue: editingItem?.name ?? "")
        _selectedType = State(
            initialValue: EquipmentCatalog.type(for: editingItem?.equipmentType)
        )
        _targetMuscles = State(initialValue: editingItem?.targetMuscleList ?? [])
        _notes = State(initialValue: editingItem?.notes ?? "")
        _photoData = State(initialValue: editingItem?.photoData ?? initialPhotoData)
    }

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("器械名称")
                            .font(AppType.caption)
                            .foregroundStyle(Theme.secondaryText)
                        TextField("例如：高位下拉", text: $name)
                            .onChange(of: name) { _, value in
                                if value.count > 30 {
                                    name = String(value.prefix(30))
                                }
                            }
                            .padding(12)
                            .background(
                                Theme.ink.opacity(0.035),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                    }
                    .card()

                    typeCard

                    if selectedType == nil {
                        bodyPartCard
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("备注（选填）")
                            .font(AppType.caption)
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
                                Theme.ink.opacity(0.035),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                    }
                    .card()

                    EquipmentPhotoCard(
                        photoData: $photoData,
                        remotePhotoURL: editingItem?.photoURL
                    )

                    Button(editingItem == nil ? "保存到器械库" : "保存修改") {
                        save()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(20)
                .padding(.bottom, 20)
            }
            .background(AppBackground())
            .navigationTitle(editingItem == nil ? "添加器械" : "编辑器械")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .sheet(isPresented: $showTypePicker) {
                EquipmentTypePickerView { type in
                    selectedType = type
                    if let type,
                       name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        name = type.nameZH
                    }
                }
            }
            .sheet(isPresented: $showBodyPartPicker) {
                EquipmentBodyPartPickerView(initial: targetMuscles) { selection in
                    targetMuscles = selection
                }
            }
            .alert("提示", isPresented: $showAlert) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(message)
            }
        }
    }

    @ViewBuilder
    private var typeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("器械类型")
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)

            if editingItem != nil {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(selectedType?.nameZH ?? "自定义器械")
                            .font(AppType.callout)
                            .foregroundStyle(Theme.ink)
                        Text(
                            selectedType.map {
                                "\($0.categoryLabel) · \(trainableCount(for: $0)) 个动作"
                            } ?? "保存后不可修改器械类型"
                        )
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.secondaryText)
                    }
                    Spacer()
                }
            } else {
                Button {
                    showTypePicker = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(selectedType?.nameZH ?? "自定义器械")
                                .font(AppType.callout)
                                .foregroundStyle(Theme.ink)
                            Text(
                                selectedType.map {
                                    "\($0.categoryLabel) · \(trainableCount(for: $0)) 个动作"
                                } ?? "不关联标准类型，保存后可手动添加动作"
                            )
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(Theme.secondaryText)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(AppType.caption)
                            .foregroundStyle(Theme.tertiaryText)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .card()
    }

    private var bodyPartCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("训练部位（必选）")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
                Spacer()
                if targetMuscles.isEmpty {
                    Text("至少 1 个")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(Theme.coral)
                }
            }

            Button {
                showBodyPartPicker = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(
                            EquipmentItem.muscleSummary(for: targetMuscles)
                                ?? "选择训练部位"
                        )
                        .font(AppType.callout)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)

                        Text(
                            targetMuscles.isEmpty
                                ? "用于筛选动作和进入计划"
                                : "已选 \(targetMuscles.count) 个细分部位"
                        )
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(AppType.caption)
                        .foregroundStyle(Theme.tertiaryText)
                }
            }
            .buttonStyle(.plain)
        }
        .card()
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            message = "先填一个器械名称。"
            showAlert = true
            return
        }

        let isCustom = selectedType == nil
        if isCustom && targetMuscles.isEmpty {
            message = "请选择至少一个训练部位。"
            showAlert = true
            return
        }

        let firstBodyPart = targetMuscles.first.flatMap {
            ExerciseLibrary.bodyPart(forMuscle: $0)
        }
        let muscle = isCustom ? MuscleGroup.from(bodyPart: firstBodyPart) : nil
        let enabled = selectedType.map { type in
            ExerciseLibrary.all
                .filter { $0.planEligible && $0.equipmentTypes.contains(type.exerciseGroup) }
                .map(\.slug)
        } ?? []
        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        if let editingItem {
            store.updateEquipment(
                editingItem.id,
                name: trimmed,
                notes: cleanNotes,
                muscle: muscle,
                targetMuscles: isCustom ? targetMuscles : [],
                photoData: photoData,
                photoChanged: photoData != editingItem.photoData
            )
        } else {
            _ = store.addEquipment(
                equipmentType: selectedType?.slug,
                name: trimmed,
                category: selectedType?.category,
                photoData: photoData,
                enabledExerciseSlugs: enabled,
                notes: cleanNotes,
                muscle: muscle,
                targetMuscles: isCustom ? targetMuscles : [],
                source: "manual"
            )
        }
        dismiss()
    }

    private func trainableCount(for type: EquipmentTypeInfo) -> Int {
        ExerciseLibrary.all.filter {
            $0.planEligible && $0.equipmentTypes.contains(type.exerciseGroup)
        }.count
    }
}
