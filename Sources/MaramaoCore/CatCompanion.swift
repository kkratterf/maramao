import Foundation

/// How the cat feels about you, derived from its affection.
public enum CatMood: String, CaseIterable, Sendable {
    case grumpy
    case sulky
    case calm
    case happy
    case delighted

    public static func from(affection: Int) -> CatMood {
        switch affection {
        case ..<20: return .grumpy
        case ..<40: return .sulky
        case ..<60: return .calm
        case ..<80: return .happy
        default: return .delighted
        }
    }

    /// Short Italian label, worded so it works whatever the cat's name.
    public var label: String {
        switch self {
        case .grumpy: return String(localized: "Ti tiene il muso")
        case .sulky: return String(localized: "Un po' di malumore")
        case .calm: return String(localized: "In pace col mondo")
        case .happy: return String(localized: "Di buon umore")
        case .delighted: return String(localized: "Al settimo cielo")
        }
    }

    public var emoji: String {
        switch self {
        case .grumpy: return "😾"
        case .sulky: return "😼"
        case .calm: return "🐱"
        case .happy: return "😺"
        case .delighted: return "😻"
        }
    }

    /// True for the moods that earn happier poses during a break.
    public var isHappy: Bool { self == .happy || self == .delighted }
    /// True for the moods that make the cat a little standoffish.
    public var isGrumpy: Bool { self == .grumpy || self == .sulky }
}

/// The cat that remembers you: its name, how fond of you it is, the treats you earned
/// by respecting breaks, and the break mode you spend most time with.
///
/// Gentle on purpose: a skipped break costs a little affection, never treats, and the
/// cat always comes round again after a few respected breaks or a treat.
public struct CatCompanion: Codable, Equatable, Sendable {
    public static let defaultName = "Maramao"
    public static let maxNameLength = 24
    public static let maxAffection = 100
    public static let startingAffection = 50
    public static let maxTreats = 10
    /// Only the first pets of each break count, so clicking frantically does not farm affection.
    public static let petsCountedPerBreak = 3

    public static let respectedBreakBonus = 4
    public static let skippedBreakPenalty = 6
    public static let petBonus = 1
    public static let treatBonus = 8

    public private(set) var name: String
    public private(set) var affection: Int
    /// Treats earned and not given yet.
    public private(set) var treats: Int
    public private(set) var treatsGiven: Int
    public private(set) var pets: Int
    /// Respected breaks in a row; a skipped break resets it.
    public private(set) var streak: Int
    public private(set) var bestStreak: Int
    /// Respected breaks per break mode (raw value of `BreakModeID`).
    public private(set) var modeCounts: [String: Int]

    public init(name: String = CatCompanion.defaultName, affection: Int = CatCompanion.startingAffection) {
        self.name = CatCompanion.sanitizedName(name)
        self.affection = CatCompanion.clampAffection(affection)
        self.treats = 0
        self.treatsGiven = 0
        self.pets = 0
        self.streak = 0
        self.bestStreak = 0
        self.modeCounts = [:]
    }

    public var mood: CatMood { CatMood.from(affection: affection) }

    /// The mode with the most respected breaks; ties go to the alphabetically first one.
    public var favouriteMode: String? {
        let best = modeCounts.filter { $0.value > 0 }.max { lhs, rhs in
            lhs.value != rhs.value ? lhs.value < rhs.value : lhs.key > rhs.key
        }
        return best?.key
    }

    public var canGiveTreat: Bool { treats > 0 }

    // MARK: - Events

    /// Records the end of a real break. A respected break earns a treat (up to `maxTreats`)
    /// and some affection; a skipped one costs a bit of affection and the streak.
    /// Returns true when a new treat was earned.
    @discardableResult
    public mutating func recordBreak(respected: Bool, mode: String?) -> Bool {
        guard respected else {
            affection = Self.clampAffection(affection - Self.skippedBreakPenalty)
            streak = 0
            return false
        }
        affection = Self.clampAffection(affection + Self.respectedBreakBonus)
        streak += 1
        bestStreak = max(bestStreak, streak)
        if let mode, !mode.isEmpty {
            modeCounts[mode, default: 0] += 1
        }
        guard treats < Self.maxTreats else { return false }
        treats += 1
        return true
    }

    /// A pet during a break. `alreadyThisBreak` is how many pets this break counted so far.
    /// Returns true when the pet counted towards affection.
    @discardableResult
    public mutating func pet(alreadyThisBreak: Int) -> Bool {
        guard alreadyThisBreak < Self.petsCountedPerBreak else { return false }
        pets += 1
        affection = Self.clampAffection(affection + Self.petBonus)
        return true
    }

    /// Gives one earned treat. Returns false when there is none to give.
    @discardableResult
    public mutating func giveTreat() -> Bool {
        guard treats > 0 else { return false }
        treats -= 1
        treatsGiven += 1
        affection = Self.clampAffection(affection + Self.treatBonus)
        return true
    }

    public mutating func rename(_ raw: String) {
        name = Self.sanitizedName(raw)
    }

    // MARK: - Helpers

