import Foundation

/// "Rimanda": postpone a break that just started by a few minutes, a limited number of
/// times per day. Not to be confused with "Pausa per…" (`Availability`), which puts the
/// whole app to sleep.
///
/// Pure rules; the engine ends the break mode, counts down `seconds` and then starts the
/// same break again, from the top. The daily count lives in the stats (`DayStats.breaksSnoozed`).
public struct BreakSnoozePolicy: Equatable, Sendable {
    /// Snooze lengths offered in Settings, in minutes.
    public static let minuteOptions = [1, 3, 5]
    public static let defaultMinutes = 3
    /// Daily limits offered in Settings. 0 turns snoozing off.
    public static let dailyLimitOptions = [0, 1, 2, 3, 5, 10]
    public static let defaultDailyLimit = 3
    /// Snoozing is offered during this first share of the break: it is for "two more
    /// minutes" right when the cat shows up, not for stretching a break that is nearly over.
    public static let offerWindow = 0.5

    public var minutes: Int
    public var dailyLimit: Int

    public init(minutes: Int = BreakSnoozePolicy.defaultMinutes, dailyLimit: Int = BreakSnoozePolicy.defaultDailyLimit) {
        self.minutes = min(60, max(1, minutes))
        self.dailyLimit = max(0, dailyLimit)
    }

    public var seconds: TimeInterval { TimeInterval(minutes * 60) }
    public var isEnabled: Bool { dailyLimit > 0 }

    /// Snoozes still available today.
    public func snoozesLeft(usedToday: Int) -> Int {
        max(0, dailyLimit - max(0, usedToday))
    }

    /// Whether a break that is starting may offer "Rimanda". Never in previews or in strict mode.
    public func canOffer(usedToday: Int, isPreview: Bool, strictMode: Bool) -> Bool {
        !isPreview && !strictMode && snoozesLeft(usedToday: usedToday) > 0
    }

    /// Seconds after the start of a break of `duration` during which snoozing stays possible.
    public func offerDuration(breakDuration duration: TimeInterval) -> TimeInterval {
        max(0, duration) * Self.offerWindow
    }

    /// Whether a snooze may happen `elapsed` seconds into a break of `duration`.
    public func canSnooze(usedToday: Int, isPreview: Bool, strictMode: Bool, elapsed: TimeInterval, breakDuration duration: TimeInterval) -> Bool {
        canOffer(usedToday: usedToday, isPreview: isPreview, strictMode: strictMode)
            && elapsed >= 0
            && elapsed < offerDuration(breakDuration: duration)
    }
}

/// Italian text for "Rimanda".
public enum BreakSnoozeText {
    /// "Rimanda 3 min", the HUD and menu button.
    public static func button(minutes: Int) -> String {
        String(localized: "Rimanda \(minutes) min")
    }

    /// "Ancora 2 rinvii oggi", the button's hint.
    public static func left(_ count: Int) -> String {
        count == 1 ? String(localized: "Ancora 1 rinvio oggi") : String(localized: "Ancora \(count) rinvii oggi")
    }

    /// What the peeking cat says right after a snooze.
    public static func snoozed(minutes: Int) -> String {
        minutes == 1
            ? String(localized: "Va bene, torno tra un minuto 🐾")
            : String(localized: "Va bene, torno tra \(minutes) minuti 🐾")
    }

    /// Label of a snooze length in Settings.
    public static func minutesLabel(_ minutes: Int) -> String {
        minutes == 1 ? String(localized: "1 minuto") : String(localized: "\(minutes) minuti")
    }

    /// Label of a daily limit in Settings.
    public static func limitLabel(_ limit: Int) -> String {
        switch limit {
        case ..<1: return String(localized: "Mai")
        case 1: return String(localized: "1 volta al giorno")
        default: return String(localized: "\(limit) volte al giorno")
        }
    }

    /// The menu's phase title while a snoozed break waits.
    public static var waiting: String { String(localized: "Pausa rimandata: il gatto torna presto") }
}
