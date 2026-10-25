import Foundation

/// Whether break animations follow the system's Reduce Motion setting or an in-app override.
public enum MotionPreference: String, CaseIterable, Sendable {
    /// Follow System Settings → Accessibility → Display → Reduce motion.
    case system
    /// Always the calm variant: fades instead of walking, falling and bouncing.
    case reduced
    /// Always the full animations.
    case full

    public static let defaultPreference: MotionPreference = .system

    public var label: String {
        switch self {
        case .system: return String(localized: "Come il sistema")
        case .reduced: return String(localized: "Ridotte")
        case .full: return String(localized: "Complete")
        }
    }

    /// True when the break should use its calm variant.
    public func reducesMotion(systemReduceMotion: Bool) -> Bool {
        switch self {
        case .system: return systemReduceMotion
        case .reduced: return true
        case .full: return false
        }
    }
}

/// What VoiceOver says about a break, in Italian. Pure text and timing, no AppKit.
public enum BreakSpeech {
    /// "5 minuti", "1 minuto", "30 secondi", "2 minuti e 30 secondi".
    public static func duration(seconds: Int) -> String {
        let s = max(0, seconds)
        let minutes = s / 60
        let rest = s % 60
        let minutePart = minutes == 1 ? String(localized: "1 minuto") : String(localized: "\(minutes) minuti")
        let secondPart = rest == 1 ? String(localized: "1 secondo") : String(localized: "\(rest) secondi")
        if minutes == 0 { return secondPart }
        if rest == 0 { return minutePart }
        return String(localized: "\(minutePart) e \(secondPart)")
    }

    /// Announced when the overlays appear: "Pausa: 5 minuti. Il gatto sulla finestra."
    /// Breaks are announced in whole minutes, rounded to the nearest one (seconds below a minute).
    public static func breakStarted(duration: TimeInterval, modeTitle: String?) -> String {
        let total = max(0, Int(duration.rounded()))
        let spoken: String
        if total >= 60 {
            let minutes = max(1, Int((Double(total) / 60).rounded()))
            spoken = minutes == 1 ? String(localized: "1 minuto") : String(localized: "\(minutes) minuti")
        } else {
            spoken = BreakSpeech.duration(seconds: total)
        }
        var text = String(localized: "Pausa: \(spoken).")
        if let modeTitle, !modeTitle.isEmpty {
            text += " \(modeTitle)."
        }
        return text
    }

    public static let breakEnded = String(localized: "Pausa finita. Puoi tornare al lavoro.")

    /// "Mancano 4 minuti" / "Manca 1 minuto" / "Mancano 30 secondi".
    public static func remaining(seconds: Int) -> String {
        let text = duration(seconds: seconds)
        let singular = seconds == 60 || seconds == 1
        return singular ? String(localized: "Manca \(text)") : String(localized: "Mancano \(text)")
    }

    /// Value of the countdown for VoiceOver: whole seconds left, spoken.
    public static func countdownValue(remaining: TimeInterval) -> String {
        duration(seconds: Int(remaining.rounded(.up)))
    }

    /// Hint for the skip control: when it unlocks, or that it is locked for good.
    public static func skipHint(secondsUntilUnlock: Int?, shortcut: String?) -> String {
        guard let wait = secondsUntilUnlock else {
            return String(localized: "Modalità severa: la pausa non si salta.")
        }
        if wait > 0 {
            return String(localized: "Potrai saltare la pausa tra \(duration(seconds: wait)).")
        }
        if let shortcut, !shortcut.isEmpty {
            return String(localized: "Puoi saltare la pausa, anche con \(shortcut).")
        }
        return String(localized: "Puoi saltare la pausa.")
    }

    /// Whether to announce the time left, so VoiceOver speaks sparingly: once per whole minute
    /// crossed, then at 30 and 10 seconds. `previous` and `current` are seconds left on two
    /// consecutive checks (`previous` > `current`).
    public static func milestone(previous: TimeInterval, current: TimeInterval) -> Int? {
        guard previous > current, current > 0 else { return nil }
        let marks = [10, 30]
        for mark in marks where previous > Double(mark) && current <= Double(mark) {
            return mark
        }
        let previousMinute = Int((previous / 60).rounded(.up))
        let currentMinute = Int((current / 60).rounded(.up))
        if currentMinute < previousMinute && currentMinute >= 1 && current > 30 {
            return currentMinute * 60
        }
        return nil
    }
}
