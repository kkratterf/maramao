import SwiftUI

/// One screen of the break. The main screen gets the text field, the keyboard with the cat and
/// the HUD; the others just a dim curtain and a note.
struct KeyboardCatScene: View {
    let model: KeyboardCatModel
    let context: BreakContext
    let isMain: Bool

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        // Increase Contrast: a nearly opaque curtain.
        let solid = contrast == .increased
        return ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.06, blue: 0.09).opacity(solid ? 0.98 : 0.9),
                    Color(red: 0.13, green: 0.1, blue: 0.12).opacity(solid ? 0.99 : 0.94),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            if isMain {
                KeyboardCatStage(model: model, context: context)
            } else {
                VStack(spacing: 10) {
                    Text("⌨️ 💤")
                        .font(.system(size: 44))
                    Text("Il gatto dorme sulla tastiera dell'altro schermo.")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.65))
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Main stage

struct KeyboardCatStage: View {
    @ObservedObject var model: KeyboardCatModel
    let context: BreakContext

    var body: some View {
        GeometryReader { geo in
            let ratio = KeyboardCatLayout.width / KeyboardCatLayout.height
            let keyboardWidth = min(geo.size.width * 0.74, 1180, geo.size.height * 0.52 * ratio)
            let unit = keyboardWidth / KeyboardCatLayout.width
            let keyboardHeight = unit * KeyboardCatLayout.height
            let origin = CGPoint(
                x: (geo.size.width - keyboardWidth) / 2,
                y: geo.size.height * 0.56 - keyboardHeight / 2
            )
            let catFrame = KeyboardCatLayout.catFrame
            let catCenter = CGPoint(
                x: origin.x + catFrame.midX * unit,
                y: origin.y + catFrame.midY * unit
            )
            let catSize = CGSize(width: catFrame.width * unit, height: catFrame.height * unit)

            ZStack {
                KeyboardCatTextField(typed: model.typed)
                    .frame(width: min(keyboardWidth, 900))
                    .position(x: geo.size.width / 2, y: max(70, origin.y - 64))

                KeyboardCatKeyboard(pressed: model.pressedKeys, catKeys: model.catKeys)
                    .frame(width: keyboardWidth, height: keyboardHeight)
                    .shadow(color: .black.opacity(0.45), radius: 24, y: 14)
                    .position(x: geo.size.width / 2, y: origin.y + keyboardHeight / 2)

                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
                    catLayer(date: timeline.date, size: catSize)
                }
                .frame(width: catSize.width * 1.4, height: catSize.height * 1.4)
                .position(catCenter)
                .allowsHitTesting(false)

                if let text = model.bubble {
                    KeyboardCatBubble(text: text)
                        .position(x: catCenter.x + catSize.width * 0.22, y: catCenter.y - catSize.height * 0.08)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                        .id(text)
                }

                VStack(spacing: 10) {
                    Text("Prova a scrivere qualcosa… il gatto non si sposta.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                    BreakHUD(context: context, message: model.hudMessage)
                }
                .position(x: geo.size.width / 2, y: min(geo.size.height - 70, origin.y + keyboardHeight + 80))
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: model.bubble)
        }
    }

    /// The cat with breathing, tail twitches and floating "z"s, in a box centred on its frame.
    private func catLayer(date: Date, size: CGSize) -> some View {
        let t = date.timeIntervalSinceReferenceDate
        let sinceTwitch = date.timeIntervalSince(model.twitchDate)
        let twitch = sinceTwitch >= 0 && sinceTwitch < 0.6 ? 1 - sinceTwitch / 0.6 : 0
        let asleep = model.phase == .asleep
        let inPhase = max(0, date.timeIntervalSince(model.phaseStart))

        let breathe = asleep ? CGFloat(1 + 0.015 * (1 - cos(2 * Double.pi * t / 3.6))) : CGFloat(1 + 0.02 * min(1, inPhase / 0.6))
        let wag = sin(t * 0.8) * 0.3 + sin(sinceTwitch * 28) * 0.9 * twitch
        // Reduce Motion: no shiver, the tail twitch is enough.
        let shiver = BreakAccessibility.reduceMotion ? 0 : CGFloat(sin(sinceTwitch * 70) * 2.5 * twitch)

        return ZStack {
            CatView(pose: asleep ? .sleeping : .stretching, palette: model.palette, tailWag: wag)
                .frame(width: size.width, height: size.height)
                .scaleEffect(x: 1, y: breathe, anchor: .bottom)
                .offset(x: shiver)
            if asleep {
                ForEach(0..<3, id: \.self) { index in
                    zLetter(index: index, t: t, size: size)
                }
            }
        }
    }

    /// One "Z" drifting up from the sleeping head (at about (150, 118) of the 200×160 design).
    private func zLetter(index: Int, t: Double, size: CGSize) -> some View {
        let period = 3.6
        let raw = (t / period + Double(index) / 3).truncatingRemainder(dividingBy: 1)
        // Reduce Motion: each Z stays in its place and only fades in and out.
        let calm = BreakAccessibility.reduceMotion
        let p = calm ? CGFloat(index + 1) / 4 : CGFloat(raw)
        let x = size.width * 0.25 + p * size.width * 0.2 + (calm ? 0 : CGFloat(sin(raw * 2 * Double.pi)) * 8)
        let y = size.height * 0.18 - p * size.height * 0.6
        return Text(index == 1 ? "z" : "Z")
            .font(.system(size: 20 + 18 * p, weight: .heavy, design: .rounded))
            .foregroundColor(Color(red: 0.88, green: 0.92, blue: 1.0))
            .opacity(Double(sin(raw * Double.pi)) * 0.9)
            .offset(x: x, y: y)
    }
}

