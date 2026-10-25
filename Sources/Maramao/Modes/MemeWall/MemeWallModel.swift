import AppKit
import SwiftUI

/// The "GIF" a card plays: how the cat moves inside the meme.
enum MemeWallTemplate: CaseIterable {
    /// Gentle up and down bob.
    case bobbing
    /// Fast side to side wiggle.
    case wiggle
    /// Annoyed cat, staring, tail lashing.
    case tailLash
    /// Slow dramatic zoom on a cat that blinks at you.
    case stare
    /// Repeated zoom punch, like a reaction GIF.
    case zoomPunch
    /// Angry vibrating cat.
    case vibrate
    /// Cat spinning on itself.
    case spin
    /// Cat walking in from one side and out the other.
    case slide
    /// Squash and stretch dance.
    case dance
    /// Sleeping loaf with floating Z's.
    case sleepy
    /// Cat that keeps stretching and sitting up again.
    case stretch

    /// Whether the cat sits upright, so sunglasses can sit on its face.
    var isSitting: Bool {
        switch self {
        case .slide, .sleepy, .stretch: return false
        default: return true
        }
    }
}

/// How a card swaps to its next meme.
enum MemeWallTransition: CaseIterable {
    case pop
    case slide
    case drop
    case spin
    case flip

    var anyTransition: AnyTransition {
        switch self {
        case .pop:
            return AnyTransition.scale(scale: 0.1).combined(with: .opacity)
        case .slide:
            return AnyTransition.asymmetric(
                insertion: AnyTransition.move(edge: .trailing).combined(with: .opacity),
                removal: AnyTransition.move(edge: .leading).combined(with: .opacity)
            )
        case .drop:
            return AnyTransition.asymmetric(
                insertion: AnyTransition.move(edge: .top).combined(with: .opacity),
                removal: AnyTransition.move(edge: .bottom).combined(with: .opacity)
            )
        case .spin:
            return AnyTransition.modifier(
                active: MemeWallSpinModifier(amount: 1),
                identity: MemeWallSpinModifier(amount: 0)
            )
        case .flip:
            return AnyTransition.modifier(
                active: MemeWallFlipModifier(amount: 1),
                identity: MemeWallFlipModifier(amount: 0)
            )
        }
    }
}

struct MemeWallSpinModifier: ViewModifier {
    let amount: Double

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(amount * 300))
            .scaleEffect(1 - amount * 0.85)
            .opacity(1 - amount)
    }
}

struct MemeWallFlipModifier: ViewModifier {
    let amount: Double

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(amount * 90), axis: (x: 0, y: 1, z: 0))
            .opacity(1 - amount)
    }
}

/// One meme: caption, animated cat (or a picture from ~/Pictures/Maramao) and decorations.
struct MemeWallMeme: Identifiable {
    let id = UUID()
    let captionIndex: Int
    let template: MemeWallTemplate
    let palette: CatPalette
    let facingLeft: Bool
    let wearsGlasses: Bool
    let prop: String?
    let backdrop: [Color]
    let transition: MemeWallTransition
    /// Random phase so cards with the same template do not move in lockstep.
    let seed: Double
    let shownAt: Date
    /// A picture the user put in ~/Pictures/Maramao, shown instead of the cat.
    let image: NSImage?

    var caption: MemeWallCaption {
        let all = MemeWallCaption.all
        return all[min(max(0, captionIndex), all.count - 1)]
    }
}

/// A slot of the collage.
struct MemeWallCard {
    var meme: MemeWallMeme
    /// Small fixed tilt, for the "pinned on a wall" look.
    let tilt: Double
}

/// The collage on one display: which memes are where, when they swap, entrance and exit.
@MainActor
final class MemeWallModel: ObservableObject {
    @Published private(set) var cards: [MemeWallCard] = []
    /// How many slots have played their entrance.
    @Published private(set) var revealed = 0
    @Published private(set) var exiting = false

    let hudMessage: String

    private let deck: MemeWallDeck
    private let userImages: MemeWallUserImages
    private let entranceScale: Double
    private var nextSwap: [Date] = []
    private var entranceTask: Task<Void, Never>?

    private static let props = ["😎", "🍕", "💻", "☕️", "🍅", "🐟", "🧶", "📎", "🍩"]
    private static let backdrops: [[Color]] = [
        [Color(red: 0.99, green: 0.83, blue: 0.55), Color(red: 0.98, green: 0.6, blue: 0.45)],
        [Color(red: 0.62, green: 0.85, blue: 0.98), Color(red: 0.42, green: 0.6, blue: 0.95)],
        [Color(red: 0.75, green: 0.95, blue: 0.7), Color(red: 0.35, green: 0.75, blue: 0.55)],
        [Color(red: 0.98, green: 0.72, blue: 0.85), Color(red: 0.8, green: 0.45, blue: 0.8)],
        [Color(red: 0.95, green: 0.92, blue: 0.6), Color(red: 0.95, green: 0.7, blue: 0.25)],
        [Color(red: 0.7, green: 0.7, blue: 0.95), Color(red: 0.4, green: 0.35, blue: 0.75)],
        [Color(red: 0.55, green: 0.9, blue: 0.88), Color(red: 0.2, green: 0.6, blue: 0.7)],
    ]
    private static let messages = [
        String(localized: "Niente lavoro. Solo meme."),
        String(localized: "Il gatto ha preso il telecomando."),
        String(localized: "Stai guardando Maramao TV."),
        String(localized: "Torna quando il gatto lo dice."),
    ]

