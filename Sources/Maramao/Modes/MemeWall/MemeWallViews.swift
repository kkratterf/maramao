import AppKit
import SwiftUI

// MARK: - Whole screen

/// One display: animated background, collage of meme cards, title and the countdown.
struct MemeWallView: View {
    let context: BreakContext
    @ObservedObject var wall: MemeWallModel

    var body: some View {
        GeometryReader { geo in
            let layout = MemeWallLayout(size: geo.size, count: wall.cards.count, isLongBreak: context.isLongBreak)
            ZStack {
                MemeWallBackground()
                VStack(spacing: 0) {
                    header
                        .frame(height: layout.headerHeight)
                        .opacity(wall.exiting ? 0 : 1)
                        .animation(.easeIn(duration: 0.3), value: wall.exiting)
                    grid(layout)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Color.clear.frame(height: layout.footerHeight)
                }
                VStack {
                    Spacer()
                    BreakHUD(context: context, message: wall.hudMessage)
                        .scaleEffect(1.35)
                        .padding(.bottom, layout.footerHeight * 0.32)
                        .opacity(wall.exiting ? 0 : 1)
                        .animation(.easeIn(duration: 0.3), value: wall.exiting)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var header: some View {
        if context.isLongBreak {
            VStack(spacing: 4) {
                MemeWallOutlinedText(text: String(localized: "📺 MARAMAO TV · PAUSA LUNGA"), size: 40, outline: 2.5)
                Text("La compilation dei gatti che ti vogliono lontano dalla tastiera")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(.top, 18)
        } else {
            HStack {
                HStack(spacing: 8) {
                    Circle().fill(Color.red).frame(width: 10, height: 10)
                    Text("IN ONDA · MARAMAO TV")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.black.opacity(0.35)))
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.top, 18)
        }
    }

    private func grid(_ layout: MemeWallLayout) -> some View {
        VStack(spacing: layout.gap) {
            ForEach(0..<layout.rows, id: \.self) { row in
                HStack(spacing: layout.gap) {
                    ForEach(0..<layout.columns, id: \.self) { column in
                        let index = row * layout.columns + column
                        if index < wall.cards.count {
                            MemeWallSlotView(
                                card: wall.cards[index],
                                index: index,
                                side: layout.side,
                                revealed: index < wall.revealed,
                                exiting: wall.exiting
                            )
                        }
                    }
                }
            }
        }
    }
}

/// Grid geometry for a screen: 3 cards in a row, 2×2, or 3×2.
struct MemeWallLayout {
    let columns: Int
    let rows: Int
    let side: CGFloat
    let gap: CGFloat
    let headerHeight: CGFloat
    let footerHeight: CGFloat

    init(size: CGSize, count: Int, isLongBreak: Bool) {
        switch count {
        case 0...3:
            columns = max(1, count)
            rows = 1
        case 4:
            columns = 2
            rows = 2
        default:
            columns = 3
            rows = (count + 2) / 3
        }
        headerHeight = isLongBreak ? 96 : 64
        footerHeight = 150
        let availableWidth = max(200, size.width - 80)
        let availableHeight = max(200, size.height - headerHeight - footerHeight - 20)
        gap = max(16, min(availableWidth, availableHeight) * 0.04)
        let cellWidth = (availableWidth - gap * CGFloat(columns - 1)) / CGFloat(columns)
        let cellHeight = (availableHeight - gap * CGFloat(rows - 1)) / CGFloat(rows)
        side = max(120, min(cellWidth, cellHeight, 520))
    }
}

// MARK: - Card

/// A slot of the collage: hosts the current meme, swaps it with a transition, plays entrance and exit.
struct MemeWallSlotView: View {
    let card: MemeWallCard
    let index: Int
    let side: CGFloat
    let revealed: Bool
    let exiting: Bool

    var body: some View {
        let visible = revealed && !exiting
        let direction: CGFloat = index % 2 == 0 ? -1 : 1
        ZStack {
            MemeWallCardView(meme: card.meme, side: side)
                .id(card.meme.id)
                .transition(card.meme.transition.anyTransition)
        }
        .frame(width: side, height: side)
        .rotationEffect(.degrees(card.tilt))
        .scaleEffect(visible ? 1 : (exiting ? 0.5 : 0.15))
        .opacity(visible ? 1 : 0)
        .rotationEffect(.degrees(exiting ? Double(direction) * 25 : 0))
        .offset(x: exiting ? direction * side * 0.5 : 0, y: exiting ? side * 1.3 : 0)
        .animation(.easeIn(duration: 0.4).delay(Double(index) * 0.04), value: exiting)
    }
}

/// A classic meme: picture with a bold white caption on top and bottom.
struct MemeWallCardView: View {
    let meme: MemeWallMeme
    let side: CGFloat

    var body: some View {
        let border = side * 0.035
        let inner = side - border * 2
        let fontSize = inner * 0.085
        ZStack {
            RoundedRectangle(cornerRadius: side * 0.04, style: .continuous)
                .fill(Color.white)
            ZStack {
                LinearGradient(colors: meme.backdrop, startPoint: .topLeading, endPoint: .bottomTrailing)
                if let image = meme.image {
                    MemeWallAnimatedImage(image: image)
                        .frame(width: inner, height: inner)
                } else {
                    MemeWallCatStage(meme: meme, side: inner)
                }
                VStack(spacing: 0) {
                    MemeWallOutlinedText(text: meme.caption.top, size: fontSize, outline: max(1.5, fontSize * 0.08))
                    Spacer(minLength: 0)
                    MemeWallOutlinedText(text: meme.caption.bottom, size: fontSize, outline: max(1.5, fontSize * 0.08))
                }
                .padding(.horizontal, inner * 0.04)
                .padding(.vertical, inner * 0.03)
            }
            .frame(width: inner, height: inner)
            .clipShape(RoundedRectangle(cornerRadius: side * 0.025, style: .continuous))
        }
        .frame(width: side, height: side)
        .overlay(alignment: .topTrailing) {
            if meme.caption.kind == .tip {
                Text("💡 CONSIGLIO DEL GATTO")
                    .font(.system(size: max(10, side * 0.035), weight: .heavy, design: .rounded))
                    .foregroundColor(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color(red: 1, green: 0.88, blue: 0.3)))
                    .rotationEffect(.degrees(8))
                    .offset(x: side * 0.05, y: -side * 0.04)
            }
        }
        .shadow(color: .black.opacity(0.35), radius: 14, x: 0, y: 8)
    }
}

/// Meme caption: white Impact (or heavy system font) with a black outline.
/// SwiftUI on macOS 13 has no text stroke, so the outline is the same text drawn eight times, offset.
struct MemeWallOutlinedText: View {
    let text: String
    let size: CGFloat
    var outline: CGFloat = 2

    var body: some View {
        let font = MemeWallFont.caption(size: size)
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                let angle = Double(i) * Double.pi / 4
                Text(text)
                    .font(font)
                    .foregroundColor(.black)
                    .offset(x: CGFloat(cos(angle)) * outline, y: CGFloat(sin(angle)) * outline)
            }
            Text(text)
                .font(font)
                .foregroundColor(.white)
        }
        .multilineTextAlignment(.center)
        .lineLimit(3)
        .minimumScaleFactor(0.5)
        .frame(maxWidth: .infinity)
    }
}

enum MemeWallFont {
    static let hasImpact: Bool = NSFont(name: "Impact", size: 12) != nil

