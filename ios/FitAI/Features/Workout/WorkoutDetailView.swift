import SwiftUI

struct WorkoutDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let session: WorkoutSession

    @State private var draft: WorkoutSession
    @State private var isEditing = false
    @State private var showDelete = false
    @State private var showExercisePicker = false
    @State private var message = ""
    @State private var showMessage = false

    init(session: WorkoutSession) {
        self.session = session
        _draft = State(initialValue: session)
    }

    private struct ExerciseGroup: Identifiable {
        let slug: String
        var sets: [SetLog]
        var id: String { slug }
    }

    private var groups: [ExerciseGroup] {
        var result: [ExerciseGroup] = []
        for log in draft.sets {
            if let index = result.firstIndex(where: { $0.slug == log.slug }) {
                result[index].sets.append(log)
            } else {
                result.append(ExerciseGroup(slug: log.slug, sets: [log]))
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
                        summaryCard
                    }

                    if groups.isEmpty {
                        EmptyStateView(
                            icon: "list.bullet.clipboard",
                            title: "这次没有记录组数",
                            message: isEditing
                                ? "点下方「添加动作」补一条训练记录。"
                                : "点右上角「编辑」可以补录动作和组数。"
                        )
                    } else {
                        ForEach(groups) { group in
                            if isEditing {
                                editExerciseCard(group)
                            } else {
                                exerciseCard(group)
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

                        Button(role: .destructive) {
                            showDelete = true
                        } label: {
                            Text("删除这条训练记录")
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
                }
                .padding(20)
                .padding(.bottom, 20)
            }
            .background(AppBackground())
            .navigationTitle(isEditing ? "编辑训练记录" : "训练详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if isEditing {
                        Button("取消") {
                            draft = session
                            isEditing = false
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
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerView(equipment: store.profile.availableEquipment) { exercise in
                    addExercise(exercise)
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

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(draft.dayTitle)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            Text(draft.date.formatted(date: .complete, time: .shortened))
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)

            HStack(spacing: 12) {
                metric("\(draft.durationMinutes)", "分钟")
                metric("\(draft.sets.count)", "组数")
                metric("\(Int(draft.volume))", "容量 kg")
            }

            HStack {
                Text("训练感受")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                Spacer()
                Text(feelingEmoji(draft.feeling))
                Text(feelingText(draft.feeling))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
            }

            if let notes = draft.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("训练心得")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                    Text(notes)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 2)
            }
        }
        .card()
    }

    private func metric(_ value: String, _ title: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.accent)
            Text(title)
                .font(.caption2)
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Theme.surfaceStrong, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func exerciseCard(_ group: ExerciseGroup) -> some View {
        let exercise = ExerciseLibrary.exercise(slug: group.slug)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise?.nameZH ?? group.slug)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("\(exercise?.muscle.label ?? "") · \(exercise?.equipment.label ?? "")")
                        .font(.caption2)
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                NavigationLink {
                    ExerciseProgressView(slug: group.slug)
                } label: {
                    Label("历史", systemImage: "chart.xyaxis.line")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
                Text("\(group.sets.count) 组")
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
                    .padding(.leading, 4)
            }

            ForEach(group.sets) { item in
                HStack {
                    Text("第 \(item.setIndex) 组")
                        .font(.caption)
                        .foregroundStyle(Theme.tertiaryText)
                        .frame(width: 52, alignment: .leading)

                    Text(item.weightKG > 0
                         ? "\(item.weightKG.formatted()) kg × \(item.reps)"
                         : "自重 × \(item.reps)")
                        .font(.subheadline)
                        .foregroundStyle(.white)

                    Spacer()

                    Text("RPE \(item.rpe.formatted(.number.precision(.fractionLength(1))))")
                        .font(.caption2)
                        .foregroundStyle(Theme.secondaryText)
                }
                .padding(.vertical, 4)
            }
        }
        .card()
    }

    // MARK: - 编辑

    private var editSummaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("训练名称")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                TextField("例如：全身 A", text: $draft.dayTitle)
                    .padding(11)
                    .background(
                        Theme.surfaceStrong,
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                    )
            }

            DatePicker(
                "训练日期",
                selection: $draft.date,
                in: Date.distantPast...Date(),
                displayedComponents: [.date, .hourAndMinute]
            )
            .font(.subheadline)

            Stepper(value: $draft.durationMinutes, in: 1...300, step: 5) {
                HStack {
                    Text("时长")
                    Spacer()
                    Text("\(draft.durationMinutes) 分钟")
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .font(.subheadline)

            VStack(alignment: .leading, spacing: 6) {
                Text("训练感受")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                Picker("训练感受", selection: $draft.feeling) {
                    ForEach(1...5, id: \.self) { value in
                        Text("\(feelingEmoji(value)) \(feelingText(value))")
                            .tag(value)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("训练心得")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                TextField("今天状态、动作感受、下次注意什么…", text: notesBinding, axis: .vertical)
                    .lineLimit(2...5)
                    .padding(11)
                    .background(
                        Theme.surfaceStrong,
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                    )
            }

            HStack(spacing: 12) {
                metric("\(draft.sets.count)", "组数")
                metric("\(Int(draft.volume))", "容量 kg")
            }
        }
        .card()
    }

    private func editExerciseCard(_ group: ExerciseGroup) -> some View {
        let exercise = ExerciseLibrary.exercise(slug: group.slug)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise?.nameZH ?? group.slug)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("\(exercise?.muscle.label ?? "") · \(exercise?.equipment.label ?? "")")
                        .font(.caption2)
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                Button(role: .destructive) {
                    deleteExercise(group.slug)
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(Theme.danger)
                }
                .buttonStyle(.plain)
            }

            ForEach(group.sets) { item in
                if let binding = setBinding(item.id) {
                    setEditor(binding)
                }
            }

            Button {
                addSet(for: group.slug)
            } label: {
                Label("添加一组", systemImage: "plus.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)
        }
        .card()
    }

    private func setEditor(_ item: Binding<SetLog>) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("第 \(item.wrappedValue.setIndex) 组")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Spacer()
                Button(role: .destructive) {
                    deleteSet(item.wrappedValue.id)
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.caption)
                        .foregroundStyle(Theme.danger.opacity(0.8))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 14) {
                HStack(spacing: 6) {
                    Text("重量")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                    TextField("0", value: item.weightKG, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 56)
                        .padding(7)
                        .background(
                            Theme.surfaceStrong,
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                    Text("kg")
                        .font(.caption2)
                        .foregroundStyle(Theme.tertiaryText)
                }

                HStack(spacing: 6) {
                    Text("次数")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                    Stepper("\(item.wrappedValue.reps)", value: item.reps, in: 0...100)
                        .labelsHidden()
                    Text("\(item.wrappedValue.reps)")
                        .font(.caption.weight(.semibold))
                        .frame(width: 24)
                }
            }

            HStack(spacing: 8) {
                Text("RPE")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                Slider(value: item.rpe, in: 6...10, step: 0.5)
                    .tint(Theme.accent)
                Text(item.wrappedValue.rpe.formatted(.number.precision(.fractionLength(1))))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 28)
            }

            Toggle("完成这一组", isOn: item.completed)
                .font(.caption)
                .tint(Theme.accent)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.surfaceStrong.opacity(0.6))
        )
    }

    // MARK: - 数据操作

    private var notesBinding: Binding<String> {
        Binding(
            get: { draft.notes ?? "" },
            set: { draft.notes = $0.isEmpty ? nil : $0 }
        )
    }

    private func setBinding(_ setID: UUID) -> Binding<SetLog>? {
        let fallback = SetLog(
            slug: "",
            setIndex: 1,
            weightKG: 0,
            reps: 0,
            rpe: 7
        )
        return Binding(
            get: {
                draft.sets.first(where: { $0.id == setID }) ?? fallback
            },
            set: { newValue in
                if let index = draft.sets.firstIndex(where: { $0.id == setID }) {
                    draft.sets[index] = newValue
                }
            }
        )
    }

    private func addSet(for slug: String) {
        let last = draft.sets.last { $0.slug == slug }
        draft.sets.append(
            SetLog(
                slug: slug,
                setIndex: (last?.setIndex ?? 0) + 1,
                weightKG: last?.weightKG ?? 0,
                reps: last?.reps ?? 10,
                rpe: last?.rpe ?? 7
            )
        )
        reindex()
    }

    private func addExercise(_ exercise: Exercise) {
        let base: Double = exercise.equipment == .bodyweight ? 0 : 10
        for index in 1...3 {
            draft.sets.append(
                SetLog(
                    slug: exercise.slug,
                    setIndex: index,
                    weightKG: base,
                    reps: 10,
                    rpe: 7
                )
            )
        }
        reindex()
    }

    private func deleteSet(_ setID: UUID) {
        draft.sets.removeAll { $0.id == setID }
        reindex()
    }

    private func deleteExercise(_ slug: String) {
        draft.sets.removeAll { $0.slug == slug }
        reindex()
    }

    private func reindex() {
        var counters: [String: Int] = [:]
        for index in draft.sets.indices {
            let slug = draft.sets[index].slug
            counters[slug, default: 0] += 1
            draft.sets[index].setIndex = counters[slug] ?? 1
        }
    }

    private func save() {
        let title = draft.dayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.dayTitle = title.isEmpty ? "训练记录" : title
        reindex()
        store.updateSession(draft)
        isEditing = false
        message = "训练记录已保存，首页和 AI 复盘数据会同步更新。"
        showMessage = true
    }

    private func feelingEmoji(_ value: Int) -> String {
        switch value {
        case 1: return "😫"
        case 2: return "😕"
        case 3: return "😐"
        case 4: return "🙂"
        default: return "💪"
        }
    }

    private func feelingText(_ value: Int) -> String {
        switch value {
        case 1: return "很吃力"
        case 2: return "有点累"
        case 3: return "一般"
        case 4: return "状态不错"
        default: return "状态很好"
        }
    }
}
