import Foundation

/// Where the timer stands, as the top of the menu says it. Modelled on the Timer in the
/// Clock app: one line that says what is happening, one main control (start, pause or
/// resume) and a stop, so "pause the timer" never reads like "take a cat break".
public enum TimerStatus: Equatable, Sendable {
    /// Nothing running: the next work session is ready to start.
    case ready
    /// A work session is counting down.
    case working(remaining: TimeInterval)
    /// A work session is paused.
    case paused(remaining: TimeInterval)
    /// A cat break is on screen.
    case onBreak(remaining: TimeInterval)
    /// The cat break was put off and comes back when this runs out.
    case breakSnoozed(remaining: TimeInterval)
    /// Maramao is switched off for a while ("Disattiva per"). `until` is already worded,
    /// e.g. "fino alle 10:30" (`AvailabilityText.until`).
    case off(until: String)

    public init(phase: PomodoroPhase, isPaused: Bool, remaining: TimeInterval, isBreakSnoozed: Bool, offUntil: String?) {
        switch phase {
        case .idle:
            if let offUntil {
                self = .off(until: offUntil)
            } else {
                self = .ready
            }
        case .work:
            self = isPaused ? .paused(remaining: remaining) : .working(remaining: remaining)
        case .shortBreak, .longBreak:
            self = isBreakSnoozed ? .breakSnoozed(remaining: remaining) : .onBreak(remaining: remaining)
        }
    }

    /// The status line on top of the menu: "Al lavoro · 18:32".
    public var title: String {
        switch self {
        case .ready:
            return String(localized: "Pronto a partire")
        case let .working(remaining):
            let clock = formatClock(remaining)
            return String(localized: "Al lavoro · \(clock)")
        case let .paused(remaining):
            let clock = formatClock(remaining)
            return String(localized: "Timer sospeso · \(clock)")
        case let .onBreak(remaining):
            let clock = formatClock(remaining)
            return String(localized: "Pausa gatto · \(clock)")
        case let .breakSnoozed(remaining):
            let clock = formatClock(remaining)
            return String(localized: "Il gatto torna tra \(clock)")
        case let .off(until):
            return String(localized: "Maramao è disattivato \(until)")
        }
    }

    /// The main control, the one bound to ⇧⌘M.
    public var primaryAction: TimerPrimaryAction? {
        switch self {
        case .ready: return .start
        case .working: return .pause
        case .paused: return .resume
        case .off: return .resume
        case .onBreak, .breakSnoozed: return nil
        }
    }

    /// True when "Interrompi" makes sense: a work session is running or paused.
    public var canStop: Bool {
        switch self {
        case .working, .paused: return true
        default: return false
        }
    }
}

/// The main control of the timer: what ⇧⌘M does right now.
public enum TimerPrimaryAction: Equatable, Sendable {
    case start
    case pause
    case resume
}