    static func caption(size: CGFloat) -> Font {
        if hasImpact {
            return Font.custom("Impact", size: size)
        }
        return Font.system(size: size, weight: .black)
    }
}

// MARK: - Animated cat

/// Plays the meme's template like a looping GIF.
struct MemeWallCatStage: View {
    let meme: MemeWallMeme
    let side: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            MemeWallAnimatedCat(
                meme: meme,
                side: side,
                t: max(0, timeline.date.timeIntervalSince(meme.shownAt))
            )
        }
        .frame(width: side, height: side)
    }
}

/// Where the cat is at time `t` for a given template.
struct MemeWallMotion {
    var pose: CatPose = .sitting
    var eyesClosed = false
    var tailWag: Double = 0
    var rotation: Double = 0
    var scaleX: Double = 1
    var scaleY: Double = 1
    /// Offsets as a fraction of the card side.
    var offsetX: Double = 0
    var offsetY: Double = 0

    init(template: MemeWallTemplate, t: Double, seed: Double) {
        let blink = (t + seed).truncatingRemainder(dividingBy: 3.4)
        eyesClosed = blink > 3.22
        tailWag = sin(t * 2 + seed) * 0.35

        switch template {
        case .bobbing:
            offsetY = sin(t * 4) * 0.03
            rotation = sin(t * 2) * 3
        case .wiggle:
            rotation = sin(t * 11) * 9
            tailWag = sin(t * 11) * 0.8
        case .tailLash:
            tailWag = sin(t * 7) * 1.1
            rotation = sin(t * 0.8) * 2
            eyesClosed = false
        case .stare:
            let zoom = min(t, 5) / 5
            scaleX = 1 + zoom * 0.35
            scaleY = scaleX
            eyesClosed = (t + seed).truncatingRemainder(dividingBy: 2.2) > 1.95
        case .zoomPunch:
            let p = t.truncatingRemainder(dividingBy: 1.6)
            let punch = p < 0.12 ? p / 0.12 : exp(-(p - 0.12) * 6)
            scaleX = 1 + punch * 0.4
            scaleY = scaleX
            rotation = punch * 6
        case .vibrate:
            offsetX = sin(t * 71) * 0.014
            offsetY = cos(t * 53) * 0.01
            rotation = sin(t * 43) * 2.5
            tailWag = sin(t * 23) * 1.2
            eyesClosed = false
        case .spin:
            rotation = (t * 240).truncatingRemainder(dividingBy: 360)
            scaleX = 0.9
            scaleY = 0.9
        case .slide:
            let p = t.truncatingRemainder(dividingBy: 4.5) / 4.5
            offsetX = p * 1.5 - 0.75
            offsetY = 0.04
            pose = .walking(step: t * 9)
        case .dance:
            let beat = sin(t * 8)
            scaleX = 1 - beat * 0.07
            scaleY = 1 + beat * 0.1
            rotation = sin(t * 4) * 7
            offsetY = -abs(sin(t * 4)) * 0.03
        case .sleepy:
            pose = .sleeping
            scaleX = 1 + sin(t * 1.8) * 0.02
            scaleY = 1 + sin(t * 1.8) * 0.035
            tailWag = sin(t * 1.2) * 0.3
        case .stretch:
            let p = t.truncatingRemainder(dividingBy: 3.0)
            pose = p < 1.5 ? .stretching : .sitting
            tailWag = sin(t * 3) * 0.4
        }
    }
}

