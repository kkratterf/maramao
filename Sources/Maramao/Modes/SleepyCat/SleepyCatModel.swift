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
        case .asleep: return String(localized: "Shhh… il gatto dorme. Non svegliarlo.")
        case .drowsy: return String(localized: "Si sta riaddormentando… piano.")
        case .startled, .awake: return String(localized: "L'hai svegliato! Giù le mani.")
        case .stretching: return String(localized: "Il gatto si stiracchia. Pausa finita.")
        }
    }
}

/// What the cat says when it is woken up, from mildly sleepy to properly angry.
enum SleepyCatLines {
    static let calm: [String] = [
        String(localized: "Mrrr? Ti avevo detto di riposare."),
        String(localized: "Il mouse non scappa."),
        String(localized: "Vai a bere un bicchiere d'acqua."),
        String(localized: "Alzati e sgranchisciti, umano."),
        String(localized: "Shh… stavo sognando un tonno."),
        String(localized: "Guarda fuori dalla finestra, non lo schermo."),
        String(localized: "Le email possono aspettare. Io no."),
        String(localized: "Rilassa le spalle. Ecco, così."),
        String(localized: "Fai due respiri profondi. Poi lasciami dormire."),
    ]

    static let annoyed: [String] = [
        String(localized: "Di nuovo? Sul serio?"),
        String(localized: "Ho detto PAUSA."),
        String(localized: "Ogni volta che tocchi il mouse un gatto perde un pisolino."),
        String(localized: "Ti vedo, sai. Dormo con un occhio solo."),
        String(localized: "Il lavoro sarà ancora lì tra cinque minuti."),
        String(localized: "Vai a fare due passi. Lontano dalla scrivania."),
        String(localized: "Questa è la mia pausa. E anche la tua."),
        String(localized: "Mrrrau. Ultimo avvertimento… forse."),
    ]

    static let angry: [String] = [
        String(localized: "😾 Basta! Sto cercando di dormire!"),
        String(localized: "😾 Un'altra mossa e ti butto il caffè dalla scrivania."),
        String(localized: "😾 Mani lontane dalla tastiera. Subito."),
        String(localized: "😾 Mi siedo sulla tastiera, giuro."),
        String(localized: "😾 Pausa vuol dire PAUSA, umano."),
        String(localized: "😾 Sto contando fino a nove. Come le mie vite."),
        String(localized: "😾 HSSSS!"),
        String(localized: "😾 Stanotte ti miagolo alle quattro."),
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
        String(localized: "Il gatto ha dormito il \(percent)% della pausa")
    }

    static func result(percent: Int) -> String {
        switch percent {
        case 90...: return String(localized: "Pausa perfetta! 😻")
        case 70..<90: return String(localized: "Bella pausa, quasi perfetta 😺")
        case 40..<70: return String(localized: "Il gatto ha sonnecchiato a tratti 😼")
        default: return String(localized: "Il gatto non ha chiuso occhio 🙀")
        }
    }
}
