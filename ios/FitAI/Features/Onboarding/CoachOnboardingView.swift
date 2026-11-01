import SwiftUI
import UIKit

/// Coach-led, one-question-at-a-time onboarding.
///
/// The old flow was a five-page form. This version keeps the same data model
/// but gives each decision its own screen, uses visual references for body
/// shape and body fat, recommends a starting point and ends with a report
/// before the plan is generated.
struct CoachOnboardingView: View {
    @Environment(AppStore.self) private var store
    @Environment(AuthStore.self) private var auth

    @State private var draft = UserProfile()
    @State private var step = 0
    @State private var bodyType: BodyType?
    @State private var bodyFatID: String?
    @State private var focusAreas: Set<BodyFocusArea> = []
    @State private var injuries: Set<String> = []
    @State private var injuryNote = ""
    @State private var location: TrainingLocation = .gym
    @State private var welcomePhase = 0
    @State private var showExitConfirm = false
    @State private var alertMessage = ""
    @State private var showAlert = false
    @FocusState private var nameFocused: Bool

    @AppStorage("fitai_body_type") private var storedBodyType = ""
    @AppStorage("fitai_focus_areas") private var storedFocusAreas = ""

    private let inputSteps = 14

    private enum TrainingLocation: String, CaseIterable, Identifiable {
        case gym
        case home
        case hybrid

        var id: String { rawValue }

        var title: String {
            switch self {
            case .gym: return "健身房"
            case .home: return "居家"
            case .hybrid: return "两边都练"
            }
        }

        var detail: String {
            switch self {
            case .gym: return "器械更全，动作选择更多"
            case .home: return "省时间，先用手边的东西"
            case .hybrid: return "按当天条件灵活切换"
            }
        }

        var symbol: String {
            switch self {
            case .gym: return "building.2.fill"
            case .home: return "house.fill"
            case .hybrid: return "arrow.triangle.2.circlepath"
            }
        }

        var equipment: Set<Equipment> {
            switch self {
            case .gym: return [.bodyweight, .dumbbell, .barbell, .machine, .cable]
            case .home: return [.bodyweight, .dumbbell, .band]
            case .hybrid: return [.bodyweight, .dumbbell, .band, .machine]
            }
        }
    }

    var body: some View {
        ZStack {
            AppBackground()

            if step == 0 {
                welcome
                    .transition(.opacity)
            } else {
                mainFlow
                    .transition(.opacity)
            }
        }
        .alert("先确认一下", isPresented: $showAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .confirmationDialog(
            "退出登录？",
            isPresented: $showExitConfirm,
            titleVisibility: .visible
        ) {
            Button("退出登录", role: .destructive) {
                Task { await auth.logout() }
            }
            Button("继续填写", role: .cancel) {}
        } message: {
            Text("当前填写的内容还没有保存，退出后需要重新填写。")
        }
        .onAppear(perform: restoreDraft)
    }

    // MARK: - Welcome

    private var welcome: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 40)

            CoachMark(size: 76)
                .padding(.bottom, 28)

