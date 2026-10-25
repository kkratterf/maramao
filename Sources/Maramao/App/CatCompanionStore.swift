import Foundation
import MaramaoCore

/// Keeps "Il tuo gatto" (`CatCompanion`) in UserDefaults as JSON and publishes changes to the UI.
/// Every method is a no-op while the companion is turned off in Settings.
@MainActor
final class CatCompanionStore: ObservableObject {
    static let shared = CatCompanionStore()

    @Published private(set) var companion: CatCompanion

    private let defaults: UserDefaults
    private let settings: AppSettings
    private static let key = "catCompanion.v1"
    /// Pets counted during the break on screen; reset when a break (or preview) starts.
    private var petsThisBreak = 0

    init(defaults: UserDefaults = .standard, settings: AppSettings = .shared) {
        self.defaults = defaults
        self.settings = settings
        if let data = defaults.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(CatCompanion.self, from: data) {
            companion = decoded
        } else {
            companion = CatCompanion()
        }
    }

    var isEnabled: Bool { settings.companionEnabled }
    var mood: CatMood { companion.mood }

    // MARK: - Breaks

    func breakBegan() {
        petsThisBreak = 0
    }

    func recordBreak(respected: Bool, mode: BreakModeID?) {
        guard isEnabled else { return }
        companion.recordBreak(respected: respected, mode: mode?.rawValue)
        save()
    }

    /// The line the cat says when a break starts, or `fallback` while the companion is off.
    func greeting(fallback: String) -> String {
        guard isEnabled else { return fallback }
        return CatCompanionText.greetings(mood: companion.mood, name: companion.name).randomElement() ?? fallback
    }

    /// The mood that drives poses during a break; neutral while the companion is off.
    var breakMood: CatMood { isEnabled ? companion.mood : .calm }

    // MARK: - Cuddles and treats

    /// A pet during a break. Returns the cat's reaction when the pet counted, nil otherwise
    /// (companion off, or enough pets already this break).
    @discardableResult
    func pet() -> String? {
        guard isEnabled else { return nil }
        guard companion.pet(alreadyThisBreak: petsThisBreak) else { return nil }
        petsThisBreak += 1
        save()
        return CatCompanionText.petReactions(mood: companion.mood).randomElement()
    }

    /// Gives one earned treat. Returns the cat's reaction, or nil when there was none.
    @discardableResult
    func giveTreat() -> String? {
        guard isEnabled, companion.giveTreat() else { return nil }
        save()
        CatSounds.shared.chirp()
        return CatCompanionText.treatReaction(mood: companion.mood)
    }

    func rename(_ name: String) {
        companion.rename(name)
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(companion) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
