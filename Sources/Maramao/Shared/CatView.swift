import AppKit
import SwiftUI

/// Fur colours for the procedural cat.
struct CatPalette: Equatable {
    var fur: Color
    var stripes: Color?
    var belly: Color
    var eyes: Color
    var nose: Color = Color(red: 0.95, green: 0.55, blue: 0.6)

    static let orange = CatPalette(
        fur: Color(red: 0.96, green: 0.6, blue: 0.25),
        stripes: Color(red: 0.82, green: 0.42, blue: 0.12),
        belly: Color(red: 1.0, green: 0.88, blue: 0.72),
        eyes: Color(red: 0.35, green: 0.7, blue: 0.3)
    )
    static let black = CatPalette(
        fur: Color(white: 0.17),
        stripes: nil,
        belly: Color(white: 0.29),
        eyes: Color(red: 0.95, green: 0.8, blue: 0.2)
    )
    static let gray = CatPalette(
        fur: Color(white: 0.55),
        stripes: Color(white: 0.4),
        belly: Color(white: 0.85),
        eyes: Color(red: 0.3, green: 0.6, blue: 0.85)
    )
    static let cream = CatPalette(
        fur: Color(red: 0.98, green: 0.94, blue: 0.86),
        stripes: Color(red: 0.85, green: 0.72, blue: 0.55),
        belly: .white,
        eyes: Color(red: 0.4, green: 0.65, blue: 0.95)
    )

    static let all: [CatPalette] = [.orange, .black, .gray, .cream]
    /// A random built-in palette, or one from an enabled cat pack.
    static func random() -> CatPalette {
        (all + CatPackRuntime.shared.content.palettes).randomElement() ?? .orange
    }
}

/// What the cat is doing.
enum CatPose: Equatable {
    /// Walking; `step` is a phase in radians that animates the legs and tail.
    case walking(step: Double)
    case sitting
    /// Curled up asleep.
    case sleeping
    /// Front low, back high: right after waking up or before leaving.
    case stretching
}

/// The look on the cat's face.
enum CatExpression: Equatable {
    case neutral
    /// Eyes squeezed shut in two arches and a wide smile: caught the dot, got petted.
    case happy
    /// Heavy eyelids and a frown: missed the dot, woken up, shaken.
    case grumpy
}

/// A cat drawn with vector shapes, facing right, in a 200×160 design space scaled to the frame.
/// Use `.scaleEffect(x: -1)` (or `facingLeft: true`) to make it face left.
/// Shared by every break mode so the cats look like one family.
struct CatView: View {
    var pose: CatPose = .sitting
    var palette: CatPalette = .orange
    var eyesClosed = false
    var expression: CatExpression = .neutral
    /// Where the open eyes look, as seen on screen: x to the right, y down, up to a length of 1.
    var gaze: CGVector = .zero
    var facingLeft = false
    /// Extra tail swing in radians, e.g. driven by a timer for an annoyed tail.
    var tailWag: Double = 0

