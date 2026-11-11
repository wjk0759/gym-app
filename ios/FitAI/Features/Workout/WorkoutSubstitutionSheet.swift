import SwiftUI

struct WorkoutSubstitutionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let current: Exercise
    let profile: UserProfile
    let equipmentLibrary: [EquipmentItem]
    let universalSlugs: [String]
    let strictEquipment: Bool
    let todaySlugs: Set<String>
    let lastSet: (String) -> SetLog?
    let onSelect: (Exercise) -> Void
    let onSkip: () -> Void

    let result: ExerciseSubstitutionResult
    let pickerPool: [Exercise]

    @State private var page = 0
    @State private var showPicker = false

    init(
        current: Exercise,
        profile: UserProfile,
        equipmentLibrary: [EquipmentItem],
        universalSlugs: [String],
        strictEquipment: Bool,
        todaySlugs: Set<String>,
        lastSet: @escaping (String) -> SetLog?,
        onSelect: @escaping (Exercise) -> Void,
        onSkip: @escaping () -> Void
    ) {
        self.current = current
        self.profile = profile
        self.equipmentLibrary = equipmentLibrary
        self.universalSlugs = universalSlugs
        self.strictEquipment = strictEquipment
        self.todaySlugs = todaySlugs
        self.lastSet = lastSet
        self.onSelect = onSelect
        self.onSkip = onSkip
        self.result = ExerciseSubstitutionEngine.candidates(
            for: current,
            equipmentLibrary: equipmentLibrary,
            universalSlugs: universalSlugs,
            profile: profile,
            strictEquipment: strictEquipment,
            todaySlugs: todaySlugs,
            lastSet: lastSet
        )
        self.pickerPool = ExerciseSubstitutionEngine.pickerExercises(
            for: current,
            equipmentLibrary: equipmentLibrary,
            universalSlugs: universalSlugs,
            profile: profile,
            strictEquipment: strictEquipment,
            todaySlugs: todaySlugs,
            lastSet: lastSet
        )
    }

    private var items: [ExerciseSubstitution] {
        result.items
    }

    private var pageCount: Int {
        max(1, (items.count + 2) / 3)
    }

    private var visibleItems: [ExerciseSubstitution] {
        let start = min(page * 3, max(0, items.count - 1))
        return Array(items.dropFirst(start).prefix(3))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header

                    if items.isEmpty {
                        emptyState
                    } else {
                        if result.source == .bodyweight {
                            sourceNote("你的器械库里没有合适替代，先给你 3 个自重动作。馆里有同款空着的话，直接换一台也行。")
                        } else if strictEquipment {
                            sourceNote("只显示你器械库里的动作。")
                        }

                        ForEach(visibleItems) { item in
                            candidateCard(item)
                        }

                        if pageCount > 1 {
                            pager
                        }
                    }

                    actions
                }
                .appPagePadding()
                .padding(.vertical, 18)
                .appReadableContent()
            }
            .background(AppBackground())
            .navigationTitle("器械被占了")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .navigationDestination(isPresented: $showPicker) {
                WorkoutSubstitutionPicker(
                    current: current,
                    exercises: pickerPool,
                    lastSet: lastSet,
                    onSelect: onSelect
                )
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.background)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SUBSTITUTE / 换动作")
                .font(AppType.overline)
                .tracking(1.2)
                .foregroundStyle(Theme.cobalt)

            Text("\(current.nameZH) 被占了？")
                .font(AppType.title)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("给你几个替代，组数和休息不变。")
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)
        }
    }

    private func sourceNote(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: .medium))
            .foregroundStyle(Theme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Theme.cobalt.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
    }

    private func candidateCard(_ item: ExerciseSubstitution) -> some View {
        Button {
            Haptics.success()
            onSelect(item.exercise)
            dismiss()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(item.exercise.nameZH)
                            .font(AppType.headline)
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        if item.isOutsideLibrary {
                            Text("非我的器械")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Theme.warning)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Theme.warning.opacity(0.12),
                                    in: Capsule(style: .continuous)
                                )
                        }
                    }

                    Text("\(item.exercise.muscle.label) · \(item.exercise.equipment.label)")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.tertiaryText)

                    Text(item.reason)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 6)

                VStack(alignment: .trailing, spacing: 4) {
                    if let last = item.lastSet {
                        Text(last.weightKG > 0
                             ? "\(WorkoutWeightFormat.text(last.weightKG)) kg"
                             : "自重")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.cobalt)
                        Text("上次 \(last.reps) 次")
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundStyle(Theme.tertiaryText)
                    } else {
                        Text("没练过")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Theme.tertiaryText)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.tertiaryText)
                }
            }
            .padding(13)
            .background(
                Theme.paper,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var pager: some View {
        HStack(spacing: 10) {
            Button {
                Haptics.tap()
                withAnimation(Motion.quick) {
                    page = (page + 1) % pageCount
                }
            } label: {
                Label("换一批", systemImage: "arrow.2.circlepath")
            }
            .font(AppType.caption.weight(.semibold))
            .foregroundStyle(Theme.cobalt)
            .buttonStyle(SubtlePressStyle())

            Spacer()

            Text("\(page + 1)/\(pageCount)")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.tertiaryText)
        }
        .padding(.top, 2)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("你的器械库里没有合适的替代动作。")
                .font(AppType.headline)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(
                pickerPool.isEmpty
                    ? "今天先跳过这个动作，或者换一台同款。"
                    : "可以自己选一个，或者今天先跳过这个动作。馆里有同款/同类空着的话，直接换一台。"
            )
            .font(AppType.caption)
            .foregroundStyle(Theme.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
        .card(padding: 14)
    }

    private var actions: some View {
        VStack(spacing: 9) {
            if !pickerPool.isEmpty {
                Button {
                    Haptics.select()
                    showPicker = true
                } label: {
                    Label("自己选", systemImage: "magnifyingglass")
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            Button("今天先跳过") {
                Haptics.tap()
                onSkip()
                dismiss()
            }
            .font(AppType.caption.weight(.medium))
            .foregroundStyle(Theme.tertiaryText)
            .padding(.top, 2)
        }
        .padding(.top, 4)
    }
}

struct WorkoutSubstitutionPicker: View {
    @Environment(\.dismiss) private var dismiss

    let current: Exercise
    let exercises: [Exercise]
    let lastSet: (String) -> SetLog?
    let onSelect: (Exercise) -> Void

    @State private var query = ""
    @State private var sameMuscleOnly = true

    private var filtered: [Exercise] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return exercises.filter { exercise in
            if sameMuscleOnly, exercise.muscle != current.muscle {
                return false
            }
            if !text.isEmpty, !exercise.searchKey.contains(text) {
                return false
            }
            return true
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                searchField
                scopePicker

                if filtered.isEmpty {
                    Text("没有找到可用动作。")
                        .font(AppType.caption)
                        .foregroundStyle(Theme.secondaryText)
                        .padding(.vertical, 24)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(filtered) { exercise in
                            Button {
                                Haptics.success()
                                onSelect(exercise)
                                dismiss()
                            } label: {
                                row(exercise)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .appPagePadding()
            .padding(.vertical, 18)
            .appReadableContent()
        }
        .background(AppBackground())
        .navigationTitle("自己选")
        .navigationBarTitleDisplayMode(.inline)
        .keyboardDoneToolbar()
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.tertiaryText)

            TextField("搜索动作", text: $query)
                .font(AppType.callout)
                .foregroundStyle(Theme.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.tertiaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }

    private var scopePicker: some View {
        Picker("范围", selection: $sameMuscleOnly) {
            Text("同肌群").tag(true)
            Text("全部").tag(false)
        }
        .pickerStyle(.segmented)
    }

    private func row(_ exercise: Exercise) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.nameZH)
                    .font(AppType.callout.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                Text("\(exercise.muscle.label) · \(exercise.equipment.label)")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Theme.tertiaryText)
            }

            Spacer(minLength: 6)

            if let last = lastSet(exercise.slug) {
                Text(last.weightKG > 0
                     ? "\(WorkoutWeightFormat.text(last.weightKG)) kg"
                     : "自重")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.cobalt)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Theme.tertiaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }
}
