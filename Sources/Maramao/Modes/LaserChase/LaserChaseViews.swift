import SwiftUI

/// Everything shown on one screen: the blurred backdrop, the cat, on the main screen the HUD,
/// and the laser dot on top of everything. The dot is the pointer, so it must never hide
/// under the HUD's close button.
/// This view observes nothing itself, so the per-frame updates only redraw the stage.
struct LaserChaseScene: View {
    let model: LaserChaseModel
    let context: BreakContext
    /// The screen's frame in global Cocoa coordinates.
    let screenFrame: CGRect
    let isMain: Bool

    var body: some View {
        ZStack {
            // Like a modal on the Mac: the desktop blurred and darkened, so the red dot pops.
            ModalBackdrop(dim: 0.5)
            LaserChaseStage(model: model, screenFrame: screenFrame, layer: .cat)
                .allowsHitTesting(false)
            if isMain {
                VStack {
                    BreakHUD(context: context)
                    Spacer()
                }
                .padding(.top, 44)
            }
            LaserChaseStage(model: model, screenFrame: screenFrame, layer: .dot)
                .allowsHitTesting(false)
        }
        .frame(width: screenFrame.width, height: screenFrame.height)
        .ignoresSafeArea()
    }
}

// MARK: - Stage

/// The cat, its shadow and hearts, or the laser dot, whenever they are on this screen.
struct LaserChaseStage: View {
    enum Layer { case cat, dot }

    @ObservedObject var model: LaserChaseModel
    let screenFrame: CGRect
    let layer: Layer

    var body: some View {
        let s = model.snapshot
        let catVisible = s.frameRect.insetBy(dx: -120, dy: -120).intersects(screenFrame)
        let dotVisible = s.dotVisible && screenFrame.insetBy(dx: -80, dy: -80).contains(s.dot)
        ZStack {
            Color.clear
            switch layer {
            case .cat:
                if catVisible {
                    shadowLayer(s)
                    catLayer(s)
                }
                ForEach(s.hearts) { heart in
                    heartLayer(heart, time: s.time)
                }
            case .dot:
                if dotVisible {
                    LaserChaseDot(points: s.trail.map { local($0) }, time: s.time)
                }
            }
        }
        .frame(width: screenFrame.width, height: screenFrame.height)
    }

    /// Global Cocoa point → SwiftUI point in this window (top-left origin).
    private func local(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x - screenFrame.minX, y: screenFrame.maxY - point.y)
    }

    private func shadowLayer(_ s: LaserChaseSnapshot) -> some View {
        let center = local(CGPoint(x: s.position.x, y: s.position.y + s.height * 0.03))
        let shrink = max(0.45, 1 - s.lift / max(1, s.height * 1.6))
        return Ellipse()
            .fill(Color.black.opacity(0.45 * Double(shrink)))
            .frame(width: s.width * 0.72 * shrink, height: s.width * 0.11 * shrink)
            .blur(radius: 4)
            .position(x: center.x, y: center.y)
    }

    private func catLayer(_ s: LaserChaseSnapshot) -> some View {
        let center = local(CGPoint(x: s.position.x, y: s.position.y + s.lift + s.height / 2))
        return CatView(
            pose: s.pose,
            palette: model.palette,
            eyesClosed: s.eyesClosed,
            facingLeft: s.facingLeft,
            tailWag: s.tailWag
        )
        .frame(width: s.width, height: s.height)
        .scaleEffect(x: 1, y: s.squashY, anchor: .bottom)
        .position(x: center.x + s.jitter, y: center.y)
    }

    /// A heart flying out of the catch like a spray: fast at first, then slowing down and
    /// falling a little, fading out at the end.
    private func heartLayer(_ heart: LaserChaseHeart, time: TimeInterval) -> some View {
        let age = time - heart.birth
        let progress = min(1.0, max(0.0, age / LaserChaseHeart.lifetime))
        let t = CGFloat(max(0, age))
        // Ease-out travel plus a little gravity (Cocoa coordinates: y grows upwards).
        let travel = 1 - pow(1 - CGFloat(progress), 3)
        let reach = CGFloat(LaserChaseHeart.lifetime) * 0.55
        let x = heart.origin.x + heart.velocity.dx * reach * travel
        let y = heart.origin.y + heart.velocity.dy * reach * travel - 140 * t * t
        let point = local(CGPoint(x: x, y: y))
        let pop = CGFloat(0.4 + 0.8 * min(1.0, progress * 6))
        return Text(heart.symbol)
            .font(.system(size: heart.size))
            .scaleEffect(pop)
            .rotationEffect(.degrees(heart.spin * progress))
            .opacity(age < 0 ? 0 : 1 - pow(progress, 2))
            .position(x: point.x, y: point.y)
    }
}

/// The laser dot: a short fading trail, a flickering red halo and a hot white core.
struct LaserChaseDot: View {
    /// Local points, oldest first; the last one is the dot.
    let points: [CGPoint]
    let time: TimeInterval

    private static let red = Color(red: 1.0, green: 0.08, blue: 0.12)

    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        // Differentiate Without Color / Increase Contrast: a white ring, so the dot does not rely on red.
        let ringed = differentiateWithoutColor || contrast == .increased
        return Canvas { ctx, _ in
            let count = points.count
            if count > 1 {
                for index in 1..<count {
                    let from = points[index - 1]
                    let to = points[index]
                    if hypot(to.x - from.x, to.y - from.y) < 0.5 { continue }
                    let f = Double(index) / Double(count)
                    var segment = Path()
                    segment.move(to: from)
                    segment.addLine(to: to)
                    ctx.stroke(
                        segment,
                        with: .color(Self.red.opacity(0.4 * f)),
                        style: StrokeStyle(lineWidth: CGFloat(2 + 7 * f), lineCap: .round)
                    )
                }
            }
            guard let dot = points.last else { return }
            let flicker = BreakAccessibility.reduceMotion ? CGFloat(1) : CGFloat(1 + 0.07 * sin(time * 37) + 0.04 * sin(time * 23))
            let halo = 30 * flicker
            ctx.fill(
                Path(ellipseIn: CGRect(x: dot.x - halo, y: dot.y - halo, width: halo * 2, height: halo * 2)),
                with: .radialGradient(
                    Gradient(colors: [Self.red.opacity(0.6), Self.red.opacity(0.18), Self.red.opacity(0)]),
                    center: dot,
                    startRadius: 0,
                    endRadius: halo
                )
            )
            let mid: CGFloat = 8
            ctx.fill(
                Path(ellipseIn: CGRect(x: dot.x - mid, y: dot.y - mid, width: mid * 2, height: mid * 2)),
                with: .color(Self.red.opacity(0.95))
            )
            let core: CGFloat = 3.5
            ctx.fill(
                Path(ellipseIn: CGRect(x: dot.x - core, y: dot.y - core, width: core * 2, height: core * 2)),
                with: .color(Color(red: 1.0, green: 0.85, blue: 0.85))
            )
            if ringed {
                let ring: CGFloat = 13
                ctx.stroke(
                    Path(ellipseIn: CGRect(x: dot.x - ring, y: dot.y - ring, width: ring * 2, height: ring * 2)),
                    with: .color(.white),
                    lineWidth: 2.5
                )
            }
        }
    }
}