    var body: some View {
        Canvas { ctx, size in
            let scale = min(size.width / 200, size.height / 160)
            ctx.translateBy(x: (size.width - 200 * scale) / 2, y: (size.height - 160 * scale) / 2)
            ctx.scaleBy(x: scale, y: scale)
            if facingLeft {
                ctx.translateBy(x: 200, y: 0)
                ctx.scaleBy(x: -1, y: 1)
            }
            switch pose {
            case .walking(let step): drawWalking(&ctx, step: step)
            case .sitting: drawSitting(&ctx)
            case .sleeping: drawSleeping(&ctx)
            case .stretching: drawStretching(&ctx)
            }
        }
        .aspectRatio(200 / 160, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(accessibilityDescription)
        .accessibilityAddTraits(.isImage)
    }

    /// What VoiceOver says about the drawing.
    private var accessibilityDescription: String {
        switch pose {
        case .walking: return String(localized: "Un gatto che cammina")
        case .sitting: return String(localized: "Un gatto seduto")
        case .sleeping: return String(localized: "Un gatto che dorme")
        case .stretching: return String(localized: "Un gatto che si stiracchia")
        }
    }

    // MARK: - Poses

    private func drawWalking(_ ctx: inout GraphicsContext, step: Double) {
        let swing = sin(step) * 12
        // Far legs first, slightly darker.
        leg(&ctx, x: 68, top: 116, swing: -swing, dark: true)
        leg(&ctx, x: 124, top: 116, swing: swing, dark: true)
        tailUp(&ctx, from: CGPoint(x: 48, y: 100), wave: sin(step * 0.5) * 0.3 + tailWag)
        // Body.
        ctx.fill(Path(ellipseIn: CGRect(x: 42, y: 77, width: 100, height: 54)), with: .color(palette.fur))
        ctx.fill(Path(ellipseIn: CGRect(x: 62, y: 111, width: 64, height: 17)), with: .color(palette.belly))
        stripes(&ctx, in: CGRect(x: 62, y: 78, width: 60, height: 20))
        leg(&ctx, x: 58, top: 116, swing: swing, dark: false)
        leg(&ctx, x: 134, top: 116, swing: -swing, dark: false)
        chinShadow(&ctx, in: CGRect(x: 118, y: 93, width: 44, height: 14))
        head(&ctx, center: CGPoint(x: 146, y: 72 + sin(step * 2) * 1.5), scale: 0.8)
    }

    private func drawSitting(_ ctx: inout GraphicsContext) {
        var tail = Path()
        tail.move(to: CGPoint(x: 76, y: 139))
        tail.addCurve(
            to: CGPoint(x: 46 + tailWag * 18, y: 101),
            control1: CGPoint(x: 48, y: 145),
            control2: CGPoint(x: 32, y: 123)
        )
        strokeTail(&ctx, tail, width: 14)
        // A small round body under a big head.
        var body = Path()
        body.move(to: CGPoint(x: 68, y: 145))
        body.addCurve(to: CGPoint(x: 104, y: 89), control1: CGPoint(x: 62, y: 113), control2: CGPoint(x: 80, y: 89))
        body.addCurve(to: CGPoint(x: 140, y: 145), control1: CGPoint(x: 128, y: 89), control2: CGPoint(x: 146, y: 113))
        body.addCurve(to: CGPoint(x: 68, y: 145), control1: CGPoint(x: 138, y: 152), control2: CGPoint(x: 70, y: 152))
        body.closeSubpath()
        ctx.fill(body, with: .color(palette.fur))
        ctx.fill(Path(ellipseIn: CGRect(x: 85, y: 106, width: 38, height: 42)), with: .color(palette.belly))
        // Front paws.
        for x in [89.0, 119.0] {
            ctx.fill(Path(ellipseIn: CGRect(x: x - 11.5, y: 139.5, width: 23, height: 13)), with: .color(palette.fur))
        }
        chinShadow(&ctx, in: CGRect(x: 74, y: 87, width: 60, height: 14))
        head(&ctx, center: CGPoint(x: 104, y: 58))
    }

    private func drawSleeping(_ ctx: inout GraphicsContext) {
        // A loaf: one big round body, head tucked on the right, tail wrapped in front.
        ctx.fill(Path(ellipseIn: CGRect(x: 32, y: 90, width: 136, height: 64)), with: .color(palette.fur))
        stripes(&ctx, in: CGRect(x: 54, y: 93, width: 64, height: 20))
        head(&ctx, center: CGPoint(x: 134, y: 118), scale: 0.72, forceClosed: true, tilt: 0.12)
        var tail = Path()
        tail.move(to: CGPoint(x: 38, y: 138))
        tail.addQuadCurve(to: CGPoint(x: 122, y: 149), control: CGPoint(x: 66, y: 158 + tailWag * 8))
        strokeTail(&ctx, tail, width: 13)
    }

    private func drawStretching(_ ctx: inout GraphicsContext) {
        tailUp(&ctx, from: CGPoint(x: 50, y: 84), wave: 0.5 + tailWag)
        // Back legs straight, rear end high.
        leg(&ctx, x: 56, top: 98, swing: 0, dark: true, length: 50)
        leg(&ctx, x: 70, top: 98, swing: 0, dark: false, length: 50)
        var body = Path()
        body.addEllipse(in: CGRect(x: 44, y: 70, width: 62, height: 48))
        body.addEllipse(in: CGRect(x: 82, y: 96, width: 76, height: 40))
        ctx.fill(body, with: .color(palette.fur))
        stripes(&ctx, in: CGRect(x: 56, y: 74, width: 46, height: 18))
        // Front paws stretched forward on the ground.
        let paw = Path(roundedRect: CGRect(x: 118, y: 138, width: 58, height: 13), cornerRadius: 6.5)
        ctx.fill(paw, with: .color(palette.fur))
        ctx.fill(Path(ellipseIn: CGRect(x: 163, y: 138, width: 18, height: 13)), with: .color(palette.belly))
        head(&ctx, center: CGPoint(x: 150, y: 114), scale: 0.72, forceClosed: true)
    }

    // MARK: - Parts

    /// The dark of pupils, closed eyes and mouths.
    private static let ink = Color(red: 0.11, green: 0.08, blue: 0.07)

    /// A coat too dark for dark lines to show: its closed eyes and whiskers are drawn light.
    private var hasDarkCoat: Bool {
        guard let fur = NSColor(palette.fur).usingColorSpace(.sRGB) else { return false }
        return 0.2126 * fur.redComponent + 0.7152 * fur.greenComponent + 0.0722 * fur.blueComponent < 0.2
    }

    /// A short, stubby leg ending in a light paw.
    private func leg(_ ctx: inout GraphicsContext, x: Double, top: Double, swing: Double, dark: Bool, length: Double = 30) {
        var c = ctx
        c.translateBy(x: x, y: top)
        c.rotate(by: .degrees(swing))
        let shape = Path(roundedRect: CGRect(x: -7.5, y: 0, width: 15, height: length), cornerRadius: 7.5)
        c.fill(shape, with: .color(palette.fur))
        if dark {
            c.fill(shape, with: .color(.black.opacity(0.14)))
        }
        let paw = Path(ellipseIn: CGRect(x: -8.5, y: length - 8.5, width: 19, height: 11))
        c.fill(paw, with: .color(palette.belly.opacity(dark ? 0.8 : 1)))
    }

    /// A tail held up behind the cat, swinging with `wave`.
    private func tailUp(_ ctx: inout GraphicsContext, from start: CGPoint, wave: Double) {
        var path = Path()
        path.move(to: start)
        let tip = CGPoint(x: start.x - 22 + wave * 25, y: start.y - 52)
        path.addQuadCurve(to: tip, control: CGPoint(x: start.x - 38, y: start.y - 6))
        strokeTail(&ctx, path, width: 13)
    }

    /// A round tail with its tip in the colour of the stripes, or of the belly on a plain coat.
    private func strokeTail(_ ctx: inout GraphicsContext, _ path: Path, width: Double) {
        let style = StrokeStyle(lineWidth: width, lineCap: .round)
        ctx.stroke(path, with: .color(palette.fur), style: style)
        ctx.stroke(path.trimmedPath(from: 0.82, to: 1), with: .color(palette.stripes ?? palette.belly), style: style)
    }

    private func stripes(_ ctx: inout GraphicsContext, in rect: CGRect) {
        guard let stripes = palette.stripes else { return }
        for i in 0..<3 {
            let x = rect.minX + rect.width * (0.2 + Double(i) * 0.3)
            var p = Path()
            p.move(to: CGPoint(x: x - 3, y: rect.minY + 2))
            p.addQuadCurve(to: CGPoint(x: x + 1, y: rect.maxY), control: CGPoint(x: x + 5, y: rect.midY))
            ctx.stroke(p, with: .color(stripes), style: StrokeStyle(lineWidth: 5, lineCap: .round))
        }
    }

    /// The soft shadow the head casts on the body.
    private func chinShadow(_ ctx: inout GraphicsContext, in rect: CGRect) {
        ctx.fill(Path(ellipseIn: rect), with: .color(.black.opacity(0.07)))
    }

    /// The head, seen from the front: wide and round, 96×72 at `scale` 1, with big eyes,
    /// pink cheeks and rounded ears.
    private func head(_ ctx: inout GraphicsContext, center: CGPoint, scale: Double = 1, forceClosed: Bool = false, tilt: Double = 0) {
        var c = ctx
        c.translateBy(x: center.x, y: center.y)
        c.rotate(by: .radians(tilt))
        c.scaleBy(x: scale, y: scale)
        let dark = hasDarkCoat
        let lines: Color = dark ? Color(white: 0.62) : Self.ink

        // Ears.
        for side in [-1.0, 1.0] {
            var ear = Path()
            ear.move(to: CGPoint(x: side * 40, y: -9))
            ear.addQuadCurve(to: CGPoint(x: side * 35, y: -50), control: CGPoint(x: side * 45, y: -43))
            ear.addQuadCurve(to: CGPoint(x: side * 7, y: -27), control: CGPoint(x: side * 20, y: -46))
            ear.closeSubpath()
            c.fill(ear, with: .color(palette.fur))
            var inner = Path()
            inner.move(to: CGPoint(x: side * 34, y: -17))
            inner.addQuadCurve(to: CGPoint(x: side * 32, y: -41), control: CGPoint(x: side * 37, y: -36))
            inner.addQuadCurve(to: CGPoint(x: side * 16, y: -26), control: CGPoint(x: side * 23, y: -38))
            inner.closeSubpath()
            c.fill(inner, with: .color(palette.nose.opacity(0.75)))
        }

        var face = Path()
        face.move(to: CGPoint(x: 0, y: -36))
        face.addCurve(to: CGPoint(x: 48, y: 1), control1: CGPoint(x: 33, y: -36), control2: CGPoint(x: 48, y: -19))
        face.addCurve(to: CGPoint(x: 0, y: 36), control1: CGPoint(x: 48, y: 24), control2: CGPoint(x: 29, y: 36))
        face.addCurve(to: CGPoint(x: -48, y: 1), control1: CGPoint(x: -29, y: 36), control2: CGPoint(x: -48, y: 24))
        face.addCurve(to: CGPoint(x: 0, y: -36), control1: CGPoint(x: -48, y: -19), control2: CGPoint(x: -33, y: -36))
        face.closeSubpath()
        c.fill(face, with: .color(palette.fur))
        // Muzzle.
        c.fill(Path(ellipseIn: CGRect(x: -17, y: 7, width: 34, height: 22)), with: .color(palette.belly))

        if let stripes = palette.stripes {
            // Three on the forehead, two on each cheek.
            for dx in [-11.0, 0.0, 11.0] {
                var p = Path()
                p.move(to: CGPoint(x: dx, y: dx == 0 ? -32 : -30))
                p.addLine(to: CGPoint(x: dx * 0.82, y: dx == 0 ? -22 : -21))
                c.stroke(p, with: .color(stripes), style: StrokeStyle(lineWidth: 4.2, lineCap: .round))
            }
            for side in [-1.0, 1.0] {
                for (x, y, length) in [(46.0, -3.0, 8.0), (47.0, 5.0, 9.0)] {
                    var p = Path()
                    p.move(to: CGPoint(x: side * x, y: y))
                    p.addLine(to: CGPoint(x: side * (x - length), y: y))
                    c.stroke(p, with: .color(stripes), style: StrokeStyle(lineWidth: 3.6, lineCap: .round))
                }
            }
        }

        // Cheeks.
        for side in [-1.0, 1.0] {
            let cheek = Path(ellipseIn: CGRect(x: side * 32 - 7.5, y: 12.8, width: 15, height: 8.4))
            c.fill(cheek, with: .color(palette.nose.opacity(0.55)))
        }

        // Eyes.
        let closed = eyesClosed || forceClosed
        let lidColor: Color = dark ? palette.eyes : Self.ink
        // The pupils slide inside the iris towards what the cat looks at.
        let gazeLength = max(1, hypot(gaze.dx, gaze.dy))
        let lookX = (facingLeft ? -gaze.dx : gaze.dx) / gazeLength * 2.2
        let lookY = gaze.dy / gazeLength * 2.2
        for side in [-1.0, 1.0] {
            let ex = side * 19
            if expression == .happy {
                var arch = Path()
                arch.move(to: CGPoint(x: ex - 8, y: 6))
                arch.addQuadCurve(to: CGPoint(x: ex + 8, y: 6), control: CGPoint(x: ex, y: -5))
                c.stroke(arch, with: .color(lidColor), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
            } else if closed {
                var lid = Path()
                lid.move(to: CGPoint(x: ex - 8, y: 2))
                lid.addQuadCurve(to: CGPoint(x: ex + 8, y: 2), control: CGPoint(x: ex, y: 10))
                c.stroke(lid, with: .color(lidColor), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
            } else {
                c.fill(Path(ellipseIn: CGRect(x: ex - 9, y: -6, width: 18, height: 18)), with: .color(palette.eyes))
                let px = ex + lookX
                let py = 3 + lookY
                c.fill(Path(ellipseIn: CGRect(x: px - 6.6, y: py - 6.6, width: 13.2, height: 13.2)), with: .color(Self.ink))
                c.fill(Path(ellipseIn: CGRect(x: px - 5.1, y: py - 5.5, width: 5, height: 5)), with: .color(.white))
                c.fill(Path(ellipseIn: CGRect(x: px + 1.4, y: py + 1.6, width: 2.4, height: 2.4)), with: .color(.white.opacity(0.85)))
                if expression == .grumpy {
                    // A heavy lid, lower towards the nose.
                    var lid = Path()
                    lid.move(to: CGPoint(x: ex + side * 11, y: -8))
                    lid.addLine(to: CGPoint(x: ex - side * 11, y: -8))
                    lid.addLine(to: CGPoint(x: ex - side * 11, y: 4.5))
                    lid.addLine(to: CGPoint(x: ex + side * 11, y: -1.5))
                    lid.closeSubpath()
                    c.fill(lid, with: .color(palette.fur))
                    var edge = Path()
                    edge.move(to: CGPoint(x: ex + side * 9.6, y: -1.1))
                    edge.addLine(to: CGPoint(x: ex - side * 9.6, y: 4.1))
                    c.stroke(edge, with: .color(dark ? Color(white: 0.52) : Self.ink), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
                }
            }
        }

        // Nose and mouth.
        var nose = Path()
        nose.move(to: CGPoint(x: -4, y: 13.5))
        nose.addQuadCurve(to: CGPoint(x: 4, y: 13.5), control: CGPoint(x: 0, y: 12))
        nose.addQuadCurve(to: CGPoint(x: 0, y: 18.5), control: CGPoint(x: 2.5, y: 18.5))
        nose.addQuadCurve(to: CGPoint(x: -4, y: 13.5), control: CGPoint(x: -2.5, y: 18.5))
        nose.closeSubpath()
        c.fill(nose, with: .color(palette.nose))
        var mouth = Path()
        switch expression {
        case .neutral:
            mouth.move(to: CGPoint(x: -6, y: 22))
            mouth.addQuadCurve(to: CGPoint(x: 0, y: 22), control: CGPoint(x: -3, y: 25.5))
            mouth.addQuadCurve(to: CGPoint(x: 6, y: 22), control: CGPoint(x: 3, y: 25.5))
        case .happy:
            mouth.move(to: CGPoint(x: -8, y: 21.5))
            mouth.addQuadCurve(to: CGPoint(x: 0, y: 21.5), control: CGPoint(x: -4, y: 27))
            mouth.addQuadCurve(to: CGPoint(x: 8, y: 21.5), control: CGPoint(x: 4, y: 27))
        case .grumpy:
            mouth.move(to: CGPoint(x: -5.5, y: 25))
            mouth.addQuadCurve(to: CGPoint(x: 5.5, y: 25), control: CGPoint(x: 0, y: 20.5))
        }
        c.stroke(mouth, with: .color(lines.opacity(0.8)), style: StrokeStyle(lineWidth: 1.9, lineCap: .round, lineJoin: .round))

        // Whiskers.
        for side in [-1.0, 1.0] {
            for (from, to) in [(CGPoint(x: 42, y: 21), CGPoint(x: 56, y: 19)), (CGPoint(x: 41, y: 26), CGPoint(x: 54, y: 29))] {
                var w = Path()
                w.move(to: CGPoint(x: side * from.x, y: from.y))
                w.addLine(to: CGPoint(x: side * to.x, y: to.y))
                c.stroke(w, with: .color(lines.opacity(0.4)), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
            }
        }
    }
}

#if DEBUG
struct CatView_Previews: PreviewProvider {
    static var previews: some View {
        HStack {
            CatView(pose: .walking(step: 0.8), palette: .orange)
            CatView(pose: .sitting, palette: .black)
            CatView(pose: .sleeping, palette: .gray)
            CatView(pose: .stretching, palette: .cream)
        }
        .frame(width: 800, height: 160)
        .padding()
    }
}
#endif
