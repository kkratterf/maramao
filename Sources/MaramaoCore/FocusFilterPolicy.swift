import Foundation

/// What the current Focus asks of Maramao, as set by the user in
/// System Settings → Focus → Focus filters.
///
/// The defaults change nothing, because the system also reports the filter
/// with its default values when the Focus turns off.
public struct FocusFilterPolicy: Equatable, Sendable {
    /// When false, breaks still run (and count down in the menu bar) but no
    /// cat appears on screen and none peeks before the break.
    public var catsEnabled: Bool
    /// Raw value of the break mode to use instead of the one in Settings.
    public var breakModeOverride: String?
    /// When false, the cats stay silent.
    public var soundsEnabled: Bool

    public init(catsEnabled: Bool = true, breakModeOverride: String? = nil, soundsEnabled: Bool = true) {
        self.catsEnabled = catsEnabled
        self.breakModeOverride = breakModeOverride
        self.soundsEnabled = soundsEnabled
    }

    /// The policy that changes nothing.
    public static let unrestricted = FocusFilterPolicy()

    /// True when the Focus changes anything at all.
    public var isActive: Bool { self != .unrestricted }

    /// Sounds play only when the cats are on too: "no cats" means no meows either.
    public var soundsAllowed: Bool { catsEnabled && soundsEnabled }

    /// The break mode to use, or nil when the cats are off.
    public func breakMode(default fallback: String) -> String? {
        guard catsEnabled else { return nil }
        if let override = breakModeOverride, !override.isEmpty { return override }
        return fallback
    }

    // MARK: - Persistence

    private enum Keys {
        static let catsEnabled = "focusFilter.catsEnabled"
        static let breakMode = "focusFilter.breakMode"
        static let soundsEnabled = "focusFilter.soundsEnabled"
    }

    /// Reads the last policy the system delivered (unrestricted if none).
    public static func load(from defaults: UserDefaults) -> FocusFilterPolicy {
        FocusFilterPolicy(
            catsEnabled: defaults.object(forKey: Keys.catsEnabled) as? Bool ?? true,
            breakModeOverride: defaults.string(forKey: Keys.breakMode),
            soundsEnabled: defaults.object(forKey: Keys.soundsEnabled) as? Bool ?? true
        )
    }

    public func store(in defaults: UserDefaults) {
        defaults.set(catsEnabled, forKey: Keys.catsEnabled)
        if let override = breakModeOverride, !override.isEmpty {
            defaults.set(override, forKey: Keys.breakMode)
        } else {
            defaults.removeObject(forKey: Keys.breakMode)
        }
        defaults.set(soundsEnabled, forKey: Keys.soundsEnabled)
    }
}
