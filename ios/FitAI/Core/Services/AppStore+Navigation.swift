import Foundation

extension AppStore {
    /// Switch to the Record tab and focus a specific plan day.
    func openRecord(for date: Date) {
        pendingRecordDate = Calendar.current.startOfDay(for: date)
        selectedTab = 1
    }
}
