import Foundation

/// The hours when Maramao may start work sessions on its own.
/// Outside them the auto-start option is ignored and a snooze does not start work when it ends.
public struct WorkingHours: Codable, Equatable, Sendable {
    /// When false every moment counts as working time.
    public var isEnabled: Bool
    /// Working days as `Calendar` weekdays: 1 = Sunday, 2 = Monday, ... 7 = Saturday.
    public var weekdays: Set<Int>
    /// Start of the day's working hours, in minutes after midnight.
    public var startMinute: Int
    /// End of the day's working hours, in minutes after midnight. When it is not after
    /// `startMinute`, the hours run past midnight and belong to the day they start on.
    public var endMinute: Int

    public init(isEnabled: Bool = false, weekdays: Set<Int> = [2, 3, 4, 5, 6], startMinute: Int = 9 * 60, endMinute: Int = 18 * 60) {
        self.isEnabled = isEnabled
        self.weekdays = weekdays
        self.startMinute = Self.clampMinute(startMinute)
        self.endMinute = Self.clampMinute(endMinute)
    }

    /// Weekdays in the Italian order, Monday first.
    public static let weekdaysMondayFirst: [Int] = [2, 3, 4, 5, 6, 7, 1]

    /// True when `date` falls inside the working hours (always true when disabled).
    public func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        guard isEnabled else { return true }
        let parts = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        let weekday = parts.weekday ?? 1
        let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        if startMinute < endMinute {
            return weekdays.contains(weekday) && minute >= startMinute && minute < endMinute
        }
        // Overnight hours, e.g. 22:00-02:00.
        let previous = weekday == 1 ? 7 : weekday - 1
        if weekdays.contains(weekday) && minute >= startMinute { return true }
        return weekdays.contains(previous) && minute < endMinute
    }

    /// The first start of the working hours at or after `date`. When disabled, every day counts.
    /// `nil` when no weekday is selected.
    public func nextStart(onOrAfter date: Date, calendar: Calendar = .current) -> Date? {
        let today = calendar.startOfDay(for: date)
        for offset in 0..<8 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            if isEnabled && !weekdays.contains(calendar.component(.weekday, from: day)) { continue }
            guard let start = calendar.date(bySettingHour: startMinute / 60, minute: startMinute % 60, second: 0, of: day) else { continue }
            if start >= date { return start }
        }
        return nil
    }

    private static func clampMinute(_ minute: Int) -> Int {
        min(max(0, minute), 24 * 60 - 1)
    }
}

/// "Pausa per…" choices in the menu.
public enum SnoozeOption: String, CaseIterable, Identifiable, Sendable {
    case thirtyMinutes
    case oneHour
    case twoHours
    case untilTomorrow

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .thirtyMinutes: return String(localized: "30 minuti")
        case .oneHour: return String(localized: "1 ora")
        case .twoHours: return String(localized: "2 ore")
        case .untilTomorrow: return String(localized: "Fino a domani")
        }
    }

    /// Short pauses start a work session when they end (if within working hours): that is the
    /// point, people forget to resume after a meeting. "Until tomorrow" only wakes Maramao up.
    public var resumesWork: Bool { self != .untilTomorrow }

    /// When the snooze ends. "Until tomorrow" ends at the start of the next working day
    /// (or tomorrow at the working hours' start time when working hours are off).
    public func resumeDate(from now: Date, calendar: Calendar = .current, workingHours: WorkingHours = WorkingHours()) -> Date {
        switch self {
        case .thirtyMinutes: return now.addingTimeInterval(30 * 60)
        case .oneHour: return now.addingTimeInterval(60 * 60)
        case .twoHours: return now.addingTimeInterval(2 * 60 * 60)
        case .untilTomorrow:
            let today = calendar.startOfDay(for: now)
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? now.addingTimeInterval(24 * 60 * 60)
            if let start = workingHours.nextStart(onOrAfter: tomorrow, calendar: calendar) {
                return start
            }
            let fallback = WorkingHours(isEnabled: false, startMinute: workingHours.startMinute)
            return fallback.nextStart(onOrAfter: tomorrow, calendar: calendar) ?? tomorrow
        }
    }
}

/// Italian text about snoozes and working hours.
public enum AvailabilityText {
    /// Italian weekday names indexed by `Calendar` weekday (1 = Sunday).
    public static func weekdayName(_ weekday: Int) -> String {
        switch weekday {
        case 1: return String(localized: "domenica")
        case 2: return String(localized: "lunedì")
        case 3: return String(localized: "martedì")
        case 4: return String(localized: "mercoledì")
        case 5: return String(localized: "giovedì")
        case 6: return String(localized: "venerdì")
        case 7: return String(localized: "sabato")
        default: return ""
        }
    }

    /// One-letter label for the weekday picker: the first letter of the localized name
    /// (L M M G V S D in Italian, M T W T F S S in English).
    public static func weekdayInitial(_ weekday: Int) -> String {
        String(weekdayName(weekday).prefix(1)).uppercased()
    }

    /// "9:00", "13:30".
    public static func clock(minute: Int) -> String {
        String(format: "%d:%02d", minute / 60, minute % 60)
    }

    public static func clock(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return clock(minute: (parts.hour ?? 0) * 60 + (parts.minute ?? 0))
    }

    /// "alle 10:30", "all'1:15".
    public static func atTime(_ date: Date, calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: date)
        return (hour == 1 ? "all'" : "alle ") + clock(date, calendar: calendar)
    }

    /// "fino alle 10:30", "fino a domani alle 9:00", "fino a lunedì alle 9:00".
    public static func until(_ resume: Date, now: Date, calendar: Calendar = .current) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: resume)).day ?? 0
        let time = clock(resume, calendar: calendar)
        // Italian elides "alle" before 1 o'clock ("all'1:15"): a separate string per case.
        let elided = calendar.component(.hour, from: resume) == 1
        switch days {
        case ..<1:
            return elided ? String(localized: "fino all'\(time)") : String(localized: "fino alle \(time)")
        case 1:
            return elided ? String(localized: "fino a domani all'\(time)") : String(localized: "fino a domani alle \(time)")
        case 2...6:
            let weekday = weekdayName(calendar.component(.weekday, from: resume))
            return elided ? String(localized: "fino a \(weekday) all'\(time)") : String(localized: "fino a \(weekday) alle \(time)")
        default:
            let parts = calendar.dateComponents([.day, .month], from: resume)
            let day = parts.day ?? 0
            let month = parts.month ?? 0
            return elided
                ? String(localized: "fino al \(day)/\(month) all'\(time)")
                : String(localized: "fino al \(day)/\(month) alle \(time)")
        }
    }

    /// Short summary for Settings: "lun–ven, 9:00–18:00" style, listing the days.
    public static func summary(_ hours: WorkingHours) -> String {
        let days = WorkingHours.weekdaysMondayFirst
            .filter { hours.weekdays.contains($0) }
            .map { String(weekdayName($0).prefix(3)) }
        if days.isEmpty { return String(localized: "Nessun giorno selezionato") }
        return "\(days.joined(separator: ", ")) · \(clock(minute: hours.startMinute))–\(clock(minute: hours.endMinute))"
    }
}
