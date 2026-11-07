import Foundation
@main struct AgendaClockTests {
    static func main() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let before = Date(timeIntervalSince1970: 1794095970)
        let after = before.addingTimeInterval(120)
        let today = cal.startOfDay(for: before)
        let tomorrow = cal.startOfDay(for: after)
        func check(_ result: Bool, _ message: String) { guard result else { fputs("FAIL: \(message)\n",stderr);exit(1) }; print("PASS: \(message)") }
        check(today != tomorrow, "fixture crosses midnight")
        check(PersonalAgendaClock.selectedDay(after: after, previousNow: before, selectedDay: today, calendar: cal) == tomorrow, "today follows midnight")
        let manualDay = cal.date(byAdding: .day, value: 3, to: today)!
        check(PersonalAgendaClock.selectedDay(after: after, previousNow: before, selectedDay: manualDay, calendar: cal) == manualDay, "browsing another day survives midnight")
        check(PersonalAgendaClock.selectedDay(after: before.addingTimeInterval(5), previousNow: before, selectedDay: today, calendar: cal) == today, "same-day tick keeps selected date")
    }
}
