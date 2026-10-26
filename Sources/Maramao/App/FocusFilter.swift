import AppIntents
import Foundation
import MaramaoCore

// Focus filter: in System Settings → Focus → (a Focus) → Focus filters, the
// user can add "Maramao" and choose, for that Focus, whether the cats show
// up, which break mode to use and whether they make sounds.
//
// The system calls `perform()` whenever the Focus turns on or off (with the
// default values when it turns off, and the defaults change nothing).

/// Break modes as the Focus filter offers them. Raw values match `BreakModeID`,
/// plus `unchanged` for "whatever is in Settings".
enum FocusFilterBreakMode: String, AppEnum {
    case unchanged
    case walkingCat
    case memeWall
    case sleepyCat
    case catPile
    case laserChase
    case keyboardCat
    case birdWatching
    case random

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Modalità pausa"
    static let caseDisplayRepresentations: [FocusFilterBreakMode: DisplayRepresentation] = [
        .unchanged: "Come nelle impostazioni",
        .walkingCat: "Il gatto sulla finestra",
        .memeWall: "Muro di meme",
        .sleepyCat: "Non svegliare il gatto",
        .catPile: "Invasione di gatti",
        .laserChase: "Caccia al laser",
        .keyboardCat: "Il gatto sulla tastiera",
        .birdWatching: "Il gatto alla finestra",
        .random: "Sorpresa",
    ]
}

struct MaramaoFocusFilter: SetFocusFilterIntent {
    static let title: LocalizedStringResource = "Gatti di Maramao"
    static let description: IntentDescription? = IntentDescription(
        "Scegli come si comportano i gatti durante questa modalità Full immersion."
    )

    @Parameter(title: "Gatti nelle pause", default: true)
    var catsEnabled: Bool

    @Parameter(title: "Modalità pausa", default: .unchanged)
    var breakMode: FocusFilterBreakMode

    @Parameter(title: "Suoni", default: true)
    var soundsEnabled: Bool

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "Maramao", subtitle: "\(summary)")
    }

    var policy: FocusFilterPolicy {
        FocusFilterPolicy(
            catsEnabled: catsEnabled,
            breakModeOverride: breakMode == .unchanged ? nil : breakMode.rawValue,
            soundsEnabled: soundsEnabled
        )
    }

    /// One line for the Focus settings, e.g. "Niente gatti" or "Invasione di gatti · senza suoni".
    private var summary: String {
        guard catsEnabled else { return String(localized: "Niente gatti: la pausa resta solo nella barra dei menu") }
        var parts: [String] = []
        if breakMode != .unchanged, let mode = BreakModeID(rawValue: breakMode.rawValue) {
            parts.append(mode.title)
        } else {
            parts.append(String(localized: "Gatti come al solito"))
        }
        if !soundsEnabled { parts.append(String(localized: "senza suoni")) }
        return parts.joined(separator: " · ")
    }

    func perform() async throws -> some IntentResult {
        FocusFilterState.shared.apply(policy)
        return .result()
    }
}

/// The Focus filter currently in effect, kept in UserDefaults so it survives a
/// relaunch. Read it on the main thread.
final class FocusFilterState: ObservableObject {
    static let shared = FocusFilterState()

    @Published private(set) var policy: FocusFilterPolicy
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        policy = FocusFilterPolicy.load(from: defaults)
        refreshFromSystem()
    }

    /// The break mode for a real break, or nil when the Focus turned the cats off.
    func breakMode(default fallback: BreakModeID) -> BreakModeID? {
        guard let raw = policy.breakMode(default: fallback.rawValue) else { return nil }
        return BreakModeID(rawValue: raw) ?? fallback
    }

    func apply(_ newPolicy: FocusFilterPolicy) {
        newPolicy.store(in: defaults)
        if Thread.isMainThread {
            policy = newPolicy
        } else {
            DispatchQueue.main.async { self.policy = newPolicy }
        }
    }

    /// The Focus may have changed while Maramao was not running: ask the system.
    private func refreshFromSystem() {
        Task {
            if let current = try? await MaramaoFocusFilter.current {
                apply(current.policy)
            }
        }
    }
}
