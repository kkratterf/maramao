import Foundation

/// Every way a cat can stop you from working. `random` picks one of the others per break.
enum BreakModeID: String, CaseIterable, Identifiable {
    case walkingCat
    case memeWall
    case sleepyCat
    case catPile
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
        case .random: return "🎲"
        }
    }

    var title: String {
        switch self {
        case .walkingCat: return "Il gatto sulla finestra"
        case .memeWall: return "Muro di meme"
        case .sleepyCat: return "Non svegliare il gatto"
        case .catPile: return "Invasione di gatti"
        case .random: return "Sorpresa"
        }
    }

    var subtitle: String {
        switch self {
        case .walkingCat: return "Un gatto attraversa lo schermo e si siede proprio sulla finestra su cui lavori."
        case .memeWall: return "Lo schermo si riempie di GIF e meme di gatti finché la pausa non è finita."
        case .sleepyCat: return "Un gatto dorme sullo schermo: se tocchi il mouse si sveglia e ti giudica."
        case .catPile: return "Piovono gatti dall'alto fino a seppellire tutto lo schermo."
        case .random: return "Ogni pausa un concept diverso."
        }
    }

    /// Resolves `random` to a concrete mode.
    func resolved() -> BreakModeID {
        self == .random ? (BreakModeID.concrete.randomElement() ?? .walkingCat) : self
    }
}
