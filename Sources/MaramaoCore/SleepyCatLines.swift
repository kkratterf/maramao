import Foundation

/// What the cat says under its photo in "Non svegliare il gatto": one calm line while it
/// sleeps, and passive-aggressive remarks every time someone wakes it up.
public enum SleepyCatLines {
    /// Under the sleeping cat.
    public static var asleep: String {
        String(localized: "Shh… il gatto dorme. Non toccare niente.")
    }

    /// The remarks of a woken cat, in a fixed order. `breakMinutes` is the length of the
    /// break, `wakeUps` how many times the cat was woken so far in this break (1 or more).
    public static func angry(breakMinutes: Int, wakeUps: Int) -> [String] {
        let minutes = max(1, breakMinutes)
        let times = max(1, wakeUps)
        return [
            String(localized: "Non riesci a stare senza computer per \(minutes) minuti?"),
            String(localized: "Ah, ok. Le mail sono più importanti del mio sonno."),
            String(localized: "Mi hai svegliato per guardare Slack? Davvero?"),
            String(localized: "Non ti giudico. Ok, ti giudico."),
            String(localized: "Il tuo capo non ti vede. Io sì."),
            String(localized: "Fai pure. Tanto io non dimentico."),
            String(localized: "Ti sembra il momento?"),
            String(localized: "Muovi ancora quel mouse e ti butto il bicchiere giù dal tavolo."),
            String(localized: "Quando io mi siedo sulla tastiera, ti lamenti. Ecco."),
            String(localized: "Alzati. Stiracchiati. Bevi un bicchiere d'acqua. Lasciami dormire."),
            String(localized: "Che bello farsi svegliare. Grazie, eh."),
            String(localized: "Mi hai svegliato \(times) volte. Sto tenendo il conto."),
        ]
    }
}

/// Hands out indices 0..<count in a shuffled order, every index once before any repeats,
/// and never the same index twice in a row across rounds.
public struct ShuffleBag: Sendable {
    public let count: Int
    private var bag: [Int] = []
    private var last: Int?

    public init(count: Int) {
        self.count = max(0, count)
    }

    public mutating func next() -> Int? {
        guard count > 0 else { return nil }
        if bag.isEmpty {
            bag = Array(0..<count).shuffled()
            // The round is consumed from the end: keep the previous pick away from it.
            if count > 1, bag.last == last {
                bag.swapAt(0, bag.count - 1)
            }
        }
        let pick = bag.removeLast()
        last = pick
        return pick
    }
}
