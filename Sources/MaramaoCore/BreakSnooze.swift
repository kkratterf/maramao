import Foundation

/// How many snoozes ("Ancora 5 minuti") were used on one day. Persisted by the app.
public struct BreakSnoozeLedger: Codable, Equatable, Sendable {
    /// The day as `yyyy-MM-dd`.
    public var day: String
    public var count: Int

    public init(day: String, count: Int = 0) {
        self.day = day
        self.count = max(0, count)
    }

    /// Snoozes used on `today`: a ledger from another day counts as zero.
    public func used(on today: String) -> Int {
        day == today ? count : 0
    }

    /// The ledger after one more snooze on `today`.
    public func recording(on today: String) -> BreakSnoozeLedger {
        BreakSnoozeLedger(day: today, count: used(on: today) + 1)
    }
}

/// Rules for snoozing a break: a few minutes more of work, a few times a day, never in strict mode.
public enum BreakSnooze {
    /// Daily limit choices in Settings. 0 turns snoozing off.
    public static let dailyLimitOptions: [Int] = [0, 1, 2, 3, 5]
    public static let defaultDailyLimit = 3
    /// Snooze length choices in Settings, in minutes.
    public static let minutesOptions: [Int] = [1, 2, 3, 5, 10]
    public static let defaultMinutes = 5

    /// Whether the "Ancora N minuti" button may show.
    public static func canSnooze(strictMode: Bool, isPreview: Bool, usedToday: Int, dailyLimit: Int) -> Bool {
        guard !strictMode, !isPreview, dailyLimit > 0 else { return false }
        return usedToday < dailyLimit
    }

    /// Snoozes left today.
    public static func remaining(usedToday: Int, dailyLimit: Int) -> Int {
        max(0, dailyLimit - usedToday)
    }

    /// The button label: "Ancora 5 minuti", "Ancora 1 minuto".
    public static func buttonLabel(minutes: Int) -> String {
        let m = max(1, minutes)
        return m == 1 ? String(localized: "Ancora 1 minuto") : String(localized: "Ancora \(m) minuti")
    }

    /// What the cat says after the `count`-th snooze of the day (1-based): grumpier every time.
    public static func catLine(count: Int, minutes: Int) -> String {
        let m = max(1, minutes)
        let time = m == 1 ? String(localized: "un minuto") : String(localized: "\(m) minuti")
        switch count {
        case ...1: return String(localized: "Va bene, \(time). Ma solo \(time). 😼")
        case 2: return String(localized: "Ancora? Il gatto prende nota. 😾")
        case 3: return String(localized: "Ultima volta, eh. Il gatto non dimentica. 🙀")
        default: return String(localized: "Il gatto è molto deluso da te. 😿")
        }
    }

    /// Italian label for a daily limit option in Settings.
    public static func dailyLimitLabel(_ limit: Int) -> String {
        switch limit {
        case ...0: return String(localized: "Mai")
        case 1: return String(localized: "1 volta al giorno")
        default: return String(localized: "\(limit) volte al giorno")
        }
    }
}
