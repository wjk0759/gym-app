import SwiftUI

/// 个人动作库：用户从器械可练动作里选中的子集，计划优先只用它。
struct PersonalExerciseLibraryView: View {
    @Environment(AppStore.self) private var store

    @State private var selectedTrainingType: String = "力量"
    @State private var query = ""

    private var allExercises: [Exercise] {
        store.personalExerciseSlugs.compactMap { ExerciseLibrary.exercise(slug: $0) }
    }

    private var filtered: [Exercise] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allExercises
            .filter { $0.trainingType == selectedTrainingType }
            .filter { text.isEmpty || $0.searchKey.contains(text) }
            .sorted { $0.nameZH < $1.nameZH }
    }

    var body: some View {
        AppScrollView {
            VStack(alignment: .leading, spacing: 16) {
                overviewCard
                trainingTypeTabs
                searchBar

                if filtered.isEmpty {
                    emptyCard
                } else {
                    list
                }
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .background(AppBackground())
        .navigationTitle("个人动作库")
        .navigationBarTitleDisplayMode(.inline)
        .keyboardDoneToolbar()
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("我的动作")
                        .font(AppType.caption.weight(.semibold))
                        .foregroundStyle(Theme.secondaryText)
                    Text("\(allExercises.count) 个")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }
                Spacer()
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Theme.cobalt)
                    .frame(width: 52, height: 52)
                    .background(
                        Theme.cobalt.opacity(0.10),
                        in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                    )
            }
            Text(
                allExercises.count >= 8
                    ? "生成计划时会优先只用这些动作。"
                    : "再添加 \(max(0, 8 - allExercises.count)) 个动作，计划就会只用你的个人动作库。"
            )
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Theme.tertiaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
        .card(padding: 18)
    }

    private var trainingTypeTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ExerciseLibrary.trainingTypes, id: \.self) { type in
                    Button {
                        Haptics.select()
                        selectedTrainingType = type
                    } label: {
                        Text(type)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(
                                selectedTrainingType == type ? Theme.onPrimary : Theme.secondaryText
                            )
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                selectedTrainingType == type ? Theme.primary : Theme.paper,
                                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .stroke(
                                        selectedTrainingType == type
                                            ? Theme.ink.opacity(0.12)
                                            : Theme.stroke,
                                        lineWidth: 1
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.tertiaryText)
            TextField("搜索个人动作库", text: $query)
                .textInputAutocapitalization(.never)
                .foregroundStyle(Theme.ink)
                .submitLabel(.search)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.tertiaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Theme.ink.opacity(0.035),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }

    private var emptyCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Theme.cobalt)
                .frame(width: 52, height: 52)
                .background(
                    Theme.cobalt.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
            Text(allExercises.isEmpty ? "个人动作库还是空的" : "这个训练类型下没有动作")
                .font(AppType.callout.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text(
                allExercises.isEmpty
                    ? "先去器械库，把器械可练的动作加入个人动作库。"
                    : "换个训练类型或清空搜索。"
            )
            .font(AppType.caption)
            .foregroundStyle(Theme.secondaryText)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .background(
            Theme.paper,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.stroke, style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
        }
    }

    private var list: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(filtered.enumerated()), id: \.element.id) { index, exercise in
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(exercise.nameZH)
                            .font(AppType.callout.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                        Text("\(exercise.muscle.label) · \(exercise.equipment.label)")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(Theme.secondaryText)
                    }
                    Spacer()
                    Button {
                        Haptics.tap()
                        store.removeFromPersonalLibrary(exercise.slug)
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Theme.coral)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("从个人动作库移除\(exercise.nameZH)")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)

                if index < filtered.count - 1 {
                    Rectangle()
                        .fill(Theme.stroke.opacity(0.7))
                        .frame(height: 1)
                        .padding(.leading, 14)
                }
            }
        }
        .background(
            Theme.paper,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }
}
