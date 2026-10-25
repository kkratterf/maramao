import SwiftUI

/// The night scene shown on one screen. The main screen gets the cat, the HUD and the stats;
/// the others get the sky and a quiet "Shhh".
struct SleepyCatScene: View {
    @ObservedObject var model: SleepyCatModel
    let context: BreakContext
    let isMain: Bool

    var body: some View {
        ZStack {
            SleepyNightSky()
            if isMain {
                SleepyCatStage(model: model, context: context)
            } else {
                secondary
            }
        }
        .ignoresSafeArea()
    }

    private var secondary: some View {
        VStack(spacing: 10) {
            Text("Shhh 🤫")
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
            Text(model.isAwake ? "😾 L'hai svegliato!" : "Il gatto dorme sull'altro schermo.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
        }
        .animation(.easeInOut(duration: 0.3), value: model.isAwake)
    }
}

// MARK: - Sky

/// Dark blue gradient, a glowing moon, twinkling stars drifting slowly and some warm dust.
struct SleepyNightSky: View {
    private struct Speck {
        var x: Double
        var y: Double
        var radius: Double
        var speed: Double
        var twinkle: Double
        var phase: Double
    }

    private static let stars: [Speck] = (0..<110).map { _ in
        Speck(
            x: Double.random(in: 0...1),
            y: Double.random(in: 0...0.8),
            radius: Double.random(in: 0.6...1.9),
            speed: Double.random(in: 0.0015...0.005),
            twinkle: Double.random(in: 0.6...2.0),
            phase: Double.random(in: 0...(2 * Double.pi))
        )
    }

    private static let dust: [Speck] = (0..<28).map { _ in
        Speck(
            x: Double.random(in: 0.25...0.75),
            y: Double.random(in: 0...1),
            radius: Double.random(in: 1.2...3.0),
            speed: Double.random(in: 0.006...0.018),
            twinkle: Double.random(in: 0.3...0.9),
            phase: Double.random(in: 0...(2 * Double.pi))
        )
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.02, green: 0.04, blue: 0.13),
                        Color(red: 0.06, green: 0.09, blue: 0.25),
                        Color(red: 0.13, green: 0.12, blue: 0.30),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Stars drift a few points a second: 15 fps looks the same as 30 and halves
                // the cost of redrawing a full-screen canvas on every display.
                // Reduce Motion: stars only twinkle in place and the dust is gone.
                let calm = BreakAccessibility.reduceMotion
                TimelineView(.animation(minimumInterval: 1.0 / 15.0, paused: false)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    Canvas { ctx, size in
                        for star in Self.stars {
                            let x = (star.x + (calm ? 0 : t) * star.speed).truncatingRemainder(dividingBy: 1) * size.width
                            let y = star.y * size.height
                            let alpha = 0.3 + 0.7 * (0.5 + 0.5 * sin(t * star.twinkle + star.phase))
                            let r = star.radius
                            ctx.fill(
                                Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                                with: .color(.white.opacity(alpha))
                            )
                        }
                        for speck in Self.dust where !calm {
                            // Dust rises slowly from the bottom and sways a little.
                            let rise = (speck.y + t * speck.speed).truncatingRemainder(dividingBy: 1)
                            let y = (1 - rise) * size.height
                            let x = speck.x * size.width + sin(t * speck.twinkle + speck.phase) * 18
                            let alpha = 0.35 * sin(rise * Double.pi)
                            let r = speck.radius
                            ctx.fill(
                                Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                                with: .color(Color(red: 1.0, green: 0.85, blue: 0.6).opacity(alpha))
                            )
                        }
                    }
                }

                SleepyMoon()
                    .frame(width: 110, height: 110)
                    .position(x: geo.size.width * 0.82, y: geo.size.height * 0.18)
            }
        }
    }
}

/// A crescent-ish moon with a soft halo.
struct SleepyMoon: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 1.0, green: 0.95, blue: 0.8).opacity(0.35), .clear],
                        center: .center,
                        startRadius: 20,
                        endRadius: 150
                    )
                )
                .frame(width: 300, height: 300)
            Circle()
                .fill(Color(red: 0.99, green: 0.95, blue: 0.82))
            Circle()
                .fill(Color(red: 0.9, green: 0.85, blue: 0.7).opacity(0.6))
                .frame(width: 18, height: 18)
                .offset(x: -18, y: 14)
            Circle()
                .fill(Color(red: 0.9, green: 0.85, blue: 0.7).opacity(0.5))
                .frame(width: 11, height: 11)
                .offset(x: 20, y: -16)
        }
    }
}

// MARK: - Main stage

/// Lamp glow, cushion, the cat with its Z's or speech bubble, then HUD and sleep stats.
struct SleepyCatStage: View {
    @ObservedObject var model: SleepyCatModel
    let context: BreakContext

