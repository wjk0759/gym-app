import SwiftUI

enum AppTab: Int {
    case today = 0
    case record = 1
    case coach = 2
    case discover = 3
    case profile = 4
}

/// Root-level pushes shared by the tab stacks.
///
/// Value-based links are required for `NavigationStack(path:)` to track the
/// route. When the user switches tabs we clear the path, so a detail page never
/// survives a tab switch while the root scroll state stays intact.
enum TabRoute: Hashable {
    case progressOverview
    case workoutHistory
    case nutrition(Date?)
    case profileEdit
    case settings
    case equipmentPicker
    case equipmentLibrary
}

extension View {
    func appTabDestinations() -> some View {
        navigationDestination(for: TabRoute.self) { route in
            switch route {
            case .progressOverview:
                ProgressOverviewView()
            case .workoutHistory:
                WorkoutHistoryView()
            case .nutrition(let date):
                NutritionView(date: date ?? Date())
            case .profileEdit:
                ProfileEditView()
            case .settings:
                SettingsView()
            case .equipmentPicker:
                EquipmentPickerView()
            case .equipmentLibrary:
                EquipmentLibraryView()
            }
        }
    }
}