    init(cardCount: Int, deck: MemeWallDeck, userImages: MemeWallUserImages, entranceScale: Double) {
        self.deck = deck
        self.userImages = userImages
        self.entranceScale = entranceScale
        self.hudMessage = Self.messages.randomElement() ?? String(localized: "Niente lavoro. Solo meme.")
        var made: [MemeWallCard] = []
        for _ in 0..<max(1, cardCount) {
            let used = made.map { $0.meme.template }
            made.append(MemeWallCard(meme: makeMeme(avoiding: used), tilt: Double.random(in: -2.5...2.5)))
        }
        cards = made
        let now = Date()
        nextSwap = made.indices.map { i in
            now.addingTimeInterval(6 + Double(i) * 0.8 + Double.random(in: 0...1.5))
        }
    }

    /// Plays the staggered entrance.
    func start() {
        let count = cards.count
        let step = 0.12 * entranceScale
        entranceTask = Task { @MainActor [weak self] in
            for i in 0..<count {
                try? await Task.sleep(nanoseconds: UInt64((0.05 + step) * 1_000_000_000))
                guard let self = self, !self.exiting else { return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    self.revealed = i + 1
                }
            }
        }
    }

    /// Swaps every card whose time has come.
    func tick(now: Date) {
        guard !exiting else { return }
        for i in cards.indices where i < nextSwap.count && now >= nextSwap[i] {
            let old = cards[i].meme
            let others = cards.enumerated().filter { $0.offset != i }.map { $0.element.meme.template }
            let fresh = makeMeme(avoiding: others + [old.template])
            deck.release(old.captionIndex)
            withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                cards[i].meme = fresh
            }
            nextSwap[i] = now.addingTimeInterval(Double.random(in: 6...9))
        }
    }

    /// Starts the exit animation: the views fly the cards away.
    func exit() {
        entranceTask?.cancel()
        entranceTask = nil
        exiting = true
    }

    private func makeMeme(avoiding used: [MemeWallTemplate]) -> MemeWallMeme {
        let candidates = MemeWallTemplate.allCases.filter { !used.contains($0) }
        let template = candidates.randomElement() ?? MemeWallTemplate.allCases.randomElement() ?? .bobbing
        let wearsGlasses = template.isSitting && Double.random(in: 0...1) < 0.3
        var prop: String? = Double.random(in: 0...1) < 0.55 ? Self.props.randomElement() : nil
        if template == .vibrate { prop = "💢" }
        if wearsGlasses && prop == "😎" { prop = nil }
        return MemeWallMeme(
            captionIndex: deck.draw(),
            template: template,
            palette: CatPalette.random(),
            facingLeft: Bool.random(),
            wearsGlasses: wearsGlasses,
            prop: prop,
            backdrop: Self.backdrops.randomElement() ?? [.white, .gray],
            transition: MemeWallTransition.allCases.randomElement() ?? .pop,
            seed: Double.random(in: 0...6),
            shownAt: Date(),
            image: userImages.maybeNext()
        )
    }
}

/// Optional extra: pictures (GIF/PNG/JPG) the user put in ~/Pictures/Maramao are mixed into the
/// cards. If the folder does not exist, nothing happens.
@MainActor
final class MemeWallUserImages {
    private var urls: [URL]
    private var cursor = 0

    init(urls: [URL]) {
        self.urls = urls
    }

    static func load() -> MemeWallUserImages {
        let fm = FileManager.default
        // Images from enabled cat packs (already validated: inside the pack, size-capped).
        let packImages = CatPackRuntime.shared.content.imageURLs
        guard let pictures = fm.urls(for: .picturesDirectory, in: .userDomainMask).first else {
            return MemeWallUserImages(urls: Array(packImages.shuffled().prefix(60)))
        }
        let folder = pictures.appendingPathComponent("Maramao", isDirectory: true)
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: folder.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return MemeWallUserImages(urls: Array(packImages.shuffled().prefix(60)))
        }
        guard let items = try? fm.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return MemeWallUserImages(urls: Array(packImages.shuffled().prefix(60)))
        }
        let allowed: Set<String> = ["gif", "png", "jpg", "jpeg"]
        let usable = items.filter { url in
            guard allowed.contains(url.pathExtension.lowercased()) else { return false }
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return size > 0 && size < 20_000_000
        }
        return MemeWallUserImages(urls: Array((usable + packImages).shuffled().prefix(60)))
    }

    /// About one card in four shows a user picture, when there are any.
    func maybeNext() -> NSImage? {
        guard !urls.isEmpty, Double.random(in: 0...1) < 0.25 else { return nil }
        for _ in 0..<urls.count {
            let url = urls[cursor % urls.count]
            cursor += 1
            if let image = NSImage(contentsOf: url), image.isValid {
                return image
            }
        }
        // Nothing loads: stop trying.
        urls = []
        return nil
    }
}
