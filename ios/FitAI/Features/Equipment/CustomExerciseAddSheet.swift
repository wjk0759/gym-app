import SwiftUI
import UIKit

struct CustomExerciseAddSheet: View {
    @Environment(\.dismiss) var dismiss

    let initialName: String
    let photo: UIImage?
    let onAdd: (String, MuscleGroup, Equipment) -> Void

    @State var name = ""
    @State var muscle: MuscleGroup = .chest
    @State var equipment: Equipment = .machine
    @FocusState private var nameFocused: Bool

    private let muscleColumns = [
        GridItem(.flexible(), spacing: 7),
        GridItem(.flexible(), spacing: 7),
        GridItem(.flexible(), spacing: 7)
    ]

    private let equipmentColumns = [
        GridItem(.flexible(), spacing: 7),
        GridItem(.flexible(), spacing: 7)
    ]

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if let photo {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 170)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Theme.stroke, lineWidth: 0.8)
                            )
                    }

                    nameCard
                    muscleCard
                    equipmentCard

                    Button {
                        add()
                    } label: {
                        Label("保存到器械库", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
                if name.isEmpty {
                    name = initialName
                }
                nameFocused = true
            }
        }
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

            Text("AI 已预填识别名称。确认名称、训练肌群和器械类型后，加入你的个人器械库。")
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

    private var muscleCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("主要训练肌群")
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(Theme.secondaryText)
            LazyVGrid(columns: muscleColumns, spacing: 7) {
                ForEach(MuscleGroup.allCases) { group in
                    selectionChip(
                        title: group.label,
                        selected: muscle == group
                    ) {
                        muscle = group
                        Haptics.select()
                    }
                }
            }
        }
        .card(padding: 14)
    }

    private var equipmentCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("器械类型")
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
        guard !trimmed.isEmpty else { return }
        onAdd(trimmed, muscle, equipment)
        dismiss()
    }
}
