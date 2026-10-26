import SwiftUI

/// Where the branch sits inside the window, so the static twigs and the moving birds agree.
enum BirdWatchingBranch {
    /// Height of the branch at `x`, in the garden's own coordinate space.
    static func y(atX x: CGFloat, in size: CGSize) -> CGFloat {
        size.height * (0.60 - 0.07 * (x / max(size.width, 1)))
    }

    static let firstX = 0.06
    static let lastX = 0.9
}

/// The window onto the garden, shown on one screen. The main screen also gets the cat,
/// the HUD and the caption; the others get the garden alone.
struct BirdWatchingScene: View {
    @ObservedObject var model: BirdWatchingModel
    let context: BreakContext
    let isMain: Bool

    var body: some View {
        ZStack {
            // The room around the window: dark, so the eyes relax on the bright garden.
            LinearGradient(
                colors: [Color(white: 0.10), Color(white: 0.05)],
                startPoint: .top,
                endPoint: .bottom
            )

            GeometryReader { geo in
                let inset = min(geo.size.width, geo.size.height) * 0.07
                let width = geo.size.width - inset * 2
                let height = geo.size.height - inset * 2

                ZStack {
                    BirdWatchingWindow()
                        .frame(width: width, height: height)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)

                    if isMain {
                        BirdWatchingCat(model: model)
                            .frame(width: min(width * 0.3, 420), height: min(width * 0.3, 420) * 0.8)
                            .position(x: geo.size.width / 2 - width * 0.3, y: geo.size.height / 2 + height * 0.36)

                        VStack(spacing: 10) {
                            BreakHUD(context: context, message: model.hudMessage)
                            Text(model.caption)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.78))
                                .multilineTextAlignment(.center)
                                .id(model.caption)
                                .transition(.opacity)
                        }
                        .position(x: geo.size.width / 2, y: geo.size.height - inset * 0.9)
                        .animation(.easeInOut(duration: 0.5), value: model.caption)
                    } else {
                        Text("Una finestra sul giardino 🌿")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                            .position(x: geo.size.width / 2, y: geo.size.height - inset * 0.55)
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - The window

/// Garden, glass and wooden frame: everything inside the window opening.
struct BirdWatchingWindow: View {
    var body: some View {
        GeometryReader { geo in
            let corner = min(geo.size.width, geo.size.height) * 0.06
            let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)

            ZStack {
                BirdWatchingGarden()
                    .clipShape(shape)
                // A hint of glass: a soft diagonal reflection, nothing that hurts the eyes.
                LinearGradient(
                    colors: [.white.opacity(0.1), .clear, .white.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(shape)
                BirdWatchingMullions()
                shape.stroke(Color(red: 0.36, green: 0.25, blue: 0.17), lineWidth: 18)
                shape.stroke(Color(red: 0.52, green: 0.38, blue: 0.26).opacity(0.8), lineWidth: 6)
            }
            .shadow(color: .black.opacity(0.5), radius: 40)
        }
    }
}

/// The two bars that split the window into four panes, plus the sill.
struct BirdWatchingMullions: View {
    var body: some View {
        GeometryReader { geo in
            let wood = Color(red: 0.36, green: 0.25, blue: 0.17)
            ZStack {
                Rectangle()
                    .fill(wood)
                    .frame(width: 12)
                Rectangle()
                    .fill(wood)
                    .frame(height: 12)
                Rectangle()
                    .fill(Color(red: 0.44, green: 0.31, blue: 0.21))
                    .frame(height: 22)
                    .position(x: geo.size.width / 2, y: geo.size.height - 11)
            }
        }
    }
}

// MARK: - Garden

/// The view out of the window: sky, hills, a hedge, a branch, birds hopping on it.
///
/// Everything that moves lives in one canvas redrawn at 15 fps: the birds hop a few points a
/// second, so a faster timeline would look the same and cost twice as much on every display.
struct BirdWatchingGarden: View {
    /// One bird hopping back and forth on the branch.
    private struct Bird {
        var base: Double
        var span: Double
        var speed: Double
        var phase: Double
        var hopRate: Double
        var scale: Double
        var belly: Double
    }

    private static let birds: [Bird] = (0..<5).map { index in
        let slot = Double(index) / 5
        return Bird(
            base: BirdWatchingBranch.firstX + slot * (BirdWatchingBranch.lastX - BirdWatchingBranch.firstX) + 0.02,
            span: Double.random(in: 0.02...0.05),
            speed: Double.random(in: 0.18...0.35),
            phase: Double.random(in: 0...(2 * Double.pi)),
            hopRate: Double.random(in: 1.6...2.6),
            scale: Double.random(in: 0.85...1.2),
            belly: Double.random(in: 0...1)
        )
    }

    private struct Cloud {
        var y: Double
        var speed: Double
        var scale: Double
        var offset: Double
    }

    private static let clouds: [Cloud] = (0..<3).map { index in
        Cloud(
            y: 0.1 + Double(index) * 0.08,
            speed: Double.random(in: 0.004...0.009),
            scale: Double.random(in: 0.8...1.4),
            offset: Double.random(in: 0...1)
        )
    }

    var body: some View {
        ZStack {
            // Sky and meadow: soft greens and blues, the restful end of the palette.
            LinearGradient(
                colors: [
                    Color(red: 0.55, green: 0.78, blue: 0.93),
                    Color(red: 0.76, green: 0.89, blue: 0.95),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            GeometryReader { geo in
                ZStack {
                    BirdWatchingHills()
                    // Reduce Motion: the birds sit still, the clouds stop and only the
                    // leaves keep a very small sway.
                    let calm = BreakAccessibility.reduceMotion
                    TimelineView(.animation(minimumInterval: 1.0 / 15.0, paused: false)) { timeline in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        Canvas { ctx, size in
                            drawClouds(&ctx, size: size, t: calm ? 0 : t)
                            drawBranch(&ctx, size: size, t: t, calm: calm)
                            drawBirds(&ctx, size: size, t: calm ? 0 : t)
                            if !calm { drawFlyBy(&ctx, size: size, t: t) }
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
            }
        }
    }

    // MARK: Drawing

    private func drawClouds(_ ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for cloud in Self.clouds {
            let drift = (cloud.offset + t * cloud.speed).truncatingRemainder(dividingBy: 1.3) - 0.15
            let x = CGFloat(drift) * size.width
            let y = CGFloat(cloud.y) * size.height
            let w = CGFloat(150 * cloud.scale)
            let h = CGFloat(46 * cloud.scale)
            var path = Path()
            path.addEllipse(in: CGRect(x: x, y: y, width: w, height: h))
            path.addEllipse(in: CGRect(x: x + w * 0.25, y: y - h * 0.4, width: w * 0.55, height: h * 1.1))
            path.addEllipse(in: CGRect(x: x + w * 0.55, y: y - h * 0.1, width: w * 0.5, height: h * 0.9))
            ctx.fill(path, with: .color(.white.opacity(0.75)))
        }
    }

    private func drawBranch(_ ctx: inout GraphicsContext, size: CGSize, t: Double, calm: Bool) {
        let bark = Color(red: 0.33, green: 0.22, blue: 0.15)
        let leaf = Color(red: 0.25, green: 0.55, blue: 0.27)
        let startY = BirdWatchingBranch.y(atX: 0, in: size)
        let endY = BirdWatchingBranch.y(atX: size.width, in: size)
        var branch = Path()
        branch.move(to: CGPoint(x: -10, y: startY))
        branch.addLine(to: CGPoint(x: size.width + 10, y: endY))
        ctx.stroke(branch, with: .color(bark), style: StrokeStyle(lineWidth: 14, lineCap: .round))

        // Leaves hanging under the branch, swaying gently even with Reduce Motion on.
        let sway: Double = calm ? 2 : 7
        for index in 0..<14 {
            let fx = 0.03 + Double(index) / 14 * 0.94
            let x = CGFloat(fx) * size.width
            let y = BirdWatchingBranch.y(atX: x, in: size)
            let wobble = CGFloat(sin(t * (calm ? 0.4 : 1.1) + Double(index)) * sway)
            let w: CGFloat = 34
            let h: CGFloat = 19
            let rect = CGRect(x: x - w / 2 + wobble, y: y + 10, width: w, height: h)
            ctx.fill(Path(ellipseIn: rect), with: .color(leaf.opacity(0.9)))
            var stem = Path()
            stem.move(to: CGPoint(x: x, y: y + 4))
            stem.addLine(to: CGPoint(x: rect.midX, y: rect.midY))
            ctx.stroke(stem, with: .color(bark.opacity(0.8)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        }
    }

    private func drawBirds(_ ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for bird in Self.birds {
            let swing = sin(t * bird.speed + bird.phase)
            let fx = min(BirdWatchingBranch.lastX, max(BirdWatchingBranch.firstX, bird.base + swing * bird.span))
            let x = CGFloat(fx) * size.width
            let hop = CGFloat(abs(sin(t * bird.hopRate + bird.phase)) * 9 * bird.scale)
            let y = BirdWatchingBranch.y(atX: x, in: size) - 7 - hop
            drawBird(&ctx, at: CGPoint(x: x, y: y), scale: bird.scale, facingRight: swing >= 0, belly: bird.belly)
        }
    }

    /// One small bird, standing on the branch: body, head, beak, tail, eye.
    private func drawBird(_ ctx: inout GraphicsContext, at point: CGPoint, scale: Double, facingRight: Bool, belly: Double) {
        let body = Color(red: 0.32 + belly * 0.3, green: 0.3 + belly * 0.16, blue: 0.42 - belly * 0.12)
        let chest = Color(red: 0.98, green: 0.82 - belly * 0.2, blue: 0.5)
        var sub = ctx
        sub.translateBy(x: point.x, y: point.y)
        sub.scaleBy(x: CGFloat(facingRight ? scale : -scale), y: CGFloat(scale))

        var tail = Path()
        tail.move(to: CGPoint(x: -9, y: -12))
        tail.addLine(to: CGPoint(x: -26, y: -18))
        tail.addLine(to: CGPoint(x: -11, y: -5))
        tail.closeSubpath()
        sub.fill(tail, with: .color(body))

        sub.fill(Path(ellipseIn: CGRect(x: -14, y: -17, width: 26, height: 17)), with: .color(body))
        sub.fill(Path(ellipseIn: CGRect(x: -6, y: -11, width: 15, height: 10)), with: .color(chest))
        sub.fill(Path(ellipseIn: CGRect(x: 2, y: -25, width: 16, height: 15)), with: .color(body))

        var beak = Path()
        beak.move(to: CGPoint(x: 16, y: -19))
        beak.addLine(to: CGPoint(x: 25, y: -16.5))
        beak.addLine(to: CGPoint(x: 16, y: -14))
        beak.closeSubpath()
        sub.fill(beak, with: .color(Color(red: 0.95, green: 0.7, blue: 0.25)))

        sub.fill(Path(ellipseIn: CGRect(x: 10, y: -21, width: 3.4, height: 3.4)), with: .color(.black.opacity(0.8)))
        for legX in [-2.0, 4.0] {
            var leg = Path()
            leg.move(to: CGPoint(x: legX, y: -2))
            leg.addLine(to: CGPoint(x: legX, y: 5))
            sub.stroke(leg, with: .color(Color(red: 0.9, green: 0.62, blue: 0.3)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
    }

    /// Every ~24 s a bird crosses the sky, far away: something to follow with the eyes.
    private func drawFlyBy(_ ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let period = 24.0
        let raw = (t / period).truncatingRemainder(dividingBy: 1)
        guard raw < 0.4 else { return }
        let p = raw / 0.4
        let x = CGFloat(-0.1 + 1.2 * p) * size.width
        let y = size.height * CGFloat(0.2 + 0.05 * sin(p * Double.pi * 2))
        let flap = CGFloat(sin(t * 7) * 10)
        var wings = Path()
        wings.move(to: CGPoint(x: x - 16, y: y + flap))
        wings.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x - 8, y: y - 6 + flap))
        wings.addQuadCurve(to: CGPoint(x: x + 16, y: y + flap), control: CGPoint(x: x + 8, y: y - 6 + flap))
        ctx.stroke(wings, with: .color(Color(white: 0.25).opacity(0.55)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
    }
}

/// Far hills, a hedge and a tree trunk: the still part of the garden.
struct BirdWatchingHills: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 1.0, green: 0.97, blue: 0.82).opacity(0.7), .clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 220
                        )
                    )
                    .frame(width: 440, height: 440)
                    .position(x: w * 0.2, y: h * 0.12)
                Ellipse()
                    .fill(Color(red: 0.56, green: 0.73, blue: 0.56))
                    .frame(width: w * 1.1, height: h * 0.5)
                    .position(x: w * 0.25, y: h * 0.86)
                Ellipse()
                    .fill(Color(red: 0.44, green: 0.66, blue: 0.45))
                    .frame(width: w * 1.0, height: h * 0.42)
                    .position(x: w * 0.85, y: h * 0.92)
                Ellipse()
                    .fill(Color(red: 0.31, green: 0.52, blue: 0.33))
                    .frame(width: w * 1.4, height: h * 0.34)
                    .position(x: w * 0.5, y: h * 1.08)
            }
        }
    }
}

// MARK: - The cat

/// The cat sitting on the sill, watching the birds, with its chatter bubble.
struct BirdWatchingCat: View {
    @ObservedObject var model: BirdWatchingModel

    var body: some View {
        ZStack {
            // 12 fps is plenty for a slowly swinging tail, and the cat is the only thing
            // redrawing here.
            TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: false)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let calm = BreakAccessibility.reduceMotion
                let wag = calm ? 0 : sin(t * (model.isChattering ? 5.0 : 1.3)) * (model.isChattering ? 0.5 : 0.22)
                CatView(pose: .sitting, palette: model.palette, tailWag: wag)
            }
            if model.isChattering {
                Text(verbatim: "ek ek ek…")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(Color(white: 0.12))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.92))
                    )
                    .offset(x: 70, y: -90)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.isChattering)
        .shadow(color: .black.opacity(0.45), radius: 16, y: 6)
    }
}
