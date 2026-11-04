import Foundation

/// What the cat says under its photo in "Non svegliare il gatto": one line while it
/// sleeps, and a dry, passive-aggressive remark every time someone wakes it up.
public enum SleepyCatLines {
    /// Under the sleeping cat.
    public static var asleep: String {
        String(localized: "Sto dormendo. Non disturbarmi.")
    }

    /// The remarks of a woken cat, in a fixed order. `breakMinutes` is the length of the break.
    public static func angry(breakMinutes: Int) -> [String] {
        let minutes = max(1, breakMinutes)
        return [
            String(localized: "Pausa vuol dire pausa. Te lo devo spiegare?"),
            String(localized: "Non riesci davvero a staccarti dal computer per \(minutes) minuti?"),
            String(localized: "Pausa vuol dire pausa."),
            String(localized: "Fai pure come se io non ci fossi."),
            String(localized: "Continua pure a lavorare. Ti fa benissimo."),
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
