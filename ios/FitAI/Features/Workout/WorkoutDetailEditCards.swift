import SwiftUI

extension WorkoutDetailView {
    // MARK: - 编辑

    var editSummaryCard: some View {
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
                        Text("\(WorkoutFeeling.emoji(value)) \(WorkoutFeeling.text(value))")
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

    func fieldLabel(_ title: String, counter: String? = nil) -> some View {
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

    func editExerciseCard(_ group: WorkoutExerciseGroup) -> some View {
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

    func setEditor(_ item: Binding<SetLog>) -> some View {
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

    var titleBinding: Binding<String> {
        Binding(
            get: { draft.dayTitle },
            set: { draft.dayTitle = String($0.prefix(40)) }
        )
    }

    var notesBinding: Binding<String> {
        Binding(
            get: { String((draft.notes ?? "").prefix(300)) },
            set: {
                let value = String($0.prefix(300))
                draft.notes = value.isEmpty ? nil : value
            }
        )
    }

    func setBinding(_ setID: UUID) -> Binding<SetLog>? {
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

    func addSet(for slug: String) {
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

    func addExercise(_ exercise: Exercise) {
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

    func deleteSet(_ setID: UUID) {
        draft.sets.removeAll { $0.id == setID }
        reindex()
    }

    func deleteExercise(_ slug: String) {
        draft.sets.removeAll { $0.slug == slug }
        reindex()
    }

    func reindex() {
        var counters: [String: Int] = [:]
        for index in draft.sets.indices {
            let slug = draft.sets[index].slug
            counters[slug, default: 0] += 1
            draft.sets[index].setIndex = counters[slug] ?? 1
        }
    }

    func save() {
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
}
