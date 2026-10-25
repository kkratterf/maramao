import Foundation
import MaramaoCore

/// Keeps the daily stats (`PomodoroStats`) in UserDefaults as JSON and publishes changes to the UI.
@MainActor
final class StatsStore: ObservableObject {
    static let shared = StatsStore()

    @Published private(set) var stats: PomodoroStats

    private let defaults: UserDefaults
    private let calendar: Calendar
    private static let key = "stats.v1"

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
        if let data = defaults.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(PomodoroStats.self, from: data) {
            stats = decoded
        } else {
            stats = PomodoroStats()
        }
    }

    // MARK: - Recording

    func recordWork(completed: Bool, focusSeconds: TimeInterval) {
        stats.recordWork(completed: completed, focusSeconds: focusSeconds, at: Date(), calendar: calendar)
        save()
    }

    func recordBreak(completed: Bool, mode: BreakModeID) {
        stats.recordBreak(completed: completed, mode: mode.rawValue, at: Date(), calendar: calendar)
        save()
    }

    func reset() {
        stats.reset()
        save()
    }

    // MARK: - Reading

    var today: DayStats { stats.day(Date(), calendar: calendar) }
    var streak: Int { stats.streak(endingAt: Date(), calendar: calendar) }
    var todayLine: String { StatsText.todayLine(today: today, streak: streak) }

    func lastDays(_ count: Int) -> [DayStats] {
        stats.lastDays(count, endingAt: Date(), calendar: calendar)
    }

    func total(ofLast count: Int) -> DayStats {
        stats.total(ofLast: count, endingAt: Date(), calendar: calendar)
    }

    /// Short weekday label ("lun", "mar", ...) for a `yyyy-MM-dd` key.
    func weekdayLabel(for dayKey: String) -> String {
        let parts = dayKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3,
              let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "it")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    private func save() {
        stats.prune(now: Date(), calendar: calendar)
        if let data = try? JSONEncoder().encode(stats) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
