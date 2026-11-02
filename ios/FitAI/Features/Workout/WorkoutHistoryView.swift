import SwiftUI

/// A month-by-month training ledger.
///
/// The record tab answers “what is this month?”. This screen answers “what did
/// I actually lift?”: one month cover, one date grid, and the sessions that
/// belong to the selected day. It reads like the next page of the same journal.
struct WorkoutHistoryView: View {
    @Environment(AppStore.self) var store
    @Environment(\.dismiss) var dismiss

    @State var month = Date()
    @State var selectedDate: Date?
    @State var selectedSession: WorkoutSession?

    init() {}

    var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.locale = Locale(identifier: "zh_CN")
        value.firstWeekday = 2
        return value
    }

    var monthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: month)) ?? month
    }

    var monthSessions: [WorkoutSession] {
        guard let interval = calendar.dateInterval(of: .month, for: monthStart) else {
            return []
        }
        return store.sessions.filter { interval.contains($0.date) }
    }

    var isCurrentMonth: Bool {
        calendar.isDate(monthStart, equalTo: Date(), toGranularity: .month)
    }

    func visibleSessions(in sessions: [WorkoutSession]) -> [WorkoutSession] {
        let list = selectedDate.map { date in
            sessions.filter { calendar.isDate($0.date, inSameDayAs: date) }
        } ?? sessions
        return list.sorted { $0.date > $1.date }
    }

    var body: some View {
        let sessions = monthSessions

        AppScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                monthCover(sessions)
                calendarCard(sessions)
                sessionsCard(sessions)
                footer
            }
            .appPagePadding()
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(AppBackground())
        .navigationTitle("训练记录")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedSession) { session in
            WorkoutDetailView(session: session)
        }
    }
}
