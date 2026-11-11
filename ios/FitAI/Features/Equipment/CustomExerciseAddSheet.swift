import SwiftUI
import UIKit

struct CustomExerciseAddSheet: View {
    @Environment(\.dismiss) var dismiss

    let onAdd: (String, [String], MuscleGroup, Equipment, Data?) -> Void

    @State private var name: String
    @State private var photoData: Data?
    @State private var targetMuscles: [String] = []
    @State private var equipment: Equipment = .machine
    @State private var showBodyPartPicker = false
    @FocusState private var nameFocused: Bool

    private let equipmentColumns = [
        GridItem(.flexible(), spacing: 7),
        GridItem(.flexible(), spacing: 7)
    ]

    init(
        initialName: String,
        photo: UIImage?,
        onAdd: @escaping (String, [String], MuscleGroup, Equipment, Data?) -> Void
    ) {
        _name = State(initialValue: initialName)
        _photoData = State(initialValue: photo?.jpegData(compressionQuality: 0.7))
        self.onAdd = onAdd
    }

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    EquipmentPhotoCard(
                        photoData: $photoData,
                        title: "器械照片"
                    )

                    nameCard
                    bodyPartCard
                    equipmentCard

                    Button {
                        add()
                    } label: {
                        Label("保存到器械库", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canSave)
                }
                .appPagePadding()
                .appPageTopPadding()
                .padding(.bottom, 24)
            }
            .background(AppBackground())
            .navigationTitle("补充器械信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .keyboardDoneToolbar()
            .onAppear {
                nameFocused = true
            }
            .sheet(isPresented: $showBodyPartPicker) {
                EquipmentBodyPartPickerView(initial: targetMuscles) { selection in
                    targetMuscles = selection
                }
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !targetMuscles.isEmpty
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("CUSTOM / 器械")
                .font(AppType.overline)
                .tracking(1.5)
                .foregroundStyle(Theme.cobalt)

            Text("补全器械信息")
                .font(AppType.display)
                .tracking(-0.9)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("AI 已预填识别名称和照片。确认训练部位后，保存到你的器械库。")
                .font(AppType.body)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("器械名称")
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(Theme.secondaryText)
            TextField("例如：髋外展机", text: $name)
                .focused($nameFocused)
                .textInputAutocapitalization(.never)
                .font(AppType.callout)
                .padding(12)
                .background(
                    Theme.ink.opacity(0.035),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                }
                .onChange(of: name) { _, value in
                    if value.count > 40 {
                        name = String(value.prefix(40))
                    }
                }
        }
        .card(padding: 14)
    }

    private var bodyPartCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("训练部位（必选）")
                    .font(.system(size: 9.5, weight: .semibold))
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
        .card(padding: 14)
    }

    private var equipmentCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("器械类别")
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(Theme.secondaryText)
            LazyVGrid(columns: equipmentColumns, spacing: 7) {
                ForEach(Equipment.allCases) { item in
                    selectionChip(
                        title: item.label,
                        selected: equipment == item
                    ) {
                        equipment = item
                        Haptics.select()
                    }
                }
            }
        }
        .card(padding: 14)
    }

    private func selectionChip(
        title: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppType.caption.weight(.semibold))
                .foregroundStyle(selected ? Theme.onAccent : Theme.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    selected ? Theme.cobalt : Theme.paper,
                    in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(
                            selected ? Theme.cobalt : Theme.stroke,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(SubtlePressStyle(scale: 0.96))
    }

    private func add() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !targetMuscles.isEmpty else { return }
        let bodyPart = targetMuscles.first.flatMap {
            ExerciseLibrary.bodyPart(forMuscle: $0)
        }
        let muscle = MuscleGroup.from(bodyPart: bodyPart) ?? .core
        onAdd(trimmed, targetMuscles, muscle, equipment, photoData)
        dismiss()
    }
}