    var body: some View {
        GeometryReader { geo in
            let catWidth = min(geo.size.width * 0.38, 460)
            let catHeight = catWidth * 0.8
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.47)

            ZStack {
                // Warm lamp glow behind the cat.
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 1.0, green: 0.7, blue: 0.35).opacity(0.38), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: catWidth * 1.05
                        )
                    )
                    .frame(width: catWidth * 2.1, height: catWidth * 2.1)
                    .position(center)

                SleepyCushion()
                    .frame(width: catWidth * 1.08, height: catWidth * 0.3)
                    .position(x: center.x, y: center.y + catHeight * 0.42)

                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
                    catLayer(date: timeline.date, width: catWidth, height: catHeight)
                }
                .frame(width: catWidth * 1.8, height: catHeight * 2.2)
                .position(center)

                if model.isAwake && !model.line.isEmpty {
                    SleepyBubble(text: model.line)
                        .frame(maxWidth: 440)
                        .position(x: center.x + catWidth * 0.12, y: center.y - catHeight * 0.72)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                        .id(model.line)
                }

                VStack(spacing: 10) {
                    if let result = model.resultLine {
                        Text(result)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
                            .transition(.opacity)
                    }
                    BreakHUD(context: context, message: model.hudMessage)
                    Text(SleepyCatLines.stat(percent: model.sleepPercent))
                        .font(.system(size: 13, weight: .medium, design: .rounded).monospacedDigit())
                        .foregroundColor(.white.opacity(0.72))
                }
                .position(x: geo.size.width / 2, y: geo.size.height - 110)
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: model.line)
            .animation(.easeInOut(duration: 0.4), value: model.resultLine)
        }
    }

    /// The cat itself plus its time-driven decorations, in a box centred on the cat.
    private func catLayer(date: Date, width: CGFloat, height: CGFloat) -> some View {
        let t = date.timeIntervalSinceReferenceDate
        let inPhase = max(0, date.timeIntervalSince(model.phaseStart))
        let phase = model.phase
        let level = Double(min(model.annoyance, 6))

        var pose: CatPose = .sleeping
        var eyesClosed = false
        var breathe: CGFloat = 1
        var jump: CGFloat = 0
        var wag: Double = 0

        switch phase {
        case .asleep:
            pose = .sleeping
            // Slow breathing, between 1.0 and 1.03.
            breathe = CGFloat(1 + 0.015 * (1 - cos(2 * Double.pi * t / 3.6)))
            wag = sin(t * 0.8) * 0.3
        case .startled:
            pose = .sitting
            let p = min(1, inPhase / 0.4)
            // Reduce Motion: the cat sits up without jumping.
            jump = BreakAccessibility.reduceMotion ? 0 : -height * 0.12 * CGFloat(sin(Double.pi * p))
            wag = sin(t * 14) * 0.6
        case .awake:
            pose = .sitting
            // The angrier the cat, the faster and wider the tail.
            wag = sin(t * (3 + level * 2.2)) * (0.2 + level * 0.09)
        case .drowsy:
            pose = .sitting
            // A slow blink before curling up again.
            eyesClosed = !(inPhase > 0.35 && inPhase < 0.5)
            wag = sin(t * 1.2) * 0.15
        case .stretching:
            pose = .stretching
            breathe = CGFloat(1 + 0.02 * min(1, inPhase / 0.6))
        }

        return ZStack {
            CatView(pose: pose, palette: model.palette, eyesClosed: eyesClosed, tailWag: wag)
                .frame(width: width, height: height)
                .scaleEffect(breathe, anchor: .bottom)
                .offset(y: jump)

            if phase == .asleep {
                ForEach(0..<3, id: \.self) { index in
                    zLetter(index: index, t: t, width: width, height: height)
                }
            }

            if phase == .startled {
                Text("❗️")
                    .font(.system(size: 40))
                    .offset(x: width * 0.12, y: -height * 0.55 + jump)
            }

            if phase == .awake && model.annoyance >= 4 {
                Text("💢")
                    .font(.system(size: 30))
                    .offset(x: width * 0.3, y: -height * 0.42)
                    .opacity(0.6 + 0.4 * sin(t * 6))
            }
        }
    }

    /// One floating "Z", drifting up and to the right from the sleeping head, then fading.
    private func zLetter(index: Int, t: Double, width: CGFloat, height: CGFloat) -> some View {
        let period = 3.6
        let raw = (t / period + Double(index) / 3).truncatingRemainder(dividingBy: 1)
        // Reduce Motion: each Z stays in its place and only fades in and out.
        let calm = BreakAccessibility.reduceMotion
        let p = calm ? CGFloat(index + 1) / 4 : CGFloat(raw)
        // The sleeping head sits at about (150, 118) in the cat's 200×160 design space.
        let startX = width * 0.25
        let startY = height * 0.18
        let x = startX + p * width * 0.22 + (calm ? 0 : CGFloat(sin(raw * 2 * Double.pi)) * 8)
        let y = startY - p * height * 0.75
        let size = 20 + 16 * p
        return Text(index == 1 ? "z" : "Z")
            .font(.system(size: size, weight: .heavy, design: .rounded))
            .foregroundColor(Color(red: 0.85, green: 0.9, blue: 1.0))
            .opacity(Double(sin(raw * Double.pi)) * 0.9)
            .offset(x: x, y: y)
    }
}

/// A round cushion for the cat to sleep on.
struct SleepyCushion: View {
    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color(red: 0.0, green: 0.0, blue: 0.0).opacity(0.25))
                .offset(y: 10)
                .blur(radius: 8)
            Ellipse()
                .fill(Color(red: 0.38, green: 0.2, blue: 0.42))
            Ellipse()
                .fill(Color(red: 0.52, green: 0.3, blue: 0.55))
                .padding(.horizontal, 14)
                .padding(.top, 4)
                .padding(.bottom, 14)
        }
    }
}

/// The cat's speech bubble.
struct SleepyBubble: View {
    let text: String

    var body: some View {
        VStack(spacing: 0) {
            Text(text)
                .font(.system(size: 21, weight: .semibold, design: .rounded))
                .foregroundColor(Color(red: 0.12, green: 0.1, blue: 0.2))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white)
                )
            SleepyBubbleTail()
                .fill(Color.white)
                .frame(width: 24, height: 14)
                .offset(x: -30)
        }
        .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
    }
}

struct SleepyBubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX - rect.width * 0.2, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
