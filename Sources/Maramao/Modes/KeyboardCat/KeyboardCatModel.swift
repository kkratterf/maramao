import SwiftUI

/// One key of the drawn keyboard, in keyboard units (1 unit = one letter key pitch).
struct KeyboardCatKey: Identifiable {
    let id: Int
    let label: String
    /// Frame in units, origin at the top-left corner of the keyboard body.
    let rect: CGRect
    /// Physical key codes (`NSEvent.keyCode`) that light this key.
    let keyCodes: [UInt16]
    /// Character the cat types with this key, lowercase. `nil` for modifiers and the like.
    let character: Character?
    /// Small labels for modifier and function keys.
    let isSmallLabel: Bool
}

/// A stylised Mac keyboard with the Italian layout, and where the cat lies on it.
/// Everything is in keyboard units; views scale it to points.
enum KeyboardCatLayout {
    static let padding: CGFloat = 0.4
    static let functionRowHeight: CGFloat = 0.62
    static let functionRowGap: CGFloat = 0.14
    static let rowsTop: CGFloat = padding + functionRowHeight + functionRowGap
    static let width: CGFloat = 15 + padding * 2
    static let height: CGFloat = rowsTop + 5 + padding - 0.08

    /// The cat's loaf over the middle of the keyboard (body ellipse bounds, in units).
    static let catBody = CGRect(x: padding + 4.7, y: rowsTop + 0.8, width: 7.2, height: 2.95)

    /// The CatView frame that puts the sleeping body exactly on `catBody`.
    /// In CatView's 200×160 design the sleeping body spans x 35…175 and y 95…153.
    static var catFrame: CGRect {
        let frameWidth = catBody.width / (140.0 / 200.0)
        let frameHeight = frameWidth * 0.8
        let minX = catBody.minX - frameWidth * (35.0 / 200.0)
        let minY = catBody.minY - frameHeight * (95.0 / 160.0)
        return CGRect(x: minX, y: minY, width: frameWidth, height: frameHeight)
    }

    private struct Spec {
        let label: String
        let width: CGFloat
        let codes: [UInt16]
        let character: Character?
        let small: Bool

        init(_ label: String, _ width: CGFloat = 1, _ codes: [UInt16], _ character: Character? = nil, small: Bool = false) {
            self.label = label
            self.width = width
            self.codes = codes
            self.character = character
            self.small = small
        }
    }

    private static func letter(_ label: String, _ code: UInt16) -> Spec {
        Spec(label.uppercased(), 1, [code], Character(label))
    }

    private static func symbol(_ label: String, _ code: UInt16, _ character: Character) -> Spec {
        Spec(label, 1, [code], character)
    }

    static let keys: [KeyboardCatKey] = build()

    private static func build() -> [KeyboardCatKey] {
        let functionRow: [Spec] = [
            Spec("esc", 1.5, [53], nil, small: true),
            Spec("F1", 1, [122], nil, small: true), Spec("F2", 1, [120], nil, small: true),
            Spec("F3", 1, [99], nil, small: true), Spec("F4", 1, [118], nil, small: true),
            Spec("F5", 1, [96], nil, small: true), Spec("F6", 1, [97], nil, small: true),
            Spec("F7", 1, [98], nil, small: true), Spec("F8", 1, [100], nil, small: true),
            Spec("F9", 1, [101], nil, small: true), Spec("F10", 1, [109], nil, small: true),
            Spec("F11", 1, [103], nil, small: true), Spec("F12", 1, [111], nil, small: true),
            Spec("", 1.5, [], nil, small: true),
        ]
        let numberRow: [Spec] = [
            symbol("\\", 10, "\\"),
            symbol("1", 18, "1"), symbol("2", 19, "2"), symbol("3", 20, "3"), symbol("4", 21, "4"),
            symbol("5", 23, "5"), symbol("6", 22, "6"), symbol("7", 26, "7"), symbol("8", 28, "8"),
            symbol("9", 25, "9"), symbol("0", 29, "0"), symbol("'", 27, "'"), symbol("ì", 24, "ì"),
            Spec("⌫", 2, [51], nil, small: true),
        ]
        let topRow: [Spec] = [
            Spec("⇥", 1.5, [48], nil, small: true),
            letter("q", 12), letter("w", 13), letter("e", 14), letter("r", 15), letter("t", 17),
            letter("y", 16), letter("u", 32), letter("i", 34), letter("o", 31), letter("p", 35),
            symbol("è", 33, "è"), symbol("+", 30, "+"),
            Spec("↩", 1.5, [36, 76], nil, small: true),
        ]
        let homeRow: [Spec] = [
            Spec("⇪", 1.75, [57], nil, small: true),
            letter("a", 0), letter("s", 1), letter("d", 2), letter("f", 3), letter("g", 5),
            letter("h", 4), letter("j", 38), letter("k", 40), letter("l", 37),
            symbol("ò", 41, "ò"), symbol("à", 39, "à"), symbol("ù", 42, "ù"),
            Spec("", 1.25, [36, 76], nil, small: true),
        ]
        let bottomRow: [Spec] = [
            Spec("⇧", 1.25, [56], nil, small: true),
            symbol("<", 50, "<"),
            letter("z", 6), letter("x", 7), letter("c", 8), letter("v", 9), letter("b", 11),
            letter("n", 45), letter("m", 46),
            symbol(",", 43, ","), symbol(".", 47, "."), symbol("-", 44, "-"),
            Spec("⇧", 2.75, [60], nil, small: true),
        ]
        let spaceRow: [Spec] = [
            Spec("fn", 1, [63], nil, small: true),
            Spec("⌃", 1, [59, 62], nil, small: true),
            Spec("⌥", 1, [58], nil, small: true),
            Spec("⌘", 1.25, [55], nil, small: true),
            Spec("", 5.5, [49], " ", small: true),
            Spec("⌘", 1.25, [54], nil, small: true),
            Spec("⌥", 1, [61], nil, small: true),
            Spec("◀", 1, [123], nil, small: true),
            Spec("▲▼", 1, [126, 125], nil, small: true),
            Spec("▶", 1, [124], nil, small: true),
        ]

        var result: [KeyboardCatKey] = []
        func addRow(_ specs: [Spec], top: CGFloat, height: CGFloat) {
            var x = padding
            for spec in specs {
                let rect = CGRect(x: x, y: top, width: spec.width, height: height)
                result.append(KeyboardCatKey(
                    id: result.count,
                    label: spec.label,
                    rect: rect,
                    keyCodes: spec.codes,
                    character: spec.character,
                    isSmallLabel: spec.small
                ))
                x += spec.width
            }
        }
        addRow(functionRow, top: padding, height: functionRowHeight)
        let rows = [numberRow, topRow, homeRow, bottomRow, spaceRow]
        for (index, row) in rows.enumerated() {
            addRow(row, top: rowsTop + CGFloat(index), height: 1)
        }
        return result
    }

