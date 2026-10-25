import SwiftUI

/// Shared, observable state of the sleepy cat. The break mode drives it, the scene views draw it.
@MainActor
final class SleepyCatModel: ObservableObject {
    enum Phase: Equatable {
        /// Curled up and breathing slowly. The only phase that counts as sleep.
        case asleep
        /// Just woken up: a quick jump with eyes wide open.
        case startled
        /// Sitting, eyes open, glaring at the user.
        case awake
        /// Nobody moved for a while: eyes closed, about to curl up again.
        case drowsy
        /// The break is over: a peaceful stretch before leaving.
        case stretching
    }

    @Published private(set) var phase: Phase = .asleep
    /// When the current phase started, used by the views for time-based animations.
    @Published private(set) var phaseStart = Date()
    @Published var line = ""
    @Published var annoyance = 0
    @Published var sleepPercent = 100
    @Published var resultLine: String?

    let palette: CatPalette

    init(palette: CatPalette) {
        self.palette = palette
    }

    func setPhase(_ newPhase: Phase) {
        guard newPhase != phase else { return }
        phase = newPhase
        phaseStart = Date()
    }

    var isAwake: Bool { phase == .startled || phase == .awake }

    var hudMessage: String {
        switch phase {
        case .asleep: return "Shhh… il gatto dorme. Non svegliarlo."
        case .drowsy: return "Si sta riaddormentando… piano."
        case .startled, .awake: return "L'hai svegliato! Giù le mani."
        case .stretching: return "Il gatto si stiracchia. Pausa finita."
        }
    }
}

/// What the cat says when it is woken up, from mildly sleepy to properly angry.
enum SleepyCatLines {
    static let calm: [String] = [
        "Mrrr? Ti avevo detto di riposare.",
        "Il mouse non scappa.",
        "Vai a bere un bicchiere d'acqua.",
        "Alzati e sgranchisciti, umano.",
        "Shh… stavo sognando un tonno.",
        "Guarda fuori dalla finestra, non lo schermo.",
        "Le email possono aspettare. Io no.",
        "Rilassa le spalle. Ecco, così.",
        "Fai due respiri profondi. Poi lasciami dormire.",
    ]

    static let annoyed: [String] = [
        "Di nuovo? Sul serio?",
        "Ho detto PAUSA.",
        "Ogni volta che tocchi il mouse un gatto perde un pisolino.",
        "Ti vedo, sai. Dormo con un occhio solo.",
        "Il lavoro sarà ancora lì tra cinque minuti.",
        "Vai a fare due passi. Lontano dalla scrivania.",
        "Questa è la mia pausa. E anche la tua.",
        "Mrrrau. Ultimo avvertimento… forse.",
    ]

    static let angry: [String] = [
        "😾 Basta! Sto cercando di dormire!",
        "😾 Un'altra mossa e ti butto il caffè dalla scrivania.",
        "😾 Mani lontane dalla tastiera. Subito.",
        "😾 Mi siedo sulla tastiera, giuro.",
        "😾 Pausa vuol dire PAUSA, umano.",
        "😾 Sto contando fino a nove. Come le mie vite.",
        "😾 HSSSS!",
        "😾 Stanotte ti miagolo alle quattro.",
    ]

    /// A line matching the annoyance level, avoiding an immediate repeat.
    static func pick(annoyance: Int, avoiding previous: String) -> String {
        let pool: [String]
        switch annoyance {
        case ..<2: pool = calm
        case 2...3: pool = annoyed
        default: pool = angry
        }
        let candidates = pool.filter { $0 != previous }
        return candidates.randomElement() ?? pool.first ?? ""
    }

    static func stat(percent: Int) -> String {
        "Il gatto ha dormito il \(percent)% della pausa"
    }

    static func result(percent: Int) -> String {
        switch percent {
        case 90...: return "Pausa perfetta! 😻"
        case 70..<90: return "Bella pausa, quasi perfetta 😺"
        case 40..<70: return "Il gatto ha sonnecchiato a tratti 😼"
        default: return "Il gatto non ha chiuso occhio 🙀"
        }
    }
}
