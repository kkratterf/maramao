import Foundation

/// Every way a cat can stop you from working. `random` picks one of the others per break.
enum BreakModeID: String, CaseIterable, Identifiable {
    case laserChase
    case catPile
    case sleepyCat
    case random

    var id: String { rawValue }

    /// Concrete modes, without `random`.
    static var concrete: [BreakModeID] { allCases.filter { $0 != .random } }

    var emoji: String {
        switch self {
        case .laserChase: return "🔴"
        case .catPile: return "🐾"
        case .sleepyCat: return "😴"
        case .random: return "🎲"
        }
    }

    var title: String {
        switch self {
        case .laserChase: return String(localized: "Caccia al laser")
        case .catPile: return String(localized: "Invasione di gatti")
        case .sleepyCat: return String(localized: "Non svegliare il gatto")
        case .random: return String(localized: "Sorpresa")
        }
    }

    var subtitle: String {
        switch self {
        case .laserChase: return String(localized: "Il mouse diventa un puntino laser e il gatto lo insegue per tutto lo schermo.")
        case .catPile: return String(localized: "Piovono gatti dall'alto fino a seppellire tutto lo schermo.")
        case .sleepyCat: return String(localized: "Un gatto dorme a tutto schermo. Tocca mouse o tastiera e si sveglia arrabbiato.")
        case .random: return String(localized: "Ogni pausa un concept diverso.")
        }
    }

    /// Resolves `random` to a concrete mode.
    func resolved() -> BreakModeID {
        self == .random ? (BreakModeID.concrete.randomElement() ?? .laserChase) : self
    }
}
