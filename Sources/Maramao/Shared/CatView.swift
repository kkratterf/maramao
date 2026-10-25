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
        fur: Color(white: 0.13),
        stripes: nil,
        belly: Color(white: 0.2),
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
    static func random() -> CatPalette { all.randomElement() ?? .orange }
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

/// A cat drawn with vector shapes, facing right, in a 200×160 design space scaled to the frame.
/// Use `.scaleEffect(x: -1)` (or `facingLeft: true`) to make it face left.
/// Shared by every break mode so the cats look like one family.
struct CatView: View {
    var pose: CatPose = .sitting
    var palette: CatPalette = .orange
    var eyesClosed = false
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
    }

    // MARK: - Poses

    private func drawWalking(_ ctx: inout GraphicsContext, step: Double) {
        let swing = sin(step) * 10
        // Far legs first, slightly darker.
        leg(&ctx, x: 72, top: 105, swing: -swing, dark: true)
        leg(&ctx, x: 132, top: 105, swing: swing, dark: true)
        tail(&ctx, from: CGPoint(x: 52, y: 92), wave: sin(step * 0.5) * 0.3 + tailWag, up: true)
        // Body.
        let body = Path(ellipseIn: CGRect(x: 45, y: 70, width: 115, height: 50))
        ctx.fill(body, with: .color(palette.fur))
        ctx.fill(Path(ellipseIn: CGRect(x: 70, y: 98, width: 70, height: 20)), with: .color(palette.belly))
        stripes(&ctx, in: CGRect(x: 70, y: 70, width: 70, height: 20))
        leg(&ctx, x: 62, top: 105, swing: swing, dark: false)
        leg(&ctx, x: 142, top: 105, swing: -swing, dark: false)
        head(&ctx, center: CGPoint(x: 160, y: 68 + sin(step * 2) * 1.5), radius: 27)
    }

    private func drawSitting(_ ctx: inout GraphicsContext) {
        tail(&ctx, from: CGPoint(x: 70, y: 142), wave: tailWag, up: false)
        // Haunch and chest.
        ctx.fill(Path(ellipseIn: CGRect(x: 58, y: 82, width: 84, height: 68)), with: .color(palette.fur))
        ctx.fill(Path(ellipseIn: CGRect(x: 95, y: 70, width: 50, height: 70)), with: .color(palette.fur))
        ctx.fill(Path(ellipseIn: CGRect(x: 108, y: 88, width: 30, height: 48)), with: .color(palette.belly))
        stripes(&ctx, in: CGRect(x: 64, y: 88, width: 40, height: 30))
        // Front legs.
        for x in [112.0, 128.0] {
            let legRect = CGRect(x: x, y: 112, width: 13, height: 38)
            ctx.fill(Path(roundedRect: legRect, cornerRadius: 6), with: .color(palette.fur))
            ctx.fill(Path(ellipseIn: CGRect(x: x - 2, y: 144, width: 17, height: 9)), with: .color(palette.belly))
        }
        head(&ctx, center: CGPoint(x: 124, y: 56), radius: 28)
    }

    private func drawSleeping(_ ctx: inout GraphicsContext) {
        // A loaf: one big round body, head tucked on the right, tail wrapped in front.
        ctx.fill(Path(ellipseIn: CGRect(x: 35, y: 95, width: 140, height: 58)), with: .color(palette.fur))
        stripes(&ctx, in: CGRect(x: 60, y: 98, width: 80, height: 22))
        head(&ctx, center: CGPoint(x: 150, y: 118), radius: 24, forceClosed: true, tilt: 0.15)
        var tailPath = Path()
        tailPath.move(to: CGPoint(x: 40, y: 135))
        tailPath.addQuadCurve(to: CGPoint(x: 140, y: 148), control: CGPoint(x: 70, y: 165 + tailWag * 10))
        ctx.stroke(tailPath, with: .color(palette.fur), style: StrokeStyle(lineWidth: 13, lineCap: .round))
        if let stripes = palette.stripes {
            ctx.stroke(tailPath, with: .color(stripes.opacity(0.5)), style: StrokeStyle(lineWidth: 13, lineCap: .round, dash: [6, 10]))
        }
    }

    private func drawStretching(_ ctx: inout GraphicsContext) {
        tail(&ctx, from: CGPoint(x: 50, y: 78), wave: 0.5 + tailWag, up: true)
        // Back legs straight, rear end high.
        leg(&ctx, x: 58, top: 95, swing: 0, dark: true, length: 55)
        leg(&ctx, x: 70, top: 95, swing: 0, dark: false, length: 55)
        var body = Path()
        body.addEllipse(in: CGRect(x: 45, y: 72, width: 60, height: 44))
        body.addEllipse(in: CGRect(x: 85, y: 92, width: 75, height: 40))
        ctx.fill(body, with: .color(palette.fur))
        stripes(&ctx, in: CGRect(x: 55, y: 76, width: 50, height: 20))
        // Front paws stretched forward on the ground.
        let paw = Path(roundedRect: CGRect(x: 120, y: 136, width: 55, height: 12), cornerRadius: 6)
        ctx.fill(paw, with: .color(palette.fur))
        ctx.fill(Path(ellipseIn: CGRect(x: 165, y: 136, width: 16, height: 12)), with: .color(palette.belly))
        head(&ctx, center: CGPoint(x: 155, y: 112), radius: 25, forceClosed: true)
    }

    // MARK: - Parts

    private func leg(_ ctx: inout GraphicsContext, x: Double, top: Double, swing: Double, dark: Bool, length: Double = 45) {
        var c = ctx
        c.translateBy(x: x, y: top)
        c.rotate(by: .degrees(swing))
        let rect = CGRect(x: -6, y: 0, width: 13, height: length)
        let color = dark ? palette.fur.opacity(0.75) : palette.fur
        c.fill(Path(roundedRect: rect, cornerRadius: 6), with: .color(color))
        c.fill(Path(ellipseIn: CGRect(x: -8, y: length - 6, width: 17, height: 9)), with: .color(palette.belly.opacity(dark ? 0.7 : 1)))
    }

    private func tail(_ ctx: inout GraphicsContext, from start: CGPoint, wave: Double, up: Bool) {
        var path = Path()
        path.move(to: start)
        if up {
            let tip = CGPoint(x: start.x - 30 + wave * 25, y: start.y - 55)
            path.addQuadCurve(to: tip, control: CGPoint(x: start.x - 40, y: start.y - 5))
        } else {
            let tip = CGPoint(x: start.x + 85, y: start.y + 6 - wave * 20)
            path.addQuadCurve(to: tip, control: CGPoint(x: start.x - 10, y: start.y + 18))
        }
        ctx.stroke(path, with: .color(palette.fur), style: StrokeStyle(lineWidth: 12, lineCap: .round))
        if let stripes = palette.stripes {
            ctx.stroke(path, with: .color(stripes.opacity(0.6)), style: StrokeStyle(lineWidth: 12, lineCap: .butt, dash: [6, 9]))
        }
    }

    private func stripes(_ ctx: inout GraphicsContext, in rect: CGRect) {
        guard let stripes = palette.stripes else { return }
        for i in 0..<3 {
            let x = rect.minX + rect.width * (0.2 + Double(i) * 0.3)
            var p = Path()
            p.move(to: CGPoint(x: x - 4, y: rect.minY + 2))
            p.addQuadCurve(to: CGPoint(x: x + 2, y: rect.maxY), control: CGPoint(x: x + 6, y: rect.midY))
            ctx.stroke(p, with: .color(stripes), style: StrokeStyle(lineWidth: 5, lineCap: .round))
        }
    }

    private func head(_ ctx: inout GraphicsContext, center: CGPoint, radius r: Double, forceClosed: Bool = false, tilt: Double = 0) {
        var c = ctx
        c.translateBy(x: center.x, y: center.y)
        c.rotate(by: .radians(tilt))

        // Ears.
        for side in [-1.0, 1.0] {
            var ear = Path()
            ear.move(to: CGPoint(x: side * r * 0.85, y: -r * 0.35))
            ear.addLine(to: CGPoint(x: side * r * 0.75, y: -r * 1.25))
            ear.addLine(to: CGPoint(x: side * r * 0.15, y: -r * 0.8))
            ear.closeSubpath()
            c.fill(ear, with: .color(palette.fur))
            var inner = Path()
            inner.move(to: CGPoint(x: side * r * 0.72, y: -r * 0.5))
            inner.addLine(to: CGPoint(x: side * r * 0.68, y: -r * 1.05))
            inner.addLine(to: CGPoint(x: side * r * 0.3, y: -r * 0.8))
            inner.closeSubpath()
            c.fill(inner, with: .color(palette.nose.opacity(0.6)))
        }

        c.fill(Path(ellipseIn: CGRect(x: -r, y: -r * 0.95, width: r * 2, height: r * 1.85)), with: .color(palette.fur))
        // Muzzle.
        c.fill(Path(ellipseIn: CGRect(x: -r * 0.55, y: r * 0.1, width: r * 1.1, height: r * 0.7)), with: .color(palette.belly))
        if let stripes = palette.stripes {
            for dx in [-0.25, 0.0, 0.25] {
                var p = Path()
                p.move(to: CGPoint(x: r * dx, y: -r * 0.9))
                p.addLine(to: CGPoint(x: r * dx * 0.8, y: -r * 0.55))
                c.stroke(p, with: .color(stripes), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
            }
        }

        // Eyes.
        let closed = eyesClosed || forceClosed
        for side in [-1.0, 1.0] {
            let ex = side * r * 0.42
            let ey = -r * 0.12
            if closed {
                var lid = Path()
                lid.move(to: CGPoint(x: ex - r * 0.18, y: ey))
                lid.addQuadCurve(to: CGPoint(x: ex + r * 0.18, y: ey), control: CGPoint(x: ex, y: ey + r * 0.16))
                c.stroke(lid, with: .color(.black.opacity(0.75)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            } else {
                c.fill(Path(ellipseIn: CGRect(x: ex - r * 0.17, y: ey - r * 0.2, width: r * 0.34, height: r * 0.4)), with: .color(palette.eyes))
                c.fill(Path(ellipseIn: CGRect(x: ex - r * 0.06, y: ey - r * 0.17, width: r * 0.12, height: r * 0.34)), with: .color(.black))
                c.fill(Path(ellipseIn: CGRect(x: ex - r * 0.02, y: ey - r * 0.14, width: r * 0.07, height: r * 0.07)), with: .color(.white))
            }
        }

        // Nose and mouth.
        var nose = Path()
        nose.move(to: CGPoint(x: -r * 0.1, y: r * 0.2))
        nose.addLine(to: CGPoint(x: r * 0.1, y: r * 0.2))
        nose.addLine(to: CGPoint(x: 0, y: r * 0.32))
        nose.closeSubpath()
        c.fill(nose, with: .color(palette.nose))
        var mouth = Path()
        mouth.move(to: CGPoint(x: -r * 0.16, y: r * 0.42))
        mouth.addQuadCurve(to: CGPoint(x: 0, y: r * 0.34), control: CGPoint(x: -r * 0.06, y: r * 0.48))
        mouth.addQuadCurve(to: CGPoint(x: r * 0.16, y: r * 0.42), control: CGPoint(x: r * 0.06, y: r * 0.48))
        c.stroke(mouth, with: .color(.black.opacity(0.6)), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))

        // Whiskers.
        for side in [-1.0, 1.0] {
            for dy in [-0.06, 0.08] {
                var w = Path()
                w.move(to: CGPoint(x: side * r * 0.35, y: r * (0.3 + dy)))
                w.addLine(to: CGPoint(x: side * r * 1.15, y: r * (0.22 + dy * 2)))
                c.stroke(w, with: .color(.black.opacity(0.35)), lineWidth: 1.2)
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
