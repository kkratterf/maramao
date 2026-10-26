import Foundation

/// How far back the stats charts look.
public enum StatsRange: String, Codable, CaseIterable, Sendable {
    case week
    case month

    /// How many days the range covers, today included.
    public var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        }
    }
}

extension PomodoroStats {
    /// The day with most pomodori in the last `count` days, or nil when there are none.
    /// Ties go to the most recent day.
    public func bestDay(ofLast count: Int, endingAt date: Date, calendar: Calendar = .current) -> DayStats? {
        var best: DayStats?
        for day in lastDays(count, endingAt: date, calendar: calendar) where day.workSessions > 0 {
            if let current = best, day.workSessions < current.workSessions { continue }
            best = day
        }
        return best
    }

    /// Days with at least one pomodoro in the last `count` days.
    public func activeDays(ofLast count: Int, endingAt date: Date, calendar: Calendar = .current) -> Int {
        lastDays(count, endingAt: date, calendar: calendar).filter { $0.workSessions > 0 }.count
    }
}

/// Turns the history into a CSV file the user can open in Numbers or Excel.
/// Column names stay in English: they are data, not UI copy.
public enum StatsCSV {
    public static let header = "day,pomodori,focus_minutes,breaks_completed,breaks_skipped,breaks_snoozed,emergency_exits"

    /// Suggested file name, e.g. `maramao-stats-2026-10-26.csv`.
    public static func fileName(for date: Date, calendar: Calendar = .current) -> String {
        "maramao-stats-\(PomodoroStats.key(for: date, calendar: calendar)).csv"
    }

    /// One line per recorded day, oldest first, with a trailing newline.
    public static func export(_ stats: PomodoroStats) -> String {
        var lines = [header]
        for key in stats.days.keys.sorted() {
            guard let day = stats.days[key] else { continue }
            lines.append([
                day.day,
                "\(day.workSessions)",
                "\(day.focusMinutes)",
                "\(day.breaksCompleted)",
                "\(day.breaksSkipped)",
                "\(day.breaksSnoozed)",
                "\(day.emergencyExits)",
            ].joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
