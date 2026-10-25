import Foundation

/// What the cat suggests doing during a break, so the break is actually restful
/// (and not spent on the phone). Short breaks get quick eye, hand and posture ideas;
/// long breaks get ideas that need a few minutes and leaving the desk.
public enum BreakTips {
    /// Quick ideas for a short break: eyes, hands, posture, breathing, water.
    public static let short: [String] = [
        "Stiracchiati come un gatto: braccia avanti, schiena ad arco.",
        "Regola 20-20-20: guarda lontano, almeno 6 metri, per 20 secondi.",
        "Bevi un po' d'acqua. Io bevo dal rubinetto.",
        "Chiudi gli occhi e conta dieci respiri lenti.",
        "Ruota piano le spalle: cinque volte avanti, cinque indietro.",
        "Apri e chiudi le mani, poi scuoti i polsi. Zampe nuove.",
        "Sbatti le palpebre venti volte: gli occhi ringraziano.",
        "Inclina la testa a destra e a sinistra, piano, come un gatto curioso.",
        "Alzati in piedi e allunga le braccia verso il soffitto.",
        "Raddrizza la schiena e rilassa la mascella. Così.",
        "Guarda fuori dalla finestra e cerca qualcosa che si muove.",
        "Fai le fusa: un respiro lungo dal naso, fuori piano dalla bocca.",
        "Allunga le dita all'indietro, una mano alla volta, per dieci secondi.",
        "Alzati e gira per la stanza come se fosse tua.",
    ]

    /// Ideas for a long break: move, eat, get some air, leave the desk.
    public static let long: [String] = [
        "Fai una passeggiata, anche solo intorno all'isolato.",
        "Prepara un tè o un caffè, senza telefono in mano.",
        "Mangia qualcosa di buono, lontano dalla scrivania.",
        "Esci a prendere un po' d'aria e di luce.",
        "Riempi la borraccia e bevi un bicchiere intero d'acqua.",
        "Fai le scale su e giù un paio di volte.",
        "Sdraiati cinque minuti e non fare niente. Da professionisti.",
        "Fai una serie di stiramenti per gambe, schiena e collo.",
        "Annaffia le piante o sistema qualcosa in casa.",
        "Chiama o scrivi a qualcuno a cui vuoi bene.",
        "Apri la finestra e cambia l'aria nella stanza.",
        "Metti una canzone e muoviti un po'. Nessuno ti guarda (tranne me).",
        "Esci sul balcone e guarda il cielo per un minuto.",
        "Fai merenda. I gatti approvano gli snack.",
    ]

    public static func tips(isLongBreak: Bool) -> [String] {
        isLongBreak ? long : short
    }
}

/// Picks a break tip without repeating the previous one.
public struct BreakTipPicker: Sendable {
    public let shortTips: [String]
    public let longTips: [String]
    /// The last tip handed out, of either kind.
    public private(set) var last: String?

    public init(shortTips: [String] = BreakTips.short, longTips: [String] = BreakTips.long, last: String? = nil) {
        self.shortTips = shortTips
        self.longTips = longTips
        self.last = last
    }

    /// A random tip for the kind of break, never equal to the previous tip
    /// (unless the list has a single tip). Returns "" if the list is empty.
    public mutating func next<G: RandomNumberGenerator>(isLongBreak: Bool, using generator: inout G) -> String {
        let pool = isLongBreak ? longTips : shortTips
        guard !pool.isEmpty else { return "" }
        var candidates = pool.filter { $0 != last }
        if candidates.isEmpty { candidates = pool }
        let index = Int.random(in: 0..<candidates.count, using: &generator)
        let tip = candidates[index]
        last = tip
        return tip
    }

    public mutating func next(isLongBreak: Bool) -> String {
        var generator = SystemRandomNumberGenerator()
        return next(isLongBreak: isLongBreak, using: &generator)
    }
}
