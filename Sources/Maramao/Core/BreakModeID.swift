import Foundation

/// Every way a cat can stop you from working. `random` picks one of the others per break.
enum BreakModeID: String, CaseIterable, Identifiable {
    case walkingCat
    case memeWall
    case sleepyCat
    case catPile
    case laserChase
    case keyboardCat
    case random

    var id: String { rawValue }

    /// Concrete modes, without `random`.
    static var concrete: [BreakModeID] { allCases.filter { $0 != .random } }

    var emoji: String {
        switch self {
        case .walkingCat: return "🐈"
        case .memeWall: return "😹"
        case .sleepyCat: return "😴"
        case .catPile: return "🐾"
        case .laserChase: return "🔴"
        case .keyboardCat: return "⌨️"
        case .random: return "🎲"
        }
    }

    var title: String {
        switch self {
        case .walkingCat: return String(localized: "Il gatto sulla finestra")
        case .memeWall: return String(localized: "Muro di meme")
        case .sleepyCat: return String(localized: "Non svegliare il gatto")
        case .catPile: return String(localized: "Invasione di gatti")
        case .laserChase: return String(localized: "Caccia al laser")
        case .keyboardCat: return String(localized: "Il gatto sulla tastiera")
        case .random: return String(localized: "Sorpresa")
        }
    }

    var subtitle: String {
        switch self {
        case .walkingCat: return String(localized: "Un gatto attraversa lo schermo e si siede proprio sulla finestra su cui lavori.")
        case .memeWall: return String(localized: "Lo schermo si riempie di GIF e meme di gatti finché la pausa non è finita.")
        case .sleepyCat: return String(localized: "Un gatto dorme sullo schermo: se tocchi il mouse si sveglia e ti giudica.")
        case .catPile: return String(localized: "Piovono gatti dall'alto fino a seppellire tutto lo schermo.")
        case .laserChase: return String(localized: "Il mouse diventa un puntino laser e il gatto lo insegue per tutto lo schermo.")
        case .keyboardCat: return String(localized: "Un gatto dorme sulla tastiera: qualunque cosa scrivi, la scrive lui.")
        case .random: return String(localized: "Ogni pausa un concept diverso.")
        }
    }

    /// Resolves `random` to a concrete mode.
    func resolved() -> BreakModeID {
        self == .random ? (BreakModeID.concrete.randomElement() ?? .walkingCat) : self
    }
}
