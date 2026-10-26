import Foundation

/// The pages of the welcome window shown on first launch, in order.
public enum OnboardingStep: Int, CaseIterable, Sendable {
    /// The cat introduces itself and explains the menu bar icon.
    case welcome
    /// Work and break lengths.
    case timing
    /// Which cat stops you (or "Sorpresa").
    case cat
    /// A 10-second trial break.
    case trial
    /// ⌃⌥⌘⌫ and the corner clicks.
    case emergencyExit
    /// "Apri Maramao all'avvio del Mac".
    case launchAtLogin

    public static let first: OnboardingStep = .welcome

    /// Length of the trial break, in seconds.
    public static let trialBreakSeconds: TimeInterval = 10

    /// The step after this one, or nil on the last step.
    public var next: OnboardingStep? { OnboardingStep(rawValue: rawValue + 1) }

    /// The step before this one, or nil on the first step.
    public var previous: OnboardingStep? { OnboardingStep(rawValue: rawValue - 1) }

    public var isFirst: Bool { previous == nil }
    public var isLast: Bool { next == nil }

    /// 1-based position, for "2 di 6".
    public var number: Int { rawValue + 1 }
}

/// Decides whether the welcome window opens at launch.
public enum OnboardingPolicy {
    /// True when the user has already been through onboarding, or does not need it.
    /// - Parameters:
    ///   - stored: the saved `hasCompletedOnboarding` flag, nil when it was never saved.
    ///   - hasPriorSettings: true when settings from an earlier version exist, i.e. the
    ///     user already knows Maramao and upgraded to a version with onboarding.
    public static func hasCompleted(stored: Bool?, hasPriorSettings: Bool) -> Bool {
        stored ?? hasPriorSettings
    }
}