    /// Trims whitespace and newlines, caps the length and falls back to the default name.
    public static func sanitizedName(_ raw: String) -> String {
        let collapsed = raw
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !collapsed.isEmpty else { return defaultName }
        return String(collapsed.prefix(maxNameLength))
    }

    static func clampAffection(_ value: Int) -> Int {
        min(maxAffection, max(0, value))
    }

    // MARK: - Codable (tolerant: missing or odd values fall back to sane defaults)

    private enum CodingKeys: String, CodingKey {
        case name, affection, treats, treatsGiven, pets, streak, bestStreak, modeCounts
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = Self.sanitizedName(try container.decodeIfPresent(String.self, forKey: .name) ?? Self.defaultName)
        affection = Self.clampAffection(try container.decodeIfPresent(Int.self, forKey: .affection) ?? Self.startingAffection)
        treats = min(Self.maxTreats, max(0, try container.decodeIfPresent(Int.self, forKey: .treats) ?? 0))
        treatsGiven = max(0, try container.decodeIfPresent(Int.self, forKey: .treatsGiven) ?? 0)
        pets = max(0, try container.decodeIfPresent(Int.self, forKey: .pets) ?? 0)
        streak = max(0, try container.decodeIfPresent(Int.self, forKey: .streak) ?? 0)
        bestStreak = max(streak, try container.decodeIfPresent(Int.self, forKey: .bestStreak) ?? 0)
        modeCounts = (try container.decodeIfPresent([String: Int].self, forKey: .modeCounts) ?? [:])
            .filter { $0.value > 0 }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(affection, forKey: .affection)
        try container.encode(treats, forKey: .treats)
        try container.encode(treatsGiven, forKey: .treatsGiven)
        try container.encode(pets, forKey: .pets)
        try container.encode(streak, forKey: .streak)
        try container.encode(bestStreak, forKey: .bestStreak)
        try container.encode(modeCounts, forKey: .modeCounts)
    }
}

/// Italian lines for the companion. Kind even when the cat is grumpy: it teases, it never scolds.
public enum CatCompanionText {
    /// What the cat says when a break starts.
    public static func greetings(mood: CatMood, name: String) -> [String] {
        switch mood {
        case .delighted:
            return [
                String(localized: "Eccoti! Ti aspettavo."),
                String(localized: "Pausa con te? Il mio momento preferito."),
                String(localized: "\(name) è tutto per te."),
            ]
        case .happy:
            return [
                String(localized: "Ciao umano, pausa insieme?"),
                String(localized: "Questa finestra adesso è mia."),
                String(localized: "Mrrr, finalmente."),
            ]
        case .calm:
            return [String(localized: "Questa finestra adesso è mia."), String(localized: "Riposati, umano.")]
        case .sulky:
            return [
                String(localized: "Ah, adesso ti ricordi di me."),
                String(localized: "Questa finestra è mia. E basta."),
            ]
        case .grumpy:
            return [
                String(localized: "Hmpf. Vediamo se stavolta la pausa la fai."),
                String(localized: "Ti tengo il muso. Però resto qui."),
            ]
        }
    }

    /// What the cat says when it is petted (and the pet counted).
    public static func petReactions(mood: CatMood) -> [String] {
        switch mood {
        case .delighted: return [
            String(localized: "Prrrrr ❤︎"),
            String(localized: "Ancora, ancora!"),
            String(localized: "Sei il mio umano preferito."),
        ]
        case .happy: return [
            String(localized: "Mrrr."),
            String(localized: "Prrr…"),
            String(localized: "Ancora coccole."),
        ]
        case .calm: return [String(localized: "Mrrr."), String(localized: "Prrr…")]
        case .sulky: return [
            String(localized: "Mh. Va bene, continua."),
            String(localized: "Non ti ho ancora perdonato. Prrr."),
        ]
        case .grumpy: return [
            String(localized: "…ok, solo un attimo."),
            String(localized: "Non pensare che basti. Prrr."),
        ]
        }
    }

    /// What the cat says when it gets a treat.
    public static func treatReaction(mood: CatMood) -> String {
        switch mood {
        case .grumpy, .sulky: return String(localized: "Gnam. Ti perdono, forse. 🐟")
        case .calm: return String(localized: "Gnam! 🐟")
        case .happy, .delighted: return String(localized: "Gnam gnam! Ti voglio bene. 🐟")
        }
    }

    /// What the cat says when dropped after being dragged.
    public static let dropLines = [
        String(localized: "Ehi! Mettimi giù piano."),
        String(localized: "Wheee!"),
        String(localized: "Lo sapevo che volevi giocare."),
        String(localized: "Torno al mio posto."),
    ]

    /// "3 croccantini", for the menu and Settings.
    public static func treatsLine(_ treats: Int) -> String {
        switch treats {
        case ..<1: return String(localized: "Nessun croccantino")
        case 1: return String(localized: "1 croccantino")
        default: return String(localized: "\(treats) croccantini")
        }
    }

    /// "Di buon umore 😺", for the menu and Settings.
    public static func moodLine(_ companion: CatCompanion) -> String {
        "\(companion.mood.label) \(companion.mood.emoji)"
    }

    public static let earnTreatHint = String(localized: "Rispetta una pausa per guadagnare un croccantino.")
}