            VStack(spacing: 16) {
                if welcomePhase == 0 {
                    TypewriterText(
                        text: "您好，\n我是您的私教 L",
                        charDelay: .milliseconds(42),
                        hapticEvery: 3
                    ) {
                        guard welcomePhase == 0 else { return }
                        withAnimation(Motion.smooth) {
                            welcomePhase = 1
                        }
                    }
                    .font(AppType.editorial)
                    .tracking(-1.4)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.ink)
                } else {
                    TypewriterText(
                        text: "告诉我你的情况，\n我帮你生成起点报告",
                        charDelay: .milliseconds(30),
                        hapticEvery: 4
                    )
                    .font(AppType.hero)
                    .tracking(-0.8)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.ink)
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: 330)

            Spacer(minLength: 30)

            Text("不是体检，是决定接下来 4 周怎么练。")
                .font(AppType.caption)
                .foregroundStyle(Theme.tertiaryText)
                .multilineTextAlignment(.center)
                .padding(.bottom, 18)

            Button {
                Haptics.impact(.light)
                withAnimation(Motion.smooth) {
                    step = 1
                }
            } label: {
                Text("开始")
            }
            .buttonStyle(PrimaryButtonStyle())
            .opacity(welcomePhase == 0 ? 0.42 : 1)
            .disabled(welcomePhase == 0)
            .padding(.horizontal, 26)

            Button("退出登录") {
                showExitConfirm = true
            }
            .font(AppType.caption)
            .foregroundStyle(Theme.tertiaryText)
            .buttonStyle(SubtlePressStyle())
            .padding(.top, 14)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppBackground())
        .onTapGesture {
            if welcomePhase == 0 {
                withAnimation(Motion.quick) { welcomePhase = 1 }
            }
        }
    }

    // MARK: - Main flow

    private var mainFlow: some View {
        VStack(spacing: 0) {
            header
            AppScrollView {
                stepContent
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 22)
            }
        }
        .background(AppBackground())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomBar
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Button {
                    Haptics.tap()
                    if step > 1 {
                        withAnimation(Motion.quick) { step -= 1 }
                    } else {
                        withAnimation(Motion.quick) { step = 0 }
                    }
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 38, height: 38)
                        .background(Theme.paper, in: Circle())
                        .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 1))
                }
                .buttonStyle(SubtlePressStyle(scale: 0.94))

                Spacer()

                Text("\(min(step, inputSteps)) / \(inputSteps)")
                    .font(AppType.micro)
                    .foregroundStyle(Theme.secondaryText)
                    .monospacedDigit()

                Button {
                    showExitConfirm = true
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.tertiaryText)
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(SubtlePressStyle())
                .accessibilityLabel("退出登录")
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.stroke)
                    Capsule()
                        .fill(Theme.cobalt)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 2)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private var progress: CGFloat {
        guard step > 0 else { return 0 }
        return min(1, CGFloat(step - 1) / CGFloat(max(1, inputSteps - 1)))
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 1: nameStep
        case 2: sexStep
        case 3: ageHeightStep
        case 4: weightStep
        case 5: bodyFatStep
        case 6: bodyTypeStep
        case 7: goalStep
        case 8: focusStep
        case 9: injuryStep
        case 10: locationStep
        case 11: equipmentStep
        case 12: experienceStep
        case 13: frequencyStep
        case 14: durationStep
        default: reportStep
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            InkDivider()
            HStack(spacing: 10) {
                if step > 1 && step <= inputSteps {
                    Button("上一步") {
                        withAnimation(Motion.quick) { step -= 1 }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .frame(maxWidth: 108)
                }

                Button {
                    if step == inputSteps + 1 {
                        save()
                    } else {
                        advance()
                    }
                } label: {
                    Text(step == inputSteps + 1 ? "生成我的计划" : "下一步")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
        .background(Theme.chrome)
    }

    // MARK: - Steps

    private var nameStep: some View {
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

    private var sexStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            stepTitle(
                eyebrow: "身体基线",
                title: "你的性别是？",
                subtitle: "用于估算基础代谢和训练负荷。"
            )

            HStack(spacing: 12) {
                ForEach(Sex.allCases) { sex in
                    sexCard(sex)
                }
            }
        }
    }

    private var ageHeightStep: some View {
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

    private var weightStep: some View {
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

    private var bodyFatStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepTitle(
                eyebrow: "身体基线",
                title: "哪个体脂范围更像你？",
                subtitle: "看图和自己的腰腹、手臂线条对比，不用知道精确数字。"
            )

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                spacing: 10
            ) {
                ForEach(BodyFatOption.all) { option in
                    BodyFatCard(option: option, selected: bodyFatID == option.id) {
                        bodyFatID = option.id
                        draft.bodyFatPCT = option.midpoint
                    }
                }
            }

            Button {
                let fallback = BodyFatOption.all.min {
                    abs($0.midpoint - draft.bodyFatPCT) < abs($1.midpoint - draft.bodyFatPCT)
                } ?? BodyFatOption.all[2]
                bodyFatID = fallback.id
                draft.bodyFatPCT = fallback.midpoint
                advance()
            } label: {
                Label("不确定，按常见范围估算", systemImage: "sparkles")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.cobalt)
            }
            .buttonStyle(SubtlePressStyle())
        }
    }

    private var bodyTypeStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepTitle(
                eyebrow: "身体基线",
                title: "你更接近哪种体型？",
                subtitle: "选最像的就好，体型只用来建议训练重点。"
            )

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                ForEach(BodyType.allCases) { type in
                    BodyTypeCard(
                        type: type,
                        selected: bodyType == type,
                        recommended: type == recommendedBodyType
                    ) {
                        bodyType = type
                        if focusAreas.isEmpty {
                            focusAreas = recommendedFocus
                        }
                    }
                }
            }
        }
    }

    private var goalStep: some View {
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

    private var focusStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepTitle(
                eyebrow: "训练重点",
                title: "想重点改善哪里？",
                subtitle: "可以多选；不选就是全身均衡。"
            )

            BodyFocusMap(selected: $focusAreas, recommended: recommendedFocus)

            Button {
                focusAreas.removeAll()
            } label: {
                Label("均衡练全身", systemImage: "circle.grid.cross")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.cobalt)
            }
            .buttonStyle(SubtlePressStyle())
        }
    }

    private var injuryStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepTitle(
                eyebrow: "安全",
                title: "有需要避开的伤病吗？",
                subtitle: "有伤病不会阻止你练，只会让计划绕开风险动作。"
            )

            Button {
                Haptics.select()
                injuries.removeAll()
                injuryNote = ""
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("没有任何伤病")
                            .font(AppType.headline)
                            .foregroundStyle(Theme.ink)
                        Text("计划按常规动作安排")
                            .font(AppType.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }
                    Spacer()
                    Image(systemName: injuries.isEmpty ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(injuries.isEmpty ? Theme.cobalt : Theme.tertiaryText)
                }
                .padding(16)
                .background(Theme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(injuries.isEmpty ? Theme.cobalt : Theme.stroke, lineWidth: injuries.isEmpty ? 1.8 : 1)
                }
            }
            .buttonStyle(CardPressStyle(scale: 0.985))

            if !injuries.isEmpty {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                    spacing: 8
                ) {
                    ForEach(injuryOptions, id: \.self) { injury in
                        Button {
                            Haptics.select()
                            if injuries.contains(injury) {
                                injuries.remove(injury)
                            } else {
                                injuries.insert(injury)
                            }
                        } label: {
                            TagChip(text: injury, selected: injuries.contains(injury))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SubtlePressStyle(scale: 0.96))
                    }
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
            } else {
                Text("如果要添加伤病，先点掉“没有任何伤病”。")
                    .font(AppType.micro)
                    .foregroundStyle(Theme.tertiaryText)
            }
        }
    }

    private var locationStep: some View {
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

    private var equipmentStep: some View {
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

    private var experienceStep: some View {
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

    private var frequencyStep: some View {
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

    private var durationStep: some View {
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

    // MARK: - Report

    private var reportStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            EditorialHeader(
                eyebrow: "起点报告",
                title: "先把起点看清楚",
                subtitle: "这不是体检，是接下来 4 周的训练依据。"
            )

            reportIdentityCard
            reportMetricsCard
            reportRecommendationCard
            reportActionCard

            Text("数据只用于生成训练和饮食建议；伤病与疼痛会被安全规则拦截。")
                .font(AppType.micro)
                .foregroundStyle(Theme.tertiaryText)
                .padding(.bottom, 6)
        }
    }

    private var reportIdentityCard: some View {
        HStack(alignment: .center, spacing: 16) {
            if let bodyType {
                BodySilhouette(
                    type: bodyType,
                    fill: Theme.cobalt.opacity(0.12),
                    stroke: Theme.cobalt,
                    lineWidth: 1.2
                )
                .frame(width: 78, height: 150)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(draft.nickname.isEmpty ? "你的起点" : draft.nickname)
                    .font(AppType.title)
                    .foregroundStyle(Theme.ink)
                Text("\(draft.age) 岁 · \(draft.sex.label) · \(String(format: "%.0f", draft.heightCM)) cm · \(String(format: "%.1f", draft.weightKG)) kg")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
                if let bodyType {
                    Text("\(bodyType.label) · \(bodyType.detail)")
                        .font(AppType.micro)
                        .foregroundStyle(Theme.cobalt)
                }
                Text("\(draft.weeklyDays) 练/周 · \(draft.sessionMinutes) 分钟/次")
                    .font(AppType.micro)
                    .foregroundStyle(Theme.tertiaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }

    private var reportMetricsCard: some View {
        VStack(spacing: 14) {
            HStack {
                Text("身体数据")
                    .font(AppType.headline)
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("估算")
                    .font(AppType.micro)
                    .foregroundStyle(Theme.tertiaryText)
            }

            HStack(spacing: 8) {
                EditorialMetric(title: "基础代谢", value: "\(bmr)", unit: "kcal", accent: Theme.cobalt)
                EditorialMetric(title: "BMI", value: String(format: "%.1f", draft.bmi), accent: Theme.lime)
                EditorialMetric(title: "体脂", value: String(format: "%.0f", draft.bodyFatPCT), unit: "%", accent: Theme.coral)
            }

            VStack(spacing: 8) {
                gaugeRow(
                    title: "体脂",
                    value: String(format: "%.0f%%", draft.bodyFatPCT),
                    progress: min(1, draft.bodyFatPCT / 45),
                    color: Theme.coral,
                    left: "偏低",
                    right: "偏高"
                )
                gaugeRow(
                    title: "BMI",
                    value: String(format: "%.1f", draft.bmi),
                    progress: min(1, draft.bmi / 35),
                    color: Theme.cobalt,
                    left: "偏低",
                    right: "偏高"
                )
            }
        }
        .padding(16)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }

    private var reportRecommendationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                RecommendationBadge(
                    text: draft.goalType == recommendedGoal
                        ? "和你的选择一致"
                        : "教练建议 \(recommendedGoal.label)"
                )
                Spacer()
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(draft.goalType.label)
                    .font(AppType.hero)
                    .foregroundStyle(Theme.ink)
                Text("你选的主目标")
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
            }

            Text(draft.goalType.detail)
                .font(AppType.body)
                .foregroundStyle(Theme.secondaryText)

            if draft.goalType != recommendedGoal {
                Text("如果愿意，也可以改成 \(recommendedGoal.label)：\(recommendedGoal.detail)")
                    .font(AppType.micro)
                    .foregroundStyle(Theme.cobalt)
                    .fixedSize(horizontal: false, vertical: true)
            }

            InkDivider()

            HStack(spacing: 8) {
                EditorialMetric(title: "每周", value: "\(draft.weeklyDays)", unit: "次")
                EditorialMetric(title: "每次", value: "\(draft.sessionMinutes)", unit: "分钟")
                EditorialMetric(
                    title: "热量",
                    value: "\(DietPlanner.targets(profile: draft).kcal)",
                    unit: "kcal"
                )
            }
        }
        .padding(16)
        .background(Theme.lime.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.ink.opacity(0.18), lineWidth: 1)
        }
    }

    private var reportActionCard: some View {
        let focusText = focusAreas.isEmpty ? "全身均衡" : focusAreas.map(\.label).joined(separator: "、")
        let equipmentText = draft.equipment.map(\.label).sorted().joined(separator: "、")
        let safetyText = injuries
            .union(injuryNote.isEmpty ? [String]() : [injuryNote])
            .filter { !$0.isEmpty }
            .joined(separator: "、")

        return VStack(alignment: .leading, spacing: 10) {
            Text("我会先这样安排")
                .font(AppType.headline)
                .foregroundStyle(Theme.ink)

            if let bodyType {
                actionLine("训练重点：\(focusText)，计划会优先安排")
                actionLine("体型参考：\(bodyType.label)，报告会记录这个重点")
            } else {
                actionLine("训练重点：\(focusText)")
            }
            actionLine("器械：\(equipmentText)")
            if !safetyText.isEmpty {
                actionLine("安全限制：\(safetyText)")
            }
            actionLine("计划会在生成后进入 Today，你可以随时找教练改。")
        }
        .padding(16)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }

    // MARK: - Components

    private func stepTitle(eyebrow: String, title: String, subtitle: String) -> some View {
        EditorialHeader(eyebrow: eyebrow, title: title, subtitle: subtitle)
    }

    private func sexCard(_ sex: Sex) -> some View {
        let selected = draft.sex == sex
        return Button {
            Haptics.select()
            draft.sex = sex
        } label: {
            VStack(spacing: 10) {
                BodySilhouette(
                    type: .rectangle,
                    fill: selected ? Theme.cobalt.opacity(0.16) : Theme.ink.opacity(0.06),
                    stroke: selected ? Theme.cobalt : Theme.ink.opacity(0.28),
                    lineWidth: selected ? 2 : 1
                )
                .frame(height: 130)
                .padding(.horizontal, 12)

                Text(sex.label)
                    .font(AppType.title)
                    .foregroundStyle(Theme.ink)
            }
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(selected ? Theme.cobalt.opacity(0.06) : Theme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(selected ? Theme.cobalt : Theme.stroke, lineWidth: selected ? 2 : 1)
            }
        }
        .buttonStyle(CardPressStyle(scale: 0.985))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func valueControl(
        title: String,
        value: String,
        unit: String,
        decrement: @escaping () -> Void,
        increment: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(AppType.numberSmall)
                        .foregroundStyle(Theme.ink)
                        .monospacedDigit()
                    Text(unit)
                        .font(AppType.micro)
                        .foregroundStyle(Theme.tertiaryText)
                }
            }
            Spacer()
            Button(action: decrement) {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 38, height: 38)
                    .background(Theme.paper, in: Circle())
                    .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 1))
            }
            .buttonStyle(SubtlePressStyle(scale: 0.92))
            Button(action: increment) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 38, height: 38)
                    .background(Theme.lime, in: Circle())
                    .overlay(Circle().strokeBorder(Theme.ink.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(SubtlePressStyle(scale: 0.92))
        }
        .padding(16)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 1)
        }
    }

    private func choiceCard(
        title: String,
        detail: String,
        symbol: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.select()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(selected ? Theme.onAccent : Theme.cobalt)
                    .frame(width: 38, height: 38)
                    .background(selected ? Theme.cobalt : Theme.cobalt.opacity(0.08), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(AppType.headline)
                        .foregroundStyle(Theme.ink)
                    Text(detail)
                        .font(AppType.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(selected ? Theme.cobalt : Theme.tertiaryText)
            }
            .padding(14)
            .background(selected ? Theme.cobalt.opacity(0.055) : Theme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(selected ? Theme.cobalt : Theme.stroke, lineWidth: selected ? 1.8 : 1)
            }
        }
        .buttonStyle(CardPressStyle(scale: 0.985))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func goalCard(_ goal: GoalType) -> some View {
        let selected = draft.goalType == goal
        return Button {
            selectGoal(goal)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: goalSymbol(goal))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(selected ? Theme.onAccent : Theme.cobalt)
                    .frame(width: 48, height: 48)
                    .background(selected ? Theme.cobalt : Theme.cobalt.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(goal.label)
                            .font(AppType.headline)
                            .foregroundStyle(Theme.ink)
                        if goal == recommendedGoal {
                            RecommendationBadge(text: "建议")
                        }
                    }
                    Text(goal.detail)
                        .font(AppType.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(selected ? Theme.cobalt : Theme.tertiaryText)
            }
            .padding(14)
            .background(selected ? Theme.cobalt.opacity(0.055) : Theme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(selected ? Theme.cobalt : Theme.stroke, lineWidth: selected ? 1.8 : 1)
            }
        }
        .buttonStyle(CardPressStyle(scale: 0.985))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func equipmentCard(_ item: Equipment) -> some View {
        let selected = draft.equipment.contains(item)
        return Button {
            Haptics.select()
            if selected {
                if draft.equipment.count > 1 { draft.equipment.remove(item) }
            } else {
                draft.equipment.insert(item)
            }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: item.symbolName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(selected ? Theme.ink : Theme.secondaryText)
                    .frame(width: 34, height: 34)
                    .background(selected ? Theme.lime : Theme.surfaceStrong, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                Text(item.label)
                    .font(AppType.caption.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }
            }
            .padding(10)
            .background(selected ? Theme.lime.opacity(0.18) : Theme.paper)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(selected ? Theme.ink.opacity(0.65) : Theme.stroke, lineWidth: selected ? 1.4 : 1)
            }
        }
        .buttonStyle(CardPressStyle(scale: 0.985))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func gaugeRow(
        title: String,
        value: String,
        progress: Double,
        color: Color,
        left: String,
        right: String
    ) -> some View {
        VStack(spacing: 5) {
            HStack {
                Text(title)
                    .font(AppType.caption)
                    .foregroundStyle(Theme.secondaryText)
                Spacer()
                Text(value)
                    .font(AppType.caption.weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.stroke)
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * max(0.02, min(1, progress)))
                }
            }
            .frame(height: 5)
            HStack {
                Text(left)
                Spacer()
                Text(right)
            }
            .font(AppType.micro)
            .foregroundStyle(Theme.tertiaryText)
        }
    }

    private func actionLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Circle()
                .fill(Theme.lime)
                .frame(width: 6, height: 6)
                .padding(.top, 5)
            Text(text)
                .font(AppType.caption)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Derived values

    private var bmr: Int {
        let base = 10 * draft.weightKG + 6.25 * draft.heightCM - 5 * Double(draft.age)
        return Int((base + (draft.sex == .male ? 5 : -161)).rounded())
    }

    private var recommendedGoal: GoalType {
        if draft.bmi >= 27 || draft.bodyFatPCT >= 30 { return .loseFat }
        if draft.bmi < 20 { return .buildMuscle }
        if bodyType == .invertedTriangle || bodyType == .rectangle { return .buildMuscle }
        return .recomp
    }

    private var recommendedBodyType: BodyType {
        if let bodyType { return bodyType }
        if draft.bmi >= 27 || draft.bodyFatPCT >= 29 { return .apple }
        if draft.bmi < 20 { return .rectangle }
        return .rectangle
    }

    private var recommendedFocus: Set<BodyFocusArea> {
        switch bodyType ?? .rectangle {
        case .apple: return [.core, .legs]
        case .pear: return [.glutes, .legs]
        case .invertedTriangle: return [.back, .shoulders]
        case .rectangle: return [.shoulders, .glutes]
        case .hourglass: return [.core, .glutes]
        }
    }

    private var injuryOptions: [String] {
        ["膝关节", "腰背", "肩颈", "心血管", "孕期/术后"]
    }

    private func experienceDetail(_ item: Experience) -> String {
        switch item {
        case .beginner: return "还在学动作，先建立习惯"
        case .intermediate: return "练过一段时间，动作基本稳定"
        case .advanced: return "训练多年，能自己安排强度"
        }
    }

    private func experienceSymbol(_ item: Experience) -> String {
        switch item {
        case .beginner: return "leaf.fill"
        case .intermediate: return "chart.line.uptrend.xyaxis"
        case .advanced: return "bolt.fill"
        }
    }

    private func goalSymbol(_ goal: GoalType) -> String {
        switch goal {
        case .loseFat: return "flame.fill"
        case .buildMuscle: return "dumbbell.fill"
        case .recomp: return "arrow.triangle.2.circlepath"
        case .endurance: return "figure.run"
        }
    }

    // MARK: - Actions

    private func selectGoal(_ goal: GoalType) {
        Haptics.select()
        draft.goalType = goal
        switch goal {
        case .loseFat:
            draft.targetWeightKG = max(40, draft.weightKG - 4)
        case .buildMuscle:
            draft.targetWeightKG = draft.weightKG + 3
        case .recomp, .endurance:
            draft.targetWeightKG = draft.weightKG
        }
    }

    private func advance() {
        switch step {
        case 1:
            let name = draft.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else {
                alertMessage = "先填一个称呼，方便教练在对话里叫你。"
                showAlert = true
                return
            }
            draft.nickname = name
            nameFocused = false
        case 11:
            if draft.equipment.isEmpty { draft.equipment = [.bodyweight] }
        case inputSteps:
            step = inputSteps + 1
            return
        default:
            break
        }

        guard step < inputSteps else { return }
        withAnimation(Motion.smooth) {
            step += 1
        }
    }

    private func save() {
        guard !draft.nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            alertMessage = "先填一个称呼，方便教练在对话里叫你。"
            showAlert = true
            step = 1
            return
        }
        if draft.equipment.isEmpty { draft.equipment = [.bodyweight] }

        draft.bodyFatPCT = bodyFatID.flatMap { id in
            BodyFatOption.all.first { $0.id == id }?.midpoint
        } ?? draft.bodyFatPCT

        var injuryText = injuries.sorted().joined(separator: "、")
        let note = injuryNote.trimmingCharacters(in: .whitespacesAndNewlines)
        if !note.isEmpty {
            injuryText = injuryText.isEmpty ? note : "\(injuryText)；\(note)"
        }
        draft.injuries = injuryText
        draft.split = draft.weeklyDays <= 3 ? .one : (draft.weeklyDays == 4 ? .three : .five)

        storedBodyType = bodyType?.rawValue ?? ""
        storedFocusAreas = focusAreas.map(\.rawValue).joined(separator: ",")

        store.completeOnboarding(draft)
    }

    private func restoreDraft() {
        guard !store.profile.nickname.isEmpty else {
            draft.equipment = [.bodyweight, .dumbbell]
            bodyFatID = BodyFatOption.all.min {
                abs($0.midpoint - draft.bodyFatPCT) < abs($1.midpoint - draft.bodyFatPCT)
            }?.id
            return
        }
        draft = store.profile
        if let type = BodyType(rawValue: storedBodyType) {
            bodyType = type
        }
        focusAreas = Set(
            storedFocusAreas
                .split(separator: ",")
                .compactMap { BodyFocusArea(rawValue: String($0)) }
        )
        bodyFatID = BodyFatOption.all.min {
            abs($0.midpoint - draft.bodyFatPCT) < abs($1.midpoint - draft.bodyFatPCT)
        }?.id
    }
}


