import Foundation

/// Decides when to warn the user that a break is coming ("Miao, tra un minuto pausa").
/// Pure state: the app feeds it the clock on every tick and shows the cat when it says so.
public struct BreakWarning: Equatable, Sendable {
    /// Lead times offered in Settings, in seconds. 0 means off.
    public static let leadTimeOptions: [Int] = [0, 30, 60, 120]
    public static let defaultLeadTime = 60

    /// Seconds before the end of a work session to warn at. 0 or less turns the warning off.
    public var leadTime: TimeInterval
    /// True once the warning has fired in the current work session.
    public private(set) var hasWarned = false

    public init(leadTime: TimeInterval = TimeInterval(BreakWarning.defaultLeadTime)) {
        self.leadTime = leadTime
    }

    public var isEnabled: Bool { leadTime > 0 }

    /// Call when a new phase starts, so the next work session can warn again.
    public mutating func reset() {
        hasWarned = false
    }

    /// Returns true exactly once per work session, on the first tick where `remaining`
    /// drops to `leadTime` or below while the work session is running.
    ///
    /// Never warns during breaks, while idle or paused, when the warning is off, or when the
    /// whole work session is not longer than the lead time (the user would be warned at start).
    public mutating func shouldWarn(
        phase: PomodoroPhase,
        isPaused: Bool,
        remaining: TimeInterval,
        phaseDuration: TimeInterval
    ) -> Bool {
        guard isEnabled, !hasWarned else { return false }
        guard phase == .work, !isPaused else { return false }
        guard phaseDuration > leadTime else { return false }
        guard remaining > 0, remaining <= leadTime else { return false }
        hasWarned = true
        return true
    }

    /// Seconds to announce in the speech bubble. Normally the lead time; when the warning
    /// fires late (e.g. the user resumed from pause with less time left) the real remaining time.
    public func announcedSeconds(remaining: TimeInterval) -> Int {
        let lead = Int(leadTime.rounded())
        let left = max(1, Int(remaining.rounded(.up)))
        return lead - left <= 2 ? lead : left
    }

    /// The Italian speech bubble text for a warning given `seconds` before the break.
    public static func message(seconds: Int) -> String {
        let s = max(1, seconds)
        if s == 60 { return String(localized: "Miao, tra un minuto pausa") }
        if s % 60 == 0 { return String(localized: "Miao, tra \(s / 60) minuti pausa") }
        if s == 1 { return String(localized: "Miao, tra un secondo pausa") }
        return String(localized: "Miao, tra \(s) secondi pausa")
    }

    /// Italian label for a lead time option in Settings.
    public static func optionLabel(seconds: Int) -> String {
        if seconds <= 0 { return String(localized: "Mai") }
        if seconds == 60 { return String(localized: "1 minuto prima") }
        if seconds % 60 == 0 { return String(localized: "\(seconds / 60) minuti prima") }
        return String(localized: "\(seconds) secondi prima")
    }
}
