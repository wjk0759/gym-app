import SwiftUI

extension CoachOnboardingView {
    // MARK: - Steps

    var nameStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            stepTitle(
                eyebrow: "先认识你",
                title: "我怎么称呼你？",
                subtitle: "教练会在对话里这样叫你，不用真名。"
            )

            TextField("例如：小林", text: $draft.nickname)
                .focused($nameFocused)
                .font(.system(size: 30, weight: .bold, design: .default))
                .foregroundStyle(Theme.ink)
                .padding(.vertical, 18)
                .padding(.horizontal, 18)
                .background(Theme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Theme.ink.opacity(0.22), lineWidth: 1.2)
                }
                .submitLabel(.next)
                .onSubmit { advance() }
                .onChange(of: draft.nickname) { _, value in
                    if value.count > 30 { draft.nickname = String(value.prefix(30)) }
                }

            HStack(spacing: 10) {
                CoachMark(size: 34)
                Text("名字只用于 App 内称呼，不上传通讯录。")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                nameFocused = true
            }
        }
    }

    var ageHeightStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            stepTitle(
                eyebrow: "身体基线",
                title: "年龄和身高",
                subtitle: "这两个数决定热量和动作幅度。"
            )

            VStack(spacing: 12) {
                valueControl(
                    title: "年龄",
                    value: "\(draft.age)",
                    unit: "岁",
                    decrement: { draft.age = max(14, draft.age - 1) },
                    increment: { draft.age = min(80, draft.age + 1) }
                )
                valueControl(
                    title: "身高",
                    value: String(format: "%.0f", draft.heightCM),
                    unit: "cm",
                    decrement: { draft.heightCM = max(140, draft.heightCM - 1) },
                    increment: { draft.heightCM = min(210, draft.heightCM + 1) }
                )
            }
        }
    }

    var weightStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            stepTitle(
                eyebrow: "身体基线",
                title: "现在大概多少公斤？",
                subtitle: "不用精确到小数点，后面可以随时改。"
            )

            VStack(spacing: 18) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(String(format: "%.1f", draft.weightKG))
                        .font(AppType.number)
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText())
                    Text("kg")
                        .font(AppType.headline)
                        .foregroundStyle(Theme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .center)

                Slider(value: $draft.weightKG, in: 35...160, step: 0.5)
                    .tint(Theme.cobalt)

                HStack {
                    Text("35")
                    Spacer()
                    Text("160")
                }
                .font(AppType.micro)
                .foregroundStyle(Theme.tertiaryText)
            }
            .padding(22)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            }
        }
    }

    var goalStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepTitle(
                eyebrow: "方向",
                title: "接下来最想改变什么？",
                subtitle: "先选一个主目标，其他目标可以在教练里继续加。"
            )

            VStack(spacing: 10) {
                ForEach(GoalType.allCases) { goal in
                    goalCard(goal)
                }
            }
        }
    }

    var focusStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepTitle(
                eyebrow: "训练重点",
                title: "想重点改善哪里？",
                subtitle: "可多选。"
            )

            FocusAreaGrid(selected: $focusAreas)
        }
    }

    var injuryStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepTitle(
                eyebrow: "安全",
                title: "有需要避开的伤病吗？",
                subtitle: "有伤病不会阻止你练，只会让计划绕开风险动作。"
            )

            Toggle(isOn: Binding(
                get: { noInjuries },
                set: { value in
                    noInjuries = value
                    if value {
                        injuries.removeAll()
                        injuryNote = ""
                    }
                }
            )) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("没有任何伤病")
                        .font(AppType.headline)
                        .foregroundStyle(Theme.ink)
                    Text("计划按常规动作安排")
                        .font(AppType.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .tint(Theme.primary)
            .padding(16)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        noInjuries ? Theme.cobalt : Theme.stroke,
                        lineWidth: noInjuries ? 1.8 : 1
                    )
            }

            VStack(spacing: 0) {
                ForEach(Array(injuryOptions.enumerated()), id: \.element) { index, injury in
                    Toggle(isOn: Binding(
                        get: { injuries.contains(injury) },
                        set: { value in
                            noInjuries = false
                            if value {
                                injuries.insert(injury)
                            } else {
                                injuries.remove(injury)
                            }
                            Haptics.select()
                        }
                    )) {
                        Text(injury)
                            .font(AppType.callout)
                            .foregroundStyle(Theme.ink)
                    }
                    .tint(Theme.primary)
                    .padding(.vertical, 12)

                    if index < injuryOptions.count - 1 {
                        InkDivider()
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            }

            TextField("补充说明，例如：右膝下楼疼、肩峰撞击", text: $injuryNote, axis: .vertical)
                .font(AppType.body)
                .padding(14)
                .background(Theme.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 1)
                }
                .lineLimit(2...4)
                .onChange(of: injuryNote) { _, value in
                    if !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        noInjuries = false
                    }
                }

        }
    }

    var locationStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepTitle(
                eyebrow: "训练条件",
                title: "你主要在哪里练？",
                subtitle: "我会先按这个条件选动作，之后还能改。"
            )

            VStack(spacing: 10) {
                ForEach(TrainingLocation.allCases) { item in
                    choiceCard(
                        title: item.title,
                        detail: item.detail,
                        symbol: item.symbol,
                        selected: location == item
                    ) {
                        location = item
                        draft.equipment = item.equipment
                    }
                }
            }
        }
    }

    var equipmentStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepTitle(
                eyebrow: "训练条件",
                title: "你实际能用什么？",
                subtitle: "只选真的能用的；没有器械也可以从徒手开始。"
            )

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                ForEach(Equipment.allCases) { item in
                    equipmentCard(item)
                }
            }

            Text("至少选一种。计划只会安排你选了的器械。")
                .font(AppType.micro)
                .foregroundStyle(Theme.tertiaryText)
        }
    }

    var experienceStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepTitle(
                eyebrow: "训练条件",
                title: "你的训练经验",
                subtitle: "决定动作难度和起始重量。"
            )

            VStack(spacing: 10) {
                ForEach(Experience.allCases) { item in
                    choiceCard(
                        title: item.label,
                        detail: experienceDetail(item),
                        symbol: experienceSymbol(item),
                        selected: draft.experience == item
                    ) {
                        draft.experience = item
                    }
                }
            }
        }
    }

    var frequencyStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepTitle(
                eyebrow: "时间",
                title: "每周能练几次？",
                subtitle: "先选一个目前容易做到的频率，之后可以随时调整。"
            )

            VStack(spacing: 10) {
                ForEach([2, 3, 4, 5], id: \.self) { days in
                    choiceCard(
                        title: "每周 \(days) 次",
                        detail: days <= 3 ? "更容易坚持，适合起步" : "训练量更足，恢复要跟上",
                        symbol: days <= 3 ? "calendar" : "flame.fill",
                        selected: draft.weeklyDays == days
                    ) {
                        draft.weeklyDays = days
                        draft.split = days <= 3 ? .one : (days == 4 ? .three : .five)
                    }
                }
            }
        }
    }

    var durationStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepTitle(
                eyebrow: "时间",
                title: "单次能练多久？",
                subtitle: "不包含有氧；按真实可用时间选。"
            )

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                ForEach([20, 30, 45, 60, 90], id: \.self) { minutes in
                    Button {
                        Haptics.select()
                        draft.sessionMinutes = minutes
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(minutes)")
                                .font(AppType.numberSmall)
                                .foregroundStyle(Theme.ink)
                            Text("分钟")
                                .font(AppType.caption)
                                .foregroundStyle(Theme.secondaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(draft.sessionMinutes == minutes ? Theme.lime.opacity(0.20) : Theme.paper)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(
                                    draft.sessionMinutes == minutes ? Theme.ink : Theme.stroke,
                                    lineWidth: draft.sessionMinutes == minutes ? 1.8 : 1
                                )
                        }
                    }
                    .buttonStyle(CardPressStyle(scale: 0.985))
                }
            }
        }
    }
}
