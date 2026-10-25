import SwiftUI

/// 训练 Tab：把执行（今日）、编排（计划）、反思（复盘）收进同一处，
/// 底部 Tab 不再为“今日”和“计划”各占一个位置。
struct TrainingHubView: View {
    @State private var section: TrainingSection = .today

    init() {}

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("训练视图", selection: $section) {
                    ForEach(TrainingSection.allCases) { item in
                        Text(item.label).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 4)
                .accessibilityLabel("切换今日、计划或复盘")

                Group {
                    switch section {
                    case .today:
                        HomeView(embedded: true)
                    case .plan:
                        PlanHomeView(embedded: true)
                    case .review:
                        TrainingReviewView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("训练")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

enum TrainingSection: String, CaseIterable, Identifiable {
    case today
    case plan
    case review

    var id: String { rawValue }

    var label: String {
        switch self {
        case .today: return "今日"
        case .plan: return "计划"
        case .review: return "复盘"
        }
    }
}
