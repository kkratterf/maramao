import Foundation

/// How many breaks of one mode were respected or skipped.
public struct BreakModeCounts: Codable, Equatable, Sendable {
    public var completed: Int
    public var skipped: Int

    public init(completed: Int = 0, skipped: Int = 0) {
        self.completed = completed
        self.skipped = skipped
    }

    public var total: Int { completed + skipped }
}

/// What happened on one calendar day.
public struct DayStats: Codable, Equatable, Sendable {
    /// The day as `yyyy-MM-dd` in the calendar used to record it.
    public var day: String
    /// Work sessions that ran until the timer ended.
    public var workSessions: Int
    /// Seconds of focus, including work sessions ended early.
    public var focusSeconds: TimeInterval
    public var breaksCompleted: Int
    public var breaksSkipped: Int
    /// Break counts per break mode, keyed by the mode's raw value.
    public var modes: [String: BreakModeCounts]

    public init(
        day: String,
        workSessions: Int = 0,
        focusSeconds: TimeInterval = 0,
        breaksCompleted: Int = 0,
        breaksSkipped: Int = 0,
        modes: [String: BreakModeCounts] = [:]
    ) {
        self.day = day
        self.workSessions = workSessions
        self.focusSeconds = focusSeconds
        self.breaksCompleted = breaksCompleted
        self.breaksSkipped = breaksSkipped
        self.modes = modes
    }

    public var breaksTotal: Int { breaksCompleted + breaksSkipped }
    public var focusMinutes: Int { Int((focusSeconds / 60).rounded(.down)) }
    public var isEmpty: Bool { workSessions == 0 && focusSeconds == 0 && breaksTotal == 0 }

    /// Sums several days into one (the result keeps `day` of the receiver).
    public func adding(_ other: DayStats) -> DayStats {
        var result = self
        result.workSessions += other.workSessions
        result.focusSeconds += other.focusSeconds
        result.breaksCompleted += other.breaksCompleted
        result.breaksSkipped += other.breaksSkipped
        for (mode, counts) in other.modes {
            var mine = result.modes[mode] ?? BreakModeCounts()
            mine.completed += counts.completed
            mine.skipped += counts.skipped
            result.modes[mode] = mine
        }
        return result
    }
}

/// Daily history of pomodori and breaks. Pure value type: the app persists it as JSON.
public struct PomodoroStats: Codable, Equatable, Sendable {
    /// Days with at least one event, keyed by `yyyy-MM-dd`.
    public private(set) var days: [String: DayStats]
    /// How many days of history to keep.
    public static let retentionDays = 400

    public init(days: [String: DayStats] = [:]) {
        self.days = days
    }

    // MARK: - Recording

    /// A work session ended. `completed` is true when the timer ran out, false when the user
    /// ended it early ("Pausa gatto ora"): only completed sessions count as pomodori, but the
    /// focused time counts either way.
    public mutating func recordWork(completed: Bool, focusSeconds: TimeInterval, at date: Date, calendar: Calendar = .current) {
        update(date, calendar: calendar) { day in
            if completed { day.workSessions += 1 }
            day.focusSeconds += max(0, focusSeconds)
        }
    }

    /// A break ended: `completed` when the timer ran out, false when it was skipped or abandoned.
    public mutating func recordBreak(completed: Bool, mode: String, at date: Date, calendar: Calendar = .current) {
        update(date, calendar: calendar) { day in
            var counts = day.modes[mode] ?? BreakModeCounts()
            if completed {
                day.breaksCompleted += 1
                counts.completed += 1
            } else {
                day.breaksSkipped += 1
                counts.skipped += 1
            }
            day.modes[mode] = counts
        }
    }

    public mutating func reset() {
        days = [:]
    }

    /// Drops days older than `retentionDays` before `now`.
    public mutating func prune(now: Date, calendar: Calendar = .current) {
        guard let cutoff = calendar.date(byAdding: .day, value: -(Self.retentionDays - 1), to: calendar.startOfDay(for: now)) else { return }
        let cutoffKey = Self.key(for: cutoff, calendar: calendar)
        // Keys are zero-padded `yyyy-MM-dd`, so string order is date order.
        days = days.filter { $0.key >= cutoffKey }
    }

    // MARK: - Reading

    public func day(_ date: Date, calendar: Calendar = .current) -> DayStats {
        let key = Self.key(for: date, calendar: calendar)
        return days[key] ?? DayStats(day: key)
    }

    /// The last `count` days up to and including `date`, oldest first, empty days included.
    public func lastDays(_ count: Int, endingAt date: Date, calendar: Calendar = .current) -> [DayStats] {
        guard count > 0 else { return [] }
        let today = calendar.startOfDay(for: date)
        var result: [DayStats] = []
        for offset in stride(from: count - 1, through: 0, by: -1) {
            guard let d = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            result.append(day(d, calendar: calendar))
        }
        return result
    }

    /// Totals of the last `count` days up to and including `date`.
    public func total(ofLast count: Int, endingAt date: Date, calendar: Calendar = .current) -> DayStats {
        let start = DayStats(day: Self.key(for: date, calendar: calendar))
        return lastDays(count, endingAt: date, calendar: calendar).reduce(start) { $0.adding($1) }
    }

    /// Consecutive days with at least one pomodoro, ending today. A day without pomodori yet
    /// does not break the streak until it is over, so it counts from yesterday then.
    public func streak(endingAt date: Date, calendar: Calendar = .current) -> Int {
        var cursor = calendar.startOfDay(for: date)
        if day(cursor, calendar: calendar).workSessions == 0 {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }
        var count = 0
        while day(cursor, calendar: calendar).workSessions > 0 {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
            if count > Self.retentionDays { break }
        }
        return count
    }

    // MARK: - Helpers

    /// `yyyy-MM-dd` of the day containing `date` in `calendar` (and its time zone).
    public static func key(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private mutating func update(_ date: Date, calendar: Calendar, _ change: (inout DayStats) -> Void) {
        let key = Self.key(for: date, calendar: calendar)
        var day = days[key] ?? DayStats(day: key)
        change(&day)
        days[key] = day
    }
}

/// Italian text for the stats shown in the app.
public enum StatsText {
    /// "Oggi: 🍅 4 · 🐈 3/4 pause rispettate · 🔥 5 giorni". Empty parts are left out.
    public static func todayLine(today: DayStats, streak: Int) -> String {
        var parts = ["Oggi: 🍅 \(today.workSessions)"]
        if today.breaksTotal > 0 {
            let noun = today.breaksTotal == 1 ? "pausa rispettata" : "pause rispettate"
            parts.append("🐈 \(today.breaksCompleted)/\(today.breaksTotal) \(noun)")
        }
        if streak > 0 {
            parts.append("🔥 \(streak) \(streak == 1 ? "giorno" : "giorni")")
        }
        return parts.joined(separator: " · ")
    }

    /// "45 min", "2 h", "1 h 05 min".
    public static func duration(minutes: Int) -> String {
        let m = max(0, minutes)
        if m < 60 { return "\(m) min" }
        let h = m / 60
        let rest = m % 60
        return rest == 0 ? "\(h) h" : String(format: "%d h %02d min", h, rest)
    }
}