// MARK: - Keyboard

/// The keyboard: an aluminium body with dark keys and Italian labels.
/// Keys the user presses light up white, the ones the cat "types" light up orange.
struct KeyboardCatKeyboard: View {
    let pressed: Set<Int>
    let catKeys: Set<Int>

    private static let userGlow = Color(red: 0.75, green: 0.9, blue: 1.0)
    private static let catGlow = Color(red: 1.0, green: 0.62, blue: 0.22)

    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        Canvas { ctx, size in
            let u = size.width / KeyboardCatLayout.width
            let plate = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: u * 0.45, style: .continuous)
            ctx.fill(plate, with: .linearGradient(
                Gradient(colors: [Color(white: 0.86), Color(white: 0.7)]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            ))
            ctx.stroke(plate, with: .color(Color.white.opacity(0.6)), lineWidth: 1)

            for key in KeyboardCatLayout.keys {
                let rect = CGRect(
                    x: key.rect.minX * u,
                    y: key.rect.minY * u,
                    width: key.rect.width * u,
                    height: key.rect.height * u
                ).insetBy(dx: u * 0.06, dy: u * 0.06)
                let radius = u * 0.14
                let isUser = pressed.contains(key.id)
                let isCat = catKeys.contains(key.id)
                let glow: Color? = isUser ? Self.userGlow : (isCat ? Self.catGlow : nil)

                if let glow {
                    let halo = Path(roundedRect: rect.insetBy(dx: -u * 0.1, dy: -u * 0.1), cornerRadius: radius * 1.6, style: .continuous)
                    ctx.fill(halo, with: .color(glow.opacity(0.45)))
                }
                let keyPath = Path(roundedRect: rect, cornerRadius: radius, style: .continuous)
                // A dark edge under each key gives it some depth.
                ctx.fill(Path(roundedRect: rect.offsetBy(dx: 0, dy: u * 0.03), cornerRadius: radius, style: .continuous),
                         with: .color(Color.black.opacity(0.35)))
                ctx.fill(keyPath, with: .color(glow ?? Color(white: 0.13)))
                if differentiateWithoutColor && glow != nil {
                    // Not only by color: keys you press get a solid outline, the cat's a dashed one.
                    let dash: [CGFloat] = isUser ? [] : [u * 0.12, u * 0.08]
                    ctx.stroke(keyPath, with: .color(.black), style: StrokeStyle(lineWidth: max(1.5, u * 0.05), dash: dash))
                }

                if !key.label.isEmpty {
                    let fontSize = key.isSmallLabel ? u * 0.24 : u * 0.34
                    let labelColor: Color = glow == nil ? Color.white.opacity(0.88) : Color(white: 0.12)
                    let text = Text(key.label)
                        .font(.system(size: fontSize, weight: .medium, design: .rounded))
                        .foregroundColor(labelColor)
                    let point: CGPoint
                    if key.isSmallLabel && key.rect.width > 1.2 {
                        point = CGPoint(x: rect.minX + u * 0.3, y: rect.maxY - u * 0.24)
                    } else {
                        point = CGPoint(x: rect.midX, y: rect.midY)
                    }
                    ctx.draw(text, at: point, anchor: key.isSmallLabel && key.rect.width > 1.2 ? .leading : .center)
                }
            }
        }
    }
}

// MARK: - Text field

/// The fake document the cat is typing into, with a blinking caret.
struct KeyboardCatTextField: View {
    let typed: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Documento senza titolo — modificato dal gatto")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.55))
            HStack(spacing: 1) {
                if typed.isEmpty {
                    caret
                    Text("Scrivi pure… se ci riesci.")
                        .foregroundColor(Color(white: 0.6))
                } else {
                    Text(String(typed.suffix(160)))
                        .foregroundColor(Color(white: 0.1))
                        .lineLimit(1)
                        .truncationMode(.head)
                    caret
                }
                Spacer(minLength: 0)
            }
            .font(.system(size: 22, weight: .regular, design: .monospaced))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(white: 0.97))
            )
            .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        }
    }

    private var caret: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { timeline in
            let on = Int(timeline.date.timeIntervalSinceReferenceDate * 2) % 2 == 0
            Rectangle()
                .fill(Color(red: 0.2, green: 0.45, blue: 0.95))
                .frame(width: 2, height: 26)
                .opacity(on ? 1 : 0)
        }
        .frame(width: 2, height: 26)
    }
}

// MARK: - Bubble

/// The cat's speech bubble, with the tail pointing down-left towards its head.
struct KeyboardCatBubble: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(text)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(Color(red: 0.12, green: 0.1, blue: 0.16))
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white)
                )
            KeyboardCatBubbleTail()
                .fill(Color.white)
                .frame(width: 22, height: 14)
                .padding(.leading, 26)
        }
        .fixedSize()
        .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
    }
}

struct KeyboardCatBubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.15, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
