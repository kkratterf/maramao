import Foundation

/// A ready-made rhythm for the timer, picked from the menu (issue #92).
/// `custom` uses the durations set in Settings; the others replace work, short and
/// long break but keep the user's "long break every N pomodori".
public enum TimerPreset: String, CaseIterable, Identifiable, Sendable {
    /// Classico 25/5, long break 15.
    case classic
    /// Lungo 50/10, long break 30.
    case long
    /// Profondo 90/20, long break 30.
    case deep
    /// Personalizzato: the durations in Settings (default, so nothing changes on update).
    case custom

    public static let defaultPreset: TimerPreset = .custom

    public var id: String { rawValue }

    /// Parses an id from a `maramao://preset/<id>` URL or a Shortcuts action, ignoring case.
    public init?(id: String) {
        let wanted = id.trimmingCharacters(in: .whitespaces).lowercased()
        guard let match = TimerPreset.allCases.first(where: { $0.rawValue.lowercased() == wanted }) else {
            return nil
        }
        self = match
    }

    /// Work, short break and long break in minutes. Nil for `custom`.
    public var minutes: (work: Int, shortBreak: Int, longBreak: Int)? {
        switch self {
        case .classic: return (25, 5, 15)
        case .long: return (50, 10, 30)
        case .deep: return (90, 20, 30)
        case .custom: return nil
        }
    }

    /// Italian label for the menu.
    public var label: String {
        switch self {
        case .classic: return String(localized: "Classico")
        case .long: return String(localized: "Lungo")
        case .deep: return String(localized: "Profondo")
        case .custom: return String(localized: "Personalizzato")
        }
    }

    /// The config to run with this preset. `custom` is the one from Settings.
    public func config(custom: PomodoroConfig) -> PomodoroConfig {
        guard let minutes = minutes else { return custom }
        return PomodoroConfig(
            work: TimeInterval(minutes.work * 60),
            shortBreak: TimeInterval(minutes.shortBreak * 60),
            longBreak: TimeInterval(minutes.longBreak * 60),
            sessionsBeforeLongBreak: custom.sessionsBeforeLongBreak
        )
    }

    /// "Classico 25/5", or "Personalizzato 30/5" with the durations from Settings.
    public func menuTitle(custom: PomodoroConfig) -> String {
        let chosen = config(custom: custom)
        let work = Int((chosen.work / 60).rounded())
        let shortBreak = Int((chosen.shortBreak / 60).rounded())
        return "\(label) \(work)/\(shortBreak)"
    }
}
