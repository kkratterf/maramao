import Foundation

/// What Maramao does with a work session when the user steps away from the Mac
/// (asleep, screen locked or no input for a while). Setting "Quando sei via".
public enum AwayBehavior: String, CaseIterable, Identifiable, Sendable {
    /// Freeze the work timer while away; back after a rest, start over from idle.
    case countAsBreak
    /// Freeze the work timer while away and leave it paused until the user resumes.
    case pause
    /// Keep counting; never start a break while the screen is asleep or locked, though.
    case ignore

    public static let defaultBehavior: AwayBehavior = .countAsBreak

    public var id: String { rawValue }

    /// Italian label in Settings.
    public var title: String {
        switch self {
        case .countAsBreak: return "Considera pausa fatta"
        case .pause: return "Metti in pausa"
        case .ignore: return "Ignora"
        }
    }
}

/// What to do with the timer when the user comes back.
public enum AwayReturnAction: Equatable, Sendable {
    /// Nothing to do (idle, break, or a work session that was not affected).
    case none
    /// Run the work session again with this much time left.
    case resume(remaining: TimeInterval)
    /// Leave the work session paused, with the time it had when the user left.
    case stayPaused
    /// The user already rested at least a short break: back to idle, session not counted.
    case resetRested
    /// The work session ran out while away and the break that followed is over too:
    /// count the session and skip the break.
    case skipBreakRested
}

/// Pure decisions about time spent away from the Mac. The app watches sleep, lock and
/// idle time and asks this type what to do with the timer.
public enum AwayPolicy {
    /// After a wake or unlock, a work session never ends sooner than this: a break must
    /// not jump on the screen while the user is still typing their password.
    public static let wakeGrace: TimeInterval = 10

    /// Seconds without any input after which the user counts as away: the short break
    /// length, but never less than a minute (reading a page is not leaving).
    public static func idleThreshold(shortBreak: TimeInterval) -> TimeInterval {
        max(60, shortBreak)
    }

    /// True when the seconds since the last keyboard/mouse event mean the user is away.
    public static func isIdleAway(idleSeconds: TimeInterval, shortBreak: TimeInterval) -> Bool {
        idleSeconds >= idleThreshold(shortBreak: shortBreak)
    }

    /// Whether a running work session should freeze when the user goes away.
    /// Breaks are never frozen: being away during a break is resting.
    public static func shouldFreeze(phase: PomodoroPhase, isPaused: Bool, behavior: AwayBehavior) -> Bool {
        phase == .work && !isPaused && behavior != .ignore
    }

    /// Work time left at the moment the user actually left (`awaySince`), given the time
    /// left now. Detecting idleness takes a while, so the time between the last input and
    /// the detection is given back. Never more than the whole session.
    public static func remainingWhenLeft(
        remainingNow: TimeInterval,
        now: Date,
        awaySince: Date,
        phaseDuration: TimeInterval
    ) -> TimeInterval {
        let lost = max(0, now.timeIntervalSince(awaySince))
        return min(max(0, phaseDuration), max(0, remainingNow) + lost)
    }

    /// Decides what to do when the user is back.
    ///
    /// - Parameters:
    ///   - phase: the phase when the user comes back.
    ///   - behavior: the "Quando sei via" setting.
    ///   - wasFrozen: true when the work session was frozen on leaving (`shouldFreeze`).
    ///   - awayDuration: how long the user was away.
    ///   - restThreshold: how long counts as a rest (the short break length).
    ///   - remaining: work time left. For a frozen session, the time left when the user
    ///     left; for a session that kept counting, the time left now (negative or zero
    ///     when it should have ended while away).
    ///   - breakDuration: length of the break that follows this work session.
    public static func onReturn(
        phase: PomodoroPhase,
        behavior: AwayBehavior,
        wasFrozen: Bool,
        awayDuration: TimeInterval,
        restThreshold: TimeInterval,
        remaining: TimeInterval,
        breakDuration: TimeInterval
    ) -> AwayReturnAction {
        guard phase == .work else { return .none }
        let rested = awayDuration >= max(1, restThreshold)

        if wasFrozen {
            switch behavior {
            case .countAsBreak:
                if rested { return .resetRested }
            case .pause:
                if rested { return .stayPaused }
            case .ignore:
                break
            }
            return .resume(remaining: max(remaining, wakeGrace))
        }

        // The session kept counting while away.
        if remaining <= 0 {
            // It ended while away: was the whole break spent away too?
            let overdue = -remaining
            if overdue >= max(1, breakDuration) { return .skipBreakRested }
            return .resume(remaining: wakeGrace)
        }
        if remaining < wakeGrace { return .resume(remaining: wakeGrace) }
        return .none
    }

    /// Italian message for the menu and the peeking cat after a return, if any.
    public static func message(for action: AwayReturnAction) -> String? {
        switch action {
        case .none, .resume: return nil
        case .stayPaused: return "Bentornato! Il timer ti aspetta in pausa"
        case .resetRested: return "Bentornato! Ti sei già riposato"
        case .skipBreakRested: return "Bentornato! La pausa l'hai già fatta"
        }
    }
}
