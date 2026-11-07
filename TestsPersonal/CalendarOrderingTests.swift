import Foundation
import Combine
import EventKit

struct CalendarModel: Equatable { let id: String; let isReminder: Bool }
struct EventModel: Equatable { let id: String }
enum CalendarSelectionState { case all; case selected(Set<String>) }
enum CalendarPreferenceKey { case calendarSelectionState }
enum Defaults {
    static var value = CalendarSelectionState.all
    static subscript(_ key: CalendarPreferenceKey) -> CalendarSelectionState { get { value } set { value = newValue } }
}
@MainActor final class CalendarService {
    static var pending = [(Date, CheckedContinuation<[EventModel], Never>)]()
    func calendars() async -> [CalendarModel] { [CalendarModel(id: "calendar", isReminder: false)] }
    func requestAccess(to type: EKEntityType) async throws -> Bool { true }
    func setReminderCompleted(reminderID: String, completed: Bool) async {}
    func events(from start: Date, to end: Date, calendars: [String]) async -> [EventModel] {
        await withCheckedContinuation { CalendarService.pending.append((start, $0)) }
    }
}
@main struct CalendarOrderingTests {
    @MainActor static func main() async {
        let manager = CalendarManager.shared
        await Task.yield()
        let calendar = Calendar(identifier: .gregorian)
        let dayA = calendar.startOfDay(for: Date(timeIntervalSince1970: 1794000000))
        let dayB = calendar.date(byAdding: .day, value: 1, to: dayA)!
        manager.currentWeekStartDate = dayA
        let oldReminder = Task { await manager.setReminderCompleted(reminderID: "old", completed: true) }
        while CalendarService.pending.count < 1 { await Task.yield() }
        let newDay = Task { await manager.updateCurrentDate(dayB) }
        while CalendarService.pending.count < 2 { await Task.yield() }
        CalendarService.pending[1].1.resume(returning: [EventModel(id: "selected-day")]); await newDay.value
        precondition(manager.events == [EventModel(id: "selected-day")], "Selected day publishes its own events")
        CalendarService.pending[0].1.resume(returning: [EventModel(id: "stale-reminder-day")]); await oldReminder.value
        precondition(manager.currentWeekStartDate == dayB && manager.events == [EventModel(id: "selected-day")], "Late reminder completion cannot overwrite the selected day")
        print("Native CalendarManager request ordering: late reminder response ignored; selected day retained")
    }
}
