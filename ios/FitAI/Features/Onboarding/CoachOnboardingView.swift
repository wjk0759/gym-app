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

    @State var draft = UserProfile()
    @State var step = 0
    @State var bodyType: BodyType?
    @State var bodyFatID: String?
    @State var focusAreas: Set<BodyFocusArea> = []
    @State var injuries: Set<String> = []
    @State var noInjuries = true
    @State var injuryNote = ""
    @State var location: TrainingLocation = .gym
    @State var welcomePhase = 0
    @State var showExitConfirm = false
    @State var alertMessage = ""
    @State var showAlert = false
    @FocusState var nameFocused: Bool

    @AppStorage("fitai_body_type") private var storedBodyType = ""
    @AppStorage("fitai_focus_areas") private var storedFocusAreas = ""

    let inputSteps = 14

    enum TrainingLocation: String, CaseIterable, Identifiable {
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
        .onChange(of: draft.sex) { _, sex in
            if let type = bodyType, !type.isAvailable(for: sex) {
                bodyType = nil
            }
            if let id = bodyFatID,
               !BodyFatOption.options(for: sex).contains(where: { $0.id == id }) {
                bodyFatID = nil
            }
        }
    }

    // MARK: - Actions

    func selectGoal(_ goal: GoalType) {
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

    func advance() {
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

    func save() {
        guard !draft.nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            alertMessage = "先填一个称呼，方便教练在对话里叫你。"
            showAlert = true
            step = 1
            return
        }
        if draft.equipment.isEmpty { draft.equipment = [.bodyweight] }

        draft.bodyFatPCT = bodyFatID.flatMap { id in
            BodyFatOption.options(for: draft.sex).first { $0.id == id }?.midpoint
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
            bodyFatID = BodyFatOption.options(for: draft.sex).min {
                abs($0.midpoint - draft.bodyFatPCT) < abs($1.midpoint - draft.bodyFatPCT)
            }?.id
            return
        }
        draft = store.profile
        if let type = BodyType(rawValue: storedBodyType), type.isAvailable(for: draft.sex) {
            bodyType = type
        }
        focusAreas = Set(
            storedFocusAreas
                .split(separator: ",")
                .compactMap { BodyFocusArea(rawValue: String($0)) }
        )
        bodyFatID = BodyFatOption.options(for: draft.sex).min {
            abs($0.midpoint - draft.bodyFatPCT) < abs($1.midpoint - draft.bodyFatPCT)
        }?.id
        noInjuries = draft.injuries.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

