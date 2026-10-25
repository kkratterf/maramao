import Foundation

/// A phase of the Pomodoro cycle.
public enum PomodoroPhase: String, Equatable, Sendable {
    case idle
    case work
    case shortBreak
    case longBreak

    public var isBreak: Bool { self == .shortBreak || self == .longBreak }
}

/// Durations and rhythm of a Pomodoro cycle.
public struct PomodoroConfig: Equatable, Sendable {
    public var work: TimeInterval
    public var shortBreak: TimeInterval
    public var longBreak: TimeInterval
    /// Number of work sessions before a long break.
    public var sessionsBeforeLongBreak: Int

    public init(
        work: TimeInterval = 25 * 60,
        shortBreak: TimeInterval = 5 * 60,
        longBreak: TimeInterval = 15 * 60,
        sessionsBeforeLongBreak: Int = 4
    ) {
        self.work = work
        self.shortBreak = shortBreak
        self.longBreak = longBreak
        self.sessionsBeforeLongBreak = max(1, sessionsBeforeLongBreak)
    }

    public func duration(of phase: PomodoroPhase) -> TimeInterval {
        switch phase {
        case .idle: return 0
        case .work: return work
        case .shortBreak: return shortBreak
        case .longBreak: return longBreak
        }
    }
}

/// The state machine behind the timer: which phase comes next and how long it lasts.
/// It knows nothing about clocks; the app drives it.
public struct PomodoroCycle: Equatable, Sendable {
    public private(set) var phase: PomodoroPhase = .idle
    /// Work sessions completed since the last reset.
    public private(set) var completedWorkSessions = 0
    public var config: PomodoroConfig

    public init(config: PomodoroConfig = PomodoroConfig()) {
        self.config = config
    }

    public var currentDuration: TimeInterval { config.duration(of: phase) }

    /// Work sessions completed in the current set (resets after each long break).
    public var sessionsInCurrentSet: Int {
        completedWorkSessions % config.sessionsBeforeLongBreak
    }

    /// Starts a work session from any phase.
    public mutating func startWork() {
        phase = .work
    }

    /// Ends the current phase and moves to the next one.
    /// Work is followed by a break (long every `sessionsBeforeLongBreak`);
    /// a break is followed by work when `autoStartWork` is true, idle otherwise.
    @discardableResult
    public mutating func advance(autoStartWork: Bool = false) -> PomodoroPhase {
        switch phase {
        case .idle:
            phase = .work
        case .work:
            completedWorkSessions += 1
            phase = completedWorkSessions % config.sessionsBeforeLongBreak == 0 ? .longBreak : .shortBreak
        case .shortBreak, .longBreak:
            phase = autoStartWork ? .work : .idle
        }
        return phase
    }

    public mutating func reset() {
        phase = .idle
        completedWorkSessions = 0
    }
}

/// Formats seconds as `mm:ss` (or `h:mm:ss` past an hour).
public func formatClock(_ seconds: TimeInterval) -> String {
    let total = max(0, Int(seconds.rounded(.up)))
    let h = total / 3600
    let m = (total % 3600) / 60
    let s = total % 60
    if h > 0 {
        return String(format: "%d:%02d:%02d", h, m, s)
    }
    return String(format: "%02d:%02d", m, s)
}

/// Seconds until `formatClock(remaining)` shows a different value, as the clock counts down.
/// The app wakes up right then instead of polling, so a running timer costs one wakeup a second.
/// Returns 0 when the countdown is over.
public func secondsUntilClockChanges(remaining: TimeInterval) -> TimeInterval {
    guard remaining > 0 else { return 0 }
    let fraction = remaining - remaining.rounded(.down)
    return fraction > 0 ? fraction : 1
}