struct MemeWallAnimatedCat: View {
    let meme: MemeWallMeme
    let side: CGFloat
    let t: Double

    var body: some View {
        let motion = MemeWallMotion(template: meme.template, t: t, seed: meme.seed)
        // The slide template always walks across in the direction the cat faces (left to right).
        let facingLeft = meme.template == .slide ? false : meme.facingLeft
        let catWidth = side * 0.64
        let catHeight = catWidth * 0.8
        let flip: CGFloat = facingLeft ? -1 : 1
        let showGlasses = meme.wearsGlasses && motion.pose == .sitting
        ZStack {
            ZStack {
                CatView(
                    pose: motion.pose,
                    palette: meme.palette,
                    eyesClosed: motion.eyesClosed,
                    facingLeft: facingLeft,
                    tailWag: motion.tailWag
                )
                .frame(width: catWidth, height: catHeight)
                if showGlasses {
                    // The sitting cat's eyes are at about (124, 53) in CatView's 200×160 design space.
                    Text("🕶️")
                        .font(.system(size: catWidth * 0.2))
                        .offset(x: flip * catWidth * 0.12, y: -catHeight * 0.165)
                }
            }
            .frame(width: catWidth, height: catHeight)
            .scaleEffect(x: motion.scaleX, y: motion.scaleY, anchor: .bottom)
            .rotationEffect(.degrees(motion.rotation))
            .offset(x: CGFloat(motion.offsetX) * side, y: CGFloat(motion.offsetY) * side + side * 0.03)

            if let prop = meme.prop {
                Text(prop)
                    .font(.system(size: side * 0.13))
                    .rotationEffect(.degrees(sin(t * 3 + meme.seed) * 12))
                    .offset(
                        x: -flip * side * 0.3,
                        y: side * 0.16 + CGFloat(sin(t * 2.5 + meme.seed)) * side * 0.02
                    )
            }

            if meme.template == .sleepy {
                ForEach(0..<3, id: \.self) { i in
                    let p = (t * 0.5 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                    Text("z")
                        .font(.system(size: side * (0.05 + CGFloat(p) * 0.05), weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2)
                        .opacity(sin(p * Double.pi))
                        .offset(
                            x: flip * side * (0.17 + CGFloat(p) * 0.1),
                            y: -side * (0.02 + CGFloat(p) * 0.2)
                        )
                }
            }
        }
        .frame(width: side, height: side)
    }
}

// MARK: - User pictures

/// Shows a user picture; GIFs keep animating.
struct MemeWallAnimatedImage: NSViewRepresentable {
    let image: NSImage

    func makeNSView(context: Context) -> NSImageView {
        let view = NSImageView()
        view.imageScaling = .scaleProportionallyUpOrDown
        view.animates = true
        view.image = image
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        return view
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {
        if nsView.image !== image {
            nsView.image = image
        }
    }
}

// MARK: - Background

/// Slowly shifting gradient with a tiled paw pattern drifting diagonally.
struct MemeWallBackground: View {
    var body: some View {
        // The paws drift ~14 pt/s and the hue shifts over minutes: 15 fps is plenty for a
        // full-screen canvas redrawn on every display.
        TimelineView(.animation(minimumInterval: 1.0 / 15.0, paused: false)) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let hue = (t * 0.015).truncatingRemainder(dividingBy: 1)
                let first = Color(hue: hue, saturation: 0.55, brightness: 0.42)
                let second = Color(hue: (hue + 0.17).truncatingRemainder(dividingBy: 1), saturation: 0.65, brightness: 0.3)
                ctx.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .linearGradient(
                        Gradient(colors: [first, second]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: size.width, y: size.height)
                    )
                )

                let spacing: CGFloat = 130
                // Drift over two rows so the alternating row offset never jumps.
                let drift = CGFloat((t * 14).truncatingRemainder(dividingBy: Double(spacing * 2)))
                var row = 0
                var y = -spacing * 2 + drift
                while y < size.height + spacing {
                    var x = -spacing + drift.truncatingRemainder(dividingBy: spacing) + (row % 2 == 0 ? 0 : spacing / 2)
                    while x < size.width + spacing {
                        Self.drawPaw(&ctx, at: CGPoint(x: x, y: y), size: 26, angle: row % 2 == 0 ? -0.35 : 0.35)
                        x += spacing
                    }
                    y += spacing
                    row += 1
                }
            }
        }
        .opacity(0.97)
        .background(Color.black)
    }

    private static func drawPaw(_ ctx: inout GraphicsContext, at point: CGPoint, size s: CGFloat, angle: Double) {
        var c = ctx
        c.translateBy(x: point.x, y: point.y)
        c.rotate(by: .radians(angle))
        let color = GraphicsContext.Shading.color(.white.opacity(0.09))
        c.fill(Path(ellipseIn: CGRect(x: -s * 0.5, y: -s * 0.1, width: s, height: s * 0.8)), with: color)
        let toes: [(CGFloat, CGFloat)] = [(-0.55, -0.35), (-0.2, -0.6), (0.2, -0.6), (0.55, -0.35)]
        for toe in toes {
            let r = s * 0.19
            c.fill(Path(ellipseIn: CGRect(x: toe.0 * s - r, y: toe.1 * s - r, width: r * 2, height: r * 2.2)), with: color)
        }
    }
}
