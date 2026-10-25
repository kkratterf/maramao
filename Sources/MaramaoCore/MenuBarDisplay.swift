import Foundation

/// What Maramao shows in the menu bar ("Nella barra dei menu" in Settings).
public enum MenuBarStyle: String, CaseIterable, Identifiable, Sendable {
    /// Phase emoji followed by the countdown (default).
    case catAndCountdown
    /// Only the phase emoji.
    case catOnly
    /// Only the countdown.
    case countdownOnly
    /// The phase symbol inside a small ring that fills up as the phase goes on.
    case catWithRing

    public static let defaultStyle: MenuBarStyle = .catAndCountdown

    public var id: String { rawValue }

    /// Italian label for Settings.
    public var title: String {
        switch self {
        case .catAndCountdown: return String(localized: "Gatto + countdown")
        case .catOnly: return String(localized: "Solo gatto")
        case .countdownOnly: return String(localized: "Solo countdown")
        case .catWithRing: return String(localized: "Gatto con anello di progresso")
        }
    }

    /// True when the style shows the remaining time as text.
    public var showsCountdown: Bool {
        self == .catAndCountdown || self == .countdownOnly
    }
}

/// Menu bar countdown text. With seconds it is `formatClock` ("24:59");
/// without, whole minutes rounded up ("25m", "1h 05m"), so the text only
/// changes once a minute and never says "0m" while time is left.
public func formatMenuBarClock(_ seconds: TimeInterval, showSeconds: Bool) -> String {
    if showSeconds { return formatClock(seconds) }
    let totalSeconds = max(0, Int(seconds.rounded(.up)))
    let minutes = (totalSeconds + 59) / 60
    if minutes >= 60 {
        return String(format: "%dh %02dm", minutes / 60, minutes % 60)
    }
    return "\(minutes)m"
}

/// Quantizes a 0...1 progress into `steps` buckets (0...steps), so the
/// menu bar ring is only redrawn when it visibly changes.
public func menuBarRingStep(progress: Double, steps: Int) -> Int {
    guard steps > 0, progress.isFinite else { return 0 }
    let clamped = min(1, max(0, progress))
    return Int((clamped * Double(steps)).rounded(.down))
}
