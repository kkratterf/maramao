import Foundation
import MaramaoCore

/// User preferences, persisted in UserDefaults.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults: UserDefaults

    @Published var workMinutes: Double { didSet { defaults.set(workMinutes, forKey: Keys.workMinutes) } }
    @Published var shortBreakMinutes: Double { didSet { defaults.set(shortBreakMinutes, forKey: Keys.shortBreakMinutes) } }
    @Published var longBreakMinutes: Double { didSet { defaults.set(longBreakMinutes, forKey: Keys.longBreakMinutes) } }
    @Published var sessionsBeforeLongBreak: Int { didSet { defaults.set(sessionsBeforeLongBreak, forKey: Keys.sessionsBeforeLongBreak) } }
    @Published var breakModeRaw: String { didSet { defaults.set(breakModeRaw, forKey: Keys.breakMode) } }
    /// When true the break can never be skipped. The cat decides.
    @Published var strictMode: Bool { didSet { defaults.set(strictMode, forKey: Keys.strictMode) } }
    /// Seconds into a break before the "skip" button appears (when not strict).
    @Published var skipUnlockSeconds: Double { didSet { defaults.set(skipUnlockSeconds, forKey: Keys.skipUnlockSeconds) } }
    @Published var autoStartWork: Bool { didSet { defaults.set(autoStartWork, forKey: Keys.autoStartWork) } }
    @Published var soundEnabled: Bool { didSet { defaults.set(soundEnabled, forKey: Keys.soundEnabled) } }
    /// Seconds before the end of a work session when a cat peeks to warn about the break. 0 = off.
    @Published var breakWarningSeconds: Int { didSet { defaults.set(breakWarningSeconds, forKey: Keys.breakWarningSeconds) } }
    /// Which displays the cats cover (`DisplayScope` raw value).
    @Published var displayScopeRaw: String { didSet { defaults.set(displayScopeRaw, forKey: Keys.displayScope) } }

    private enum Keys {
        static let workMinutes = "workMinutes"
        static let shortBreakMinutes = "shortBreakMinutes"
        static let longBreakMinutes = "longBreakMinutes"
        static let sessionsBeforeLongBreak = "sessionsBeforeLongBreak"
        static let breakMode = "breakMode"
        static let strictMode = "strictMode"
        static let skipUnlockSeconds = "skipUnlockSeconds"
        static let autoStartWork = "autoStartWork"
        static let soundEnabled = "soundEnabled"
        static let breakWarningSeconds = "breakWarningSeconds"
        static let displayScope = "displayScope"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Keys.workMinutes: 25.0,
            Keys.shortBreakMinutes: 5.0,
            Keys.longBreakMinutes: 15.0,
            Keys.sessionsBeforeLongBreak: 4,
            Keys.breakMode: BreakModeID.random.rawValue,
            Keys.strictMode: false,
            Keys.skipUnlockSeconds: 60.0,
            Keys.autoStartWork: false,
            Keys.soundEnabled: true,
            Keys.breakWarningSeconds: BreakWarning.defaultLeadTime,
            Keys.displayScope: DisplayScope.defaultScope.rawValue,
        ])
        workMinutes = defaults.double(forKey: Keys.workMinutes)
        shortBreakMinutes = defaults.double(forKey: Keys.shortBreakMinutes)
        longBreakMinutes = defaults.double(forKey: Keys.longBreakMinutes)
        sessionsBeforeLongBreak = defaults.integer(forKey: Keys.sessionsBeforeLongBreak)
        breakModeRaw = defaults.string(forKey: Keys.breakMode) ?? BreakModeID.random.rawValue
        strictMode = defaults.bool(forKey: Keys.strictMode)
        skipUnlockSeconds = defaults.double(forKey: Keys.skipUnlockSeconds)
        autoStartWork = defaults.bool(forKey: Keys.autoStartWork)
        soundEnabled = defaults.bool(forKey: Keys.soundEnabled)
        breakWarningSeconds = defaults.integer(forKey: Keys.breakWarningSeconds)
        displayScopeRaw = defaults.string(forKey: Keys.displayScope) ?? DisplayScope.defaultScope.rawValue
    }

    var breakMode: BreakModeID {
        get { BreakModeID(rawValue: breakModeRaw) ?? .random }
        set { breakModeRaw = newValue.rawValue }
    }

    var displayScope: DisplayScope {
        get { DisplayScope(rawValue: displayScopeRaw) ?? .defaultScope }
        set { displayScopeRaw = newValue.rawValue }
    }

    var pomodoroConfig: PomodoroConfig {
        PomodoroConfig(
            work: workMinutes * 60,
            shortBreak: shortBreakMinutes * 60,
            longBreak: longBreakMinutes * 60,
            sessionsBeforeLongBreak: sessionsBeforeLongBreak
        )
    }
}