    /// Keys lit by a physical key code.
    static func keys(forKeyCode code: UInt16) -> [Int] {
        keys.filter { $0.keyCodes.contains(code) }.map(\.id)
    }

    /// The first key that types `character`.
    static func key(for character: Character) -> Int? {
        keys.first { $0.character == character }?.id
    }

    /// Keys whose centre is under the cat's body.
    static let keysUnderCat: [Int] = keys.filter { key in
        let cx = catBody.midX
        let cy = catBody.midY
        let dx = (key.rect.midX - cx) / (catBody.width / 2)
        let dy = (key.rect.midY - cy) / (catBody.height / 2)
        return dx * dx + dy * dy <= 1
    }.map(\.id)
}

/// Shared, observable state of the keyboard cat. The break mode drives it, the views draw it.
@MainActor
final class KeyboardCatModel: ObservableObject {
    enum Phase: Equatable {
        case asleep
        /// The break is over: a stretch before leaving.
        case stretching
    }

    @Published private(set) var phase: Phase = .asleep
    @Published private(set) var phaseStart = Date()
    /// What the cat has "typed" so far.
    @Published var typed = ""
    /// Keys the user pressed, lit in white.
    @Published var pressedKeys: Set<Int> = []
    /// Keys the cat is lying on and "typing", lit in warm orange.
    @Published var catKeys: Set<Int> = []
    @Published var bubble: String?
    /// Last time the cat twitched (tail and a little shiver), for the views' animation.
    @Published var twitchDate = Date.distantPast
    @Published var hudMessage = "Il gatto dorme sulla tastiera."

    let palette: CatPalette

    init(palette: CatPalette) {
        self.palette = palette
    }

    func setPhase(_ newPhase: Phase) {
        guard newPhase != phase else { return }
        phase = newPhase
        phaseStart = Date()
    }
}

/// What the cat types and says.
enum KeyboardCatLines {
    /// Cat-typing, fed to the text field a few characters per key press.
    static let typing = [
        "mmmmrrrrrrrooooow",
        "ffffffffffffff",
        "jjjjjjjjjjjjjjòòòòò",
        "hhhhhhhhhhhhhhhhhh",
        "        ",
        "ggggggggggggggggggg",
        "bbbbbbnnnnnnnnnnnmmmmmmm",
        "kkkkkkkkkkkkkkkkkk",
        "prrrrrrrrrrrrrrrrrr",
        "yuuuuuuuuuuuuuuuuiiii",
        "zzzzzzzzzzzzzzz",
        "vvvvvvvvvvvvbbbbbbb",
        "miaooooooooooooo",
        "jhjhjhjhjhjhjhjhjh",
    ]

    /// What the cat mumbles every few key presses. The first one is always the first line.
    static let sleepy = [
        "Sto dormendo qui.",
        "Mrrr. Tastiera occupata.",
        "Shhh. Cinque minuti ancora.",
        "Questa tastiera è calda. È mia.",
        "Il lavoro può aspettare. Io no.",
        "Prrr… scrivo io per te.",
    ]

    static let escape = [
        "Esc? Non c'è via di fuga.",
        "Niente Esc. Solo pausa.",
    ]

    static let quit = "Il gatto non ti lascia uscire 😼"
}
