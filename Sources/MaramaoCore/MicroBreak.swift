import Foundation

/// The 20-20-20 micro-break: every N minutes of work a cat peeks for twenty seconds and
/// asks you to look far away. It never covers the screen and never touches the pomodoro.
///
/// Pure state: the app feeds it the clock of the current work session on every tick and
/// shows the cat when it says so. Reset at every new phase, so a real break (which rests
/// the eyes anyway) starts the count again.
public struct MicroBreakSchedule: Equatable, Sendable {
    /// Intervals offered in Settings, in minutes. 0 means off, which is the default:
    /// the micro-break is an extra, not part of the Pomodoro.
    public static let intervalOptions: [Int] = [0, 15, 20, 30]
    public static let defaultIntervalMinutes = 0
    /// Interval proposed when the user turns the micro-break on (the "20" of 20-20-20).
    public static let suggestedIntervalMinutes = 20
    /// How long the cat stays on screen, the "20 seconds" of 20-20-20.
    public static let duration: TimeInterval = 20
    /// Never within this much of a real break: the cat would only get in the way of the
    /// other cat. A break resets the schedule, so this also covers the time after one.
    public static let breakGuard: TimeInterval = 120

    /// Minutes of work between micro-breaks. 0 or less turns them off.
    public var intervalMinutes: Int
    /// How many micro-breaks already ran in the current work session.
    public private(set) var shownInSession = 0

    public init(intervalMinutes: Int = MicroBreakSchedule.defaultIntervalMinutes) {
        self.intervalMinutes = intervalMinutes
    }

    public var isEnabled: Bool { intervalMinutes > 0 }

    public var interval: TimeInterval { TimeInterval(max(0, intervalMinutes) * 60) }

    /// Call when a new phase starts.
    public mutating func reset() {
        shownInSession = 0
    }

    /// True when another full interval of work has passed and a cat could peek now.
    /// `elapsed` and `remaining` describe the current work session.
    ///
    /// False during breaks, while idle or paused, when the micro-break is off, and within
    /// two minutes of the real break. Cheap on purpose: the app only asks the system
    /// whether the user is in a call once this says yes.
    public func isDue(
        phase: PomodoroPhase,
        isPaused: Bool,
        elapsed: TimeInterval,
        remaining: TimeInterval
    ) -> Bool {
        guard isEnabled else { return false }
        guard phase == .work, !isPaused else { return false }
        guard remaining > Self.breakGuard, elapsed > Self.breakGuard else { return false }
        return elapsed >= interval * TimeInterval(shownInSession + 1)
    }

    /// Returns true on the first tick where the work session has run for another full
    /// interval. `busy` is true while the user is in a call or presenting: the interval is
    /// then simply missed, and the next one comes when the call is over.
    public mutating func shouldShow(
        phase: PomodoroPhase,
        isPaused: Bool,
        elapsed: TimeInterval,
        remaining: TimeInterval,
        busy: Bool
    ) -> Bool {
        guard !busy else { return false }
        guard isDue(phase: phase, isPaused: isPaused, elapsed: elapsed, remaining: remaining) else { return false }
        // A long pause in the ticks (sleep, a frozen session) may skip whole intervals:
        // count them as missed instead of firing once per interval in a row.
        shownInSession = max(shownInSession + 1, Int((elapsed / interval).rounded(.down)))
        return true
    }

    /// What the cat says, for `duration` seconds.
    public static var message: String {
        String(localized: "Guarda lontano, almeno 6 metri")
    }

    /// Italian label for an interval option in Settings.
    public static func optionLabel(minutes: Int) -> String {
        if minutes <= 0 { return String(localized: "Mai") }
        return String(localized: "Ogni \(minutes) minuti")
    }
}
