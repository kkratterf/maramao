import AppKit
import MaramaoCore

/// Runs `AutomationCommand`s from the `maramao://` URL scheme (and the
/// Shortcuts actions) against the engine.
///
/// Commands that would end a real break early (start, reset, skip) only
/// work once the break may be skipped, so strict mode is respected.
@MainActor
enum AutomationRunner {
    /// Handles a `maramao://` URL. Returns false when it is not one we understand.
    @discardableResult
    static func handle(_ url: URL) -> Bool {
        guard let command = AutomationCommand(url: url) else {
            NSLog("Maramao: ignoring unknown URL \(url.absoluteString)")
            return false
        }
        perform(command)
        return true
    }

    static func perform(_ command: AutomationCommand) {
        let engine = PomodoroEngine.shared
        let breakLocked = engine.phase.isBreak && !engine.canSkipBreak

        switch command {
        case .start:
            switch engine.phase {
            case .idle: engine.startWork()
            case .work: if engine.isPaused { engine.togglePause() }
            case .shortBreak, .longBreak: if !breakLocked { engine.startWork() }
            }
        case .pause:
            if engine.phase == .work && !engine.isPaused { engine.togglePause() }
        case .resume:
            if engine.phase == .work && engine.isPaused { engine.togglePause() }
        case .toggle:
            switch engine.phase {
            case .idle: engine.startWork()
            case .work: engine.togglePause()
            case .shortBreak, .longBreak: break // Breaks cannot be paused.
            }
        case .takeBreak:
            if !engine.phase.isBreak { engine.takeBreakNow() }
        case .skip:
            // `skip()` refuses to end a break before it may be skipped.
            engine.skip()
        case .reset:
            if !breakLocked { engine.reset() }
        case .setMode(let id):
            if let mode = breakMode(matching: id) {
                AppSettings.shared.breakMode = mode
            }
        case .preview(let id):
            if let mode = breakMode(matching: id) {
                engine.preview(mode.resolved(), seconds: 30)
            }
        case .setPreset(let id):
            if let preset = TimerPreset(id: id) {
                engine.setTimerPreset(preset)
            }
        }
    }

    /// `BreakModeID` for a raw value, ignoring case ("memewall" works too).
    static func breakMode(matching id: String) -> BreakModeID? {
        let wanted = id.lowercased()
        return BreakModeID.allCases.first { $0.rawValue.lowercased() == wanted }
    }

    /// One localized line with the current state, e.g. "Concentrazione, 12:34 rimasti · 3 pomodori oggi".
    static func statusLine() -> String {
        let engine = PomodoroEngine.shared
        let clock = formatClock(engine.remaining)
        let state: String
        switch engine.phase {
        case .idle: state = String(localized: "Fermo")
        case .work:
            state = engine.isPaused
                ? String(localized: "In pausa, \(clock) rimasti")
                : String(localized: "Concentrazione, \(clock) rimasti")
        case .shortBreak: state = String(localized: "Pausa breve, \(clock) rimasti")
        case .longBreak: state = String(localized: "Pausa lunga, \(clock) rimasti")
        }
        let today = StatsStore.shared.today.workSessions
        let count = String(localized: "\(today) pomodori oggi")
        return "\(state) · \(count)"
    }
}
