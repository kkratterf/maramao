import SwiftUI

/// Everything shown on one screen: the dim curtain, the stage with the cat and the laser dot,
/// and on the main screen the HUD, the catch counter and the idle hint.
/// This view observes nothing itself, so the per-frame updates only redraw the stage.
struct LaserChaseScene: View {
    let model: LaserChaseModel
    let status: LaserChaseStatus
    let context: BreakContext
    /// The screen's frame in global Cocoa coordinates.
    let screenFrame: CGRect
    let isMain: Bool

    var body: some View {
        ZStack {
            LaserChaseCurtain()
            LaserChaseStage(model: model, screenFrame: screenFrame)
                .allowsHitTesting(false)
            if isMain {
                LaserChaseOverlay(status: status, context: context)
            }
        }
        .frame(width: screenFrame.width, height: screenFrame.height)
        .ignoresSafeArea()
    }
}

/// A dark room with a faint warm spot on the floor, so the red dot pops.
struct LaserChaseCurtain: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.03, blue: 0.07).opacity(0.86),
                    Color(red: 0.08, green: 0.06, blue: 0.1).opacity(0.9),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [Color(red: 1.0, green: 0.75, blue: 0.5).opacity(0.07), .clear],
                center: UnitPoint(x: 0.5, y: 0.7),
                startRadius: 0,
                endRadius: 700
            )
        }
    }
}

// MARK: - Stage

/// The cat, its shadow, bubble and hearts, and the laser dot, whenever they are on this screen.
struct LaserChaseStage: View {
    @ObservedObject var model: LaserChaseModel
    let screenFrame: CGRect

    var body: some View {
        let s = model.snapshot
        let catVisible = s.frameRect.insetBy(dx: -120, dy: -120).intersects(screenFrame)
        let dotVisible = s.dotVisible && screenFrame.insetBy(dx: -80, dy: -80).contains(s.dot)
        ZStack {
            Color.clear
            if catVisible {
                shadowLayer(s)
                catLayer(s)
            }
            ForEach(s.hearts) { heart in
                heartLayer(heart, time: s.time)
            }
            if dotVisible {
                LaserChaseDot(points: s.trail.map { local($0) }, time: s.time)
            }
            if catVisible, let text = s.bubble {
                bubbleLayer(text, s)
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

    private func bubbleLayer(_ text: String, _ s: LaserChaseSnapshot) -> some View {
        let headOffset: CGFloat = s.facingLeft ? -s.width * 0.18 : s.width * 0.18
        var anchor = local(CGPoint(x: s.position.x + headOffset, y: s.position.y + s.lift + s.height + 26))
        anchor.x = min(max(anchor.x, 180), max(180, screenFrame.width - 180))
        anchor.y = max(anchor.y, 40)
        let appear = min(1.0, max(0.0, s.bubbleAge / 0.18))
        let fade = min(1.0, max(0.0, s.bubbleRemaining / 0.3))
        return LaserChaseBubble(text: text)
            .scaleEffect(CGFloat(0.6 + 0.4 * appear), anchor: .bottom)
            .opacity(appear * fade)
            .position(x: anchor.x, y: anchor.y)
    }

    private func heartLayer(_ heart: LaserChaseHeart, time: TimeInterval) -> some View {
        let age = time - heart.birth
        let progress = min(1.0, max(0.0, age / LaserChaseHeart.lifetime))
        let p = CGFloat(progress)
        let sway = CGFloat(sin(progress * 9.0)) * 5
        let point = local(CGPoint(x: heart.origin.x + heart.drift * p + sway, y: heart.origin.y + 110 * p))
        let grow = CGFloat(0.6 + 0.6 * min(1.0, progress * 4))
        return Text("❤️")
            .font(.system(size: heart.size))
            .scaleEffect(grow)
            .opacity(age < 0 ? 0 : 1 - progress)
            .position(x: point.x, y: point.y)
    }
}

/// The laser dot: a short fading trail, a flickering red halo and a hot white core.
struct LaserChaseDot: View {
    /// Local points, oldest first; the last one is the dot.
    let points: [CGPoint]
    let time: TimeInterval

    private static let red = Color(red: 1.0, green: 0.08, blue: 0.12)

    var body: some View {
        Canvas { ctx, _ in
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
            let flicker = CGFloat(1 + 0.07 * sin(time * 37) + 0.04 * sin(time * 23))
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
        }
    }
}

// MARK: - HUD and texts

/// Countdown, catch counter and the idle hint. Only on the main screen.
struct LaserChaseOverlay: View {
    @ObservedObject var status: LaserChaseStatus
    let context: BreakContext

    var body: some View {
        VStack(spacing: 12) {
            BreakHUD(context: context, message: status.message)
            LaserChaseCounter(catches: status.catches)
            Spacer()
            if status.showHint && !status.ending {
                Text("Muovi il mouse… il gatto aspetta")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.black.opacity(0.45)))
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(.top, 44)
        .padding(.bottom, 70)
        .animation(.easeInOut(duration: 0.35), value: status.showHint)
        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: status.catches)
    }
}

/// "🔴 Catture: N", popping a little at every catch.
struct LaserChaseCounter: View {
    let catches: Int

    var body: some View {
        HStack(spacing: 8) {
            Text("🔴")
                .font(.system(size: 14))
            Text("Catture: \(catches)")
                .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
                .id(catches)
                .transition(.scale(scale: 1.6).combined(with: .opacity))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.white.opacity(0.12)))
        .allowsHitTesting(false)
    }
}

/// A white speech bubble with a little tail, readable on the dark curtain.
struct LaserChaseBubble: View {
    let text: String

    var body: some View {
        VStack(spacing: 0) {
            Text(text)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(Color(white: 0.12))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white)
                )
            LaserChaseBubbleTail()
                .fill(Color.white)
                .frame(width: 18, height: 9)
        }
        .fixedSize()
        .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 3)
    }
}

struct LaserChaseBubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
