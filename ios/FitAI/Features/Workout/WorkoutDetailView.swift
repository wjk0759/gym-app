import SwiftUI

struct WorkoutDetailView: View {
    @Environment(AppStore.self) var store
    @Environment(\.dismiss) var dismiss

    let session: WorkoutSession
    let isNew: Bool

    @State var draft: WorkoutSession
    @State var isEditing: Bool
    @State var showDelete = false
    @State var showExercisePicker = false
    @State var message = ""
    @State var showMessage = false

    init(session: WorkoutSession, isNew: Bool = false) {
        self.session = session
        self.isNew = isNew
        _draft = State(initialValue: session)
        _isEditing = State(initialValue: isNew)
    }

    private var groups: [WorkoutExerciseGroup] {
        var result: [WorkoutExerciseGroup] = []
        for log in draft.sets {
            if let index = result.firstIndex(where: { $0.slug == log.slug }) {
                result[index].sets.append(log)
            } else {
                result.append(WorkoutExerciseGroup(slug: log.slug, sets: [log]))
            }
        }
        return result.map { group in
            var copy = group
            copy.sets.sort { $0.setIndex < $1.setIndex }
            return copy
        }
    }

    var body: some View {
        NavigationStack {
            AppScrollView {
                VStack(spacing: 16) {
                    if isEditing {
                        editSummaryCard
                    } else {
                        WorkoutSummaryCard(session: draft)
                    }

                    if groups.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("这次没有记录组数")
                                .font(AppType.headline)
                                .foregroundStyle(Theme.ink)
                            Text(
                                isEditing
                                    ? "点下方「添加动作」补一条训练记录。"
                                    : "点右上角「编辑」可以补录动作和组数。"
                            )
                            .font(AppType.caption)
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card()
                    } else {
                        ForEach(groups) { group in
                            if isEditing {
                                editExerciseCard(group)
                            } else {
                                WorkoutExerciseCard(group: group)
                            }
                        }
                    }

                    if isEditing {
                        Button {
                            showExercisePicker = true
                        } label: {
                            Label("添加动作", systemImage: "plus")
                        }
                        .buttonStyle(SecondaryButtonStyle())

                        if !isNew {
                            Button(role: .destructive) {
                                showDelete = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 10, weight: .semibold))
                                    Text("删除这条训练记录")
                                        .font(AppType.caption.weight(.semibold))
                                }
                                .foregroundStyle(Theme.danger)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    Theme.danger.opacity(0.07),
                                    in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                                        .strokeBorder(Theme.danger.opacity(0.22), lineWidth: 1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .appPagePadding()
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(AppBackground())
            .navigationTitle(
                isEditing
                    ? (isNew ? "记录训练" : "编辑训练记录")
                    : "训练详情"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if isEditing {
                        Button("取消") {
                            if isNew {
                                dismiss()
                            } else {
                                draft = session
                                isEditing = false
                            }
                        }
                    } else {
                        Button("关闭") { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "保存" : "编辑") {
                        if isEditing {
                            save()
                        } else {
                            draft = session
                            isEditing = true
                        }
                    }
                }
            }
            .keyboardDoneToolbar()
            .fullScreenCover(isPresented: $showExercisePicker) {
                NavigationStack {
                    EquipmentPickerView(onSelect: { exercise in
                        addExercise(exercise)
                    })
                }
            }
            .confirmationDialog(
                "删除这条训练记录？",
                isPresented: $showDelete,
                titleVisibility: .visible
            ) {
                Button("删除", role: .destructive) {
                    store.deleteSession(session.id)
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("删除后无法恢复，训练容量和 AI 复盘数据也会同步更新。")
            }
            .alert("提示", isPresented: $showMessage) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(message)
            }
        }
    }

    // MARK: - 只读
}
