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
    /// Raw `TimerPreset` picked in the menu. `custom` runs the durations above.
    @Published var timerPresetRaw: String { didSet { defaults.set(timerPresetRaw, forKey: Keys.timerPreset) } }
    @Published var breakModeRaw: String { didSet { defaults.set(breakModeRaw, forKey: Keys.breakMode) } }
    /// When true the break can never be skipped. The cat decides.
    @Published var strictMode: Bool { didSet { defaults.set(strictMode, forKey: Keys.strictMode) } }
    /// Seconds into a break before the "skip" button appears (when not strict).
    @Published var skipUnlockSeconds: Double { didSet { defaults.set(skipUnlockSeconds, forKey: Keys.skipUnlockSeconds) } }
    @Published var autoStartWork: Bool { didSet { defaults.set(autoStartWork, forKey: Keys.autoStartWork) } }
    @Published var soundEnabled: Bool { didSet { defaults.set(soundEnabled, forKey: Keys.soundEnabled) } }
    /// Loudness of the cat sounds, 0...1.
    @Published var soundVolume: Double { didSet { defaults.set(soundVolume, forKey: Keys.soundVolume) } }
    /// Seconds before the end of a work session when a cat peeks to warn about the break. 0 = off.
    @Published var breakWarningSeconds: Int { didSet { defaults.set(breakWarningSeconds, forKey: Keys.breakWarningSeconds) } }
    /// What happens to a work session while the Mac is asleep, locked or idle (`AwayBehavior`).
    @Published var awayBehaviorRaw: String { didSet { defaults.set(awayBehaviorRaw, forKey: Keys.awayBehavior) } }
    /// Which displays the cats cover (`DisplayScope` raw value).
    @Published var displayScopeRaw: String { didSet { defaults.set(displayScopeRaw, forKey: Keys.displayScope) } }
    /// Hold the break while the microphone or camera is in use or a presentation is fullscreen.
    @Published var dontInterruptCalls: Bool { didSet { defaults.set(dontInterruptCalls, forKey: Keys.dontInterruptCalls) } }
    /// Longest hold, in minutes. 0 = wait as long as the call lasts.
    @Published var maxPostponeMinutes: Int { didSet { defaults.set(maxPostponeMinutes, forKey: Keys.maxPostponeMinutes) } }
    /// Raw `MenuBarStyle`: what the menu bar item shows.
    @Published var menuBarStyleRaw: String { didSet { defaults.set(menuBarStyleRaw, forKey: Keys.menuBarStyle) } }
    /// Shows "24m" instead of "24:59" in the menu bar.
    @Published var menuBarHideSeconds: Bool { didSet { defaults.set(menuBarHideSeconds, forKey: Keys.menuBarHideSeconds) } }
    /// Raw `MotionPreference`: follow Reduce Motion, or force calm or full break animations.
    @Published var motionPreferenceRaw: String { didSet { defaults.set(motionPreferenceRaw, forKey: Keys.motionPreference) } }
    /// "Il tuo gatto": the cat remembers you, can be petted and fed with treats.
    @Published var companionEnabled: Bool { didSet { defaults.set(companionEnabled, forKey: Keys.companionEnabled) } }
    /// "Rimanda": minutes a break is postponed by, and how many times a day (0 = never).
    @Published var snoozeMinutes: Int { didSet { defaults.set(snoozeMinutes, forKey: Keys.snoozeMinutes) } }
    @Published var snoozeDailyLimit: Int { didSet { defaults.set(snoozeDailyLimit, forKey: Keys.snoozeDailyLimit) } }
    /// Minutes of work between 20-20-20 micro-breaks for the eyes. 0 = off.
    @Published var microBreakMinutes: Int { didSet { defaults.set(microBreakMinutes, forKey: Keys.microBreakMinutes) } }

    private enum Keys {
        static let workMinutes = "workMinutes"
        static let shortBreakMinutes = "shortBreakMinutes"
        static let longBreakMinutes = "longBreakMinutes"
        static let sessionsBeforeLongBreak = "sessionsBeforeLongBreak"
        static let timerPreset = "timerPreset"
        static let breakMode = "breakMode"
        static let strictMode = "strictMode"
        static let skipUnlockSeconds = "skipUnlockSeconds"
        static let autoStartWork = "autoStartWork"
        static let soundEnabled = "soundEnabled"
        static let soundVolume = "soundVolume"
        static let breakWarningSeconds = "breakWarningSeconds"
        static let awayBehavior = "awayBehavior"
        static let displayScope = "displayScope"
        static let dontInterruptCalls = "dontInterruptCalls"
        static let maxPostponeMinutes = "maxPostponeMinutes"
        static let menuBarStyle = "menuBarStyle"
        static let menuBarHideSeconds = "menuBarHideSeconds"
        static let motionPreference = "motionPreference"
        static let companionEnabled = "companionEnabled"
        static let snoozeMinutes = "snoozeMinutes"
        static let snoozeDailyLimit = "snoozeDailyLimit"
        static let microBreakMinutes = "microBreakMinutes"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Keys.workMinutes: 25.0,
            Keys.shortBreakMinutes: 5.0,
            Keys.longBreakMinutes: 15.0,
            Keys.sessionsBeforeLongBreak: 4,
            Keys.timerPreset: TimerPreset.defaultPreset.rawValue,
            Keys.breakMode: BreakModeID.random.rawValue,
            Keys.strictMode: false,
            Keys.skipUnlockSeconds: 60.0,
            Keys.autoStartWork: false,
            Keys.soundEnabled: true,
            Keys.soundVolume: 0.7,
            Keys.breakWarningSeconds: BreakWarning.defaultLeadTime,
            Keys.awayBehavior: AwayBehavior.defaultBehavior.rawValue,
            Keys.displayScope: DisplayScope.defaultScope.rawValue,
            Keys.dontInterruptCalls: true,
            Keys.maxPostponeMinutes: BreakPostponer.defaultMaxMinutes,
            Keys.menuBarStyle: MenuBarStyle.defaultStyle.rawValue,
            Keys.menuBarHideSeconds: false,
            Keys.motionPreference: MotionPreference.defaultPreference.rawValue,
            Keys.companionEnabled: true,
            Keys.snoozeMinutes: BreakSnoozePolicy.defaultMinutes,
            Keys.snoozeDailyLimit: BreakSnoozePolicy.defaultDailyLimit,
            Keys.microBreakMinutes: MicroBreakSchedule.defaultIntervalMinutes,
        ])
        workMinutes = defaults.double(forKey: Keys.workMinutes)
        shortBreakMinutes = defaults.double(forKey: Keys.shortBreakMinutes)
        longBreakMinutes = defaults.double(forKey: Keys.longBreakMinutes)
        sessionsBeforeLongBreak = defaults.integer(forKey: Keys.sessionsBeforeLongBreak)
        timerPresetRaw = defaults.string(forKey: Keys.timerPreset) ?? TimerPreset.defaultPreset.rawValue
        breakModeRaw = defaults.string(forKey: Keys.breakMode) ?? BreakModeID.random.rawValue
        strictMode = defaults.bool(forKey: Keys.strictMode)
        skipUnlockSeconds = defaults.double(forKey: Keys.skipUnlockSeconds)
        autoStartWork = defaults.bool(forKey: Keys.autoStartWork)
        soundEnabled = defaults.bool(forKey: Keys.soundEnabled)
        soundVolume = min(1, max(0, defaults.double(forKey: Keys.soundVolume)))
        breakWarningSeconds = defaults.integer(forKey: Keys.breakWarningSeconds)
        awayBehaviorRaw = defaults.string(forKey: Keys.awayBehavior) ?? AwayBehavior.defaultBehavior.rawValue
        displayScopeRaw = defaults.string(forKey: Keys.displayScope) ?? DisplayScope.defaultScope.rawValue
        dontInterruptCalls = defaults.bool(forKey: Keys.dontInterruptCalls)
        maxPostponeMinutes = defaults.integer(forKey: Keys.maxPostponeMinutes)
        menuBarStyleRaw = defaults.string(forKey: Keys.menuBarStyle) ?? MenuBarStyle.defaultStyle.rawValue
        menuBarHideSeconds = defaults.bool(forKey: Keys.menuBarHideSeconds)
        motionPreferenceRaw = defaults.string(forKey: Keys.motionPreference) ?? MotionPreference.defaultPreference.rawValue
        companionEnabled = defaults.bool(forKey: Keys.companionEnabled)
        snoozeMinutes = defaults.integer(forKey: Keys.snoozeMinutes)
        snoozeDailyLimit = defaults.integer(forKey: Keys.snoozeDailyLimit)
        microBreakMinutes = defaults.integer(forKey: Keys.microBreakMinutes)
    }

    var snoozePolicy: BreakSnoozePolicy {
        BreakSnoozePolicy(minutes: snoozeMinutes, dailyLimit: snoozeDailyLimit)
    }

    var breakMode: BreakModeID {
        get { BreakModeID(rawValue: breakModeRaw) ?? .random }
        set { breakModeRaw = newValue.rawValue }
    }

    var displayScope: DisplayScope {
        get { DisplayScope(rawValue: displayScopeRaw) ?? .defaultScope }
        set { displayScopeRaw = newValue.rawValue }
    }

    var menuBarStyle: MenuBarStyle {
        get { MenuBarStyle(rawValue: menuBarStyleRaw) ?? .defaultStyle }
        set { menuBarStyleRaw = newValue.rawValue }
    }

    var motionPreference: MotionPreference {
        get { MotionPreference(rawValue: motionPreferenceRaw) ?? .defaultPreference }
        set { motionPreferenceRaw = newValue.rawValue }
    }

    var timerPreset: TimerPreset {
        get { TimerPreset(rawValue: timerPresetRaw) ?? .defaultPreset }
        set { timerPresetRaw = newValue.rawValue }
    }

    /// The durations set in Settings ("Personalizzato").
    var customPomodoroConfig: PomodoroConfig {
        PomodoroConfig(
            work: workMinutes * 60,
            shortBreak: shortBreakMinutes * 60,
            longBreak: longBreakMinutes * 60,
            sessionsBeforeLongBreak: sessionsBeforeLongBreak
        )
    }

    /// The durations the timer runs: the chosen preset, or the Settings ones.
    var pomodoroConfig: PomodoroConfig {
        timerPreset.config(custom: customPomodoroConfig)
    }
}
