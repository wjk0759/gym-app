import SwiftUI

struct WorkoutDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let session: WorkoutSession
    let isNew: Bool

    @State private var draft: WorkoutSession
    @State private var isEditing: Bool
    @State private var showDelete = false
    @State private var showExercisePicker = false
    @State private var message = ""
    @State private var showMessage = false

    init(session: WorkoutSession, isNew: Bool = false) {
        self.session = session
        self.isNew = isNew
        _draft = State(initialValue: session)
        _isEditing = State(initialValue: isNew)
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

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("SESSION / 训练详情")
                    .font(AppType.overline)
                    .tracking(1.3)
                    .foregroundStyle(Theme.cobalt)

                Spacer(minLength: 4)

                Text(draft.date.formatted(.dateTime.month().day().weekday(.abbreviated)))
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
            }

            Text(String(draft.dayTitle.prefix(40)))
                .lineLimit(2)
                .font(AppType.hero)
                .tracking(-0.6)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(draft.date.formatted(date: .complete, time: .shortened))
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)

            HStack(spacing: 8) {
                EditorialMetric(
                    title: "时长",
                    value: "\(draft.durationMinutes)",
                    unit: "分钟"
                )
                EditorialMetric(
                    title: "组数",
                    value: "\(draft.sets.count)",
                    unit: "组"
                )
                EditorialMetric(
                    title: "容量",
                    value: "\(Int(draft.volume))",
                    unit: "kg"
                )
            }

            HStack(spacing: 8) {
                Text(feelingEmoji(draft.feeling))
                    .font(.system(size: 19))
                Text(feelingText(draft.feeling))
                    .font(AppType.caption.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("训练感受")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
            }
            .padding(10)
            .background(Theme.ink.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            }

            if let notes = draft.notes, !notes.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Theme.cobalt)
                        .frame(width: 3, height: 16)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("训练心得")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.cobalt)
                        Text(String(notes.prefix(300)))
                            .font(AppType.callout)
                            .foregroundStyle(Theme.ink)
                            .lineLimit(6)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 2)
            }
        }
        .editorialCard(accent: Theme.lime)
    }

    private func exerciseCard(_ group: ExerciseGroup) -> some View {
        let exercise = ExerciseLibrary.exercise(slug: group.slug)
        return VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise?.nameZH ?? group.slug)
                        .font(AppType.headline)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(exercise?.muscle.label ?? "") · \(exercise?.equipment.label ?? "")")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                }

                Spacer(minLength: 4)

                NavigationLink {
                    ExerciseProgressView(slug: group.slug)
                } label: {
                    Label("历史", systemImage: "chart.xyaxis.line")
                        .font(AppType.micro)
                        .foregroundStyle(Theme.cobalt)
                }
                .buttonStyle(SubtlePressStyle(scale: 0.95))

                Text("\(group.sets.count) 组")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.onPrimary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Theme.primary, in: Capsule(style: .continuous))
            }

            InkDivider()

            ForEach(group.sets) { item in
                HStack(spacing: 9) {
                    Text("\(item.setIndex)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 22, height: 22)
                        .background(Theme.ink.opacity(0.05), in: Circle())

                    Text(item.weightKG > 0
                         ? "\(item.weightKG.formatted()) kg × \(item.reps)"
                         : "自重 × \(item.reps)")
                        .font(AppType.callout.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .monospacedDigit()

                    Spacer(minLength: 4)

                    Text("RPE \(item.rpe.formatted(.number.precision(.fractionLength(1))))")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.tertiaryText)
                }
                .padding(.vertical, 3)
            }
        }
        .card()
    }

    // MARK: - 编辑

    private var editSummaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("EDIT / 训练记录")
                .font(AppType.overline)
                .tracking(1.3)
                .foregroundStyle(Theme.cobalt)

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("训练名称", counter: "\(min(40, draft.dayTitle.count))/40")
                TextField("例如：全身 A", text: titleBinding)
                    .font(AppType.callout)
                    .padding(11)
                    .background(
                        Theme.ink.opacity(0.035),
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(Theme.stroke, lineWidth: 1)
                    }
            }

            DatePicker(
                "训练日期",
                selection: $draft.date,
                in: Date.distantPast...Date(),
                displayedComponents: [.date, .hourAndMinute]
            )
            .font(AppType.callout)
            .tint(Theme.cobalt)

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("时长")
                Stepper(value: $draft.durationMinutes, in: 1...300, step: 5) {
                    HStack {
                        Text("\(draft.durationMinutes) 分钟")
                            .font(AppType.callout.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                    }
                }
                .tint(Theme.cobalt)
            }

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("训练感受")
                Picker("训练感受", selection: $draft.feeling) {
                    ForEach(1...5, id: \.self) { value in
                        Text("\(feelingEmoji(value)) \(feelingText(value))")
                            .tag(value)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel(
                    "训练心得",
                    counter: "\(min(300, (draft.notes ?? "").count))/300"
                )
                TextField(
                    "今天状态、动作感受、下次注意什么…",
                    text: notesBinding,
                    axis: .vertical
                )
                .font(AppType.callout)
                .lineLimit(2...5)
                .padding(11)
                .background(
                    Theme.ink.opacity(0.035),
                    in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                }
            }

            HStack(spacing: 8) {
                EditorialMetric(
                    title: "组数",
                    value: "\(draft.sets.count)",
                    unit: "组"
                )
                EditorialMetric(
                    title: "容量",
                    value: "\(Int(draft.volume))",
                    unit: "kg"
                )
            }
        }
        .editorialCard(accent: Theme.cobalt)
    }

    private func fieldLabel(_ title: String, counter: String? = nil) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(Theme.secondaryText)
            Spacer()
            if let counter {
                Text(counter)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
            }
        }
    }

    private func editExerciseCard(_ group: ExerciseGroup) -> some View {
        let exercise = ExerciseLibrary.exercise(slug: group.slug)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise?.nameZH ?? group.slug)
                        .font(AppType.headline)
                        .foregroundStyle(Theme.ink)
                    Text("\(exercise?.muscle.label ?? "") · \(exercise?.equipment.label ?? "")")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                }

                Spacer(minLength: 4)

                Text("\(group.sets.count) 组")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.cobalt)

                Button(role: .destructive) {
                    deleteExercise(group.slug)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.danger)
                }
                .buttonStyle(SubtlePressStyle(scale: 0.94))
            }

            InkDivider()

            ForEach(group.sets) { item in
                if let binding = setBinding(item.id) {
                    setEditor(binding)
                }
            }

            Button {
                addSet(for: group.slug)
            } label: {
                Label("添加一组", systemImage: "plus.circle")
                    .font(AppType.caption.weight(.semibold))
                    .foregroundStyle(Theme.cobalt)
            }
            .buttonStyle(SubtlePressStyle())
            .padding(.top, 2)
        }
        .card()
    }

    private func setEditor(_ item: Binding<SetLog>) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("第 \(item.wrappedValue.setIndex) 组")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.ink.opacity(0.05), in: Capsule(style: .continuous))

                Spacer()

                Button(role: .destructive) {
                    deleteSet(item.wrappedValue.id)
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.danger.opacity(0.8))
                }
                .buttonStyle(SubtlePressStyle(scale: 0.94))
            }

            HStack(spacing: 14) {
                HStack(spacing: 6) {
                    Text("重量")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.secondaryText)
                    TextField("0", value: item.weightKG, format: .number)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 56)
                        .padding(7)
                        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Theme.stroke, lineWidth: 1)
                        }
                    Text("kg")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)
                }

                HStack(spacing: 6) {
                    Text("次数")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.secondaryText)
                    Stepper("\(item.wrappedValue.reps)", value: item.reps, in: 0...100)
                        .labelsHidden()
                        .tint(Theme.cobalt)
                    Text("\(item.wrappedValue.reps)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 24)
                }
            }

            HStack(spacing: 8) {
                Text("RPE")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.secondaryText)
                Slider(value: item.rpe, in: 6...10, step: 0.5)
                    .tint(Theme.cobalt)
                Text(item.wrappedValue.rpe.formatted(.number.precision(.fractionLength(1))))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.cobalt)
                    .frame(width: 28)
            }

            Toggle("完成这一组", isOn: item.completed)
                .font(AppType.caption)
                .tint(Theme.primary)
        }
        .padding(11)
        .background(
            Theme.ink.opacity(0.025),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }

    // MARK: - 数据操作

    private var titleBinding: Binding<String> {
        Binding(
            get: { draft.dayTitle },
            set: { draft.dayTitle = String($0.prefix(40)) }
        )
    }

    private var notesBinding: Binding<String> {
        Binding(
            get: { String((draft.notes ?? "").prefix(300)) },
            set: {
                let value = String($0.prefix(300))
                draft.notes = value.isEmpty ? nil : value
            }
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
        draft.dayTitle = String((title.isEmpty ? "训练记录" : title).prefix(40))
        draft.notes = draft.notes.map { String($0.prefix(300)) }
        reindex()
        if isNew {
            store.addSession(draft)
            dismiss()
            return
        }
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
