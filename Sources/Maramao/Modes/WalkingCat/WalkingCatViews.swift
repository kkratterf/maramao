import AppKit
import SwiftUI

/// Full-screen, click-through layer for one screen. Draws the cat, its bubble, the "z"s
/// and the hearts whenever they fall on this screen (global → local conversion).
struct WalkingCatStageView: View {
    @ObservedObject var model: WalkingCatModel
    /// The screen's frame in global Cocoa coordinates.
    let screenFrame: CGRect

    var body: some View {
        let snapshot = model.snapshot
        let onThisScreen = snapshot.frameRect.insetBy(dx: -200, dy: -200).intersects(screenFrame)
        ZStack {
            Color.clear
            if onThisScreen {
                catLayer(snapshot)
                if snapshot.pose == .sleeping {
                    sleepyZs(snapshot)
                }
                if let text = snapshot.bubble {
                    bubbleLayer(text, snapshot)
                }
            }
            ForEach(snapshot.hearts) { heart in
                heartLayer(heart, time: snapshot.time)
            }
        }
        .frame(width: screenFrame.width, height: screenFrame.height)
        .allowsHitTesting(false)
    }

    /// Global Cocoa point → SwiftUI point in this window (top-left origin).
    private func local(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x - screenFrame.minX, y: screenFrame.maxY - point.y)
    }

    private func catLayer(_ s: WalkingCatSnapshot) -> some View {
        let width = s.width
        let height = s.height
        let center = local(CGPoint(x: s.position.x, y: s.position.y + height / 2))
        return CatView(
            pose: s.pose,
            palette: model.palette,
            eyesClosed: s.eyesClosed,
            facingLeft: s.facingLeft,
            tailWag: s.tailWag
        )
        .frame(width: width, height: height)
        .scaleEffect(x: s.breathX, y: s.breathY, anchor: .bottom)
        .shadow(color: Color.black.opacity(0.28), radius: 8, x: 0, y: 4)
        .opacity(s.opacity)
        .position(x: center.x, y: center.y)
    }

    private func sleepyZs(_ s: WalkingCatSnapshot) -> some View {
        let width = s.width
        let headFraction: CGFloat = s.facingLeft ? 0.25 : 0.75
        let headX = s.position.x - width / 2 + width * headFraction
        let base = local(CGPoint(x: headX, y: s.position.y + s.height * 0.48))
        let direction: CGFloat = s.facingLeft ? -1 : 1
        let time = s.time
        return ZStack {
            ForEach(0..<3, id: \.self) { index in
                let phase = (time * 0.33 + Double(index) / 3.0).truncatingRemainder(dividingBy: 1.0)
                let p = CGFloat(phase)
                let wobble = CGFloat(sin(phase * 7.0)) * 5
                Text(verbatim: "z")
                    .font(.system(size: 13 + 15 * p + width * 0.015, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.55), radius: 2, x: 0, y: 1)
                    .opacity(sin(phase * Double.pi) * 0.9)
                    .position(x: base.x + direction * (10 + 34 * p) + wobble, y: base.y - 70 * p)
            }
        }
    }

    private func bubbleLayer(_ text: String, _ s: WalkingCatSnapshot) -> some View {
        let catBody = s.bodyRect
        var anchor = local(CGPoint(x: catBody.midX, y: catBody.maxY + 30))
        anchor.x = min(max(anchor.x, 160), max(160, screenFrame.width - 160))
        anchor.y = max(anchor.y, 34)
        let appear = min(1.0, max(0.0, s.bubbleAge / 0.18))
        let fade = min(1.0, max(0.0, s.bubbleRemaining / 0.3))
        return WalkingCatBubble(text: text)
            .scaleEffect(CGFloat(0.6 + 0.4 * appear), anchor: .bottom)
            .opacity(appear * fade)
            .position(x: anchor.x, y: anchor.y)
    }

    private func heartLayer(_ heart: WalkingCatHeart, time: TimeInterval) -> some View {
        let age = time - heart.birth
        let progress = min(1.0, max(0.0, age / WalkingCatHeart.lifetime))
        let p = CGFloat(progress)
        let sway = CGFloat(sin(progress * 9.0)) * 4
        let point = local(CGPoint(x: heart.origin.x + heart.drift * p + sway, y: heart.origin.y + 95 * p))
        let grow = CGFloat(0.6 + 0.6 * min(1.0, progress * 4))
        return Text("❤️")
            .font(.system(size: heart.size))
            .scaleEffect(grow)
            .opacity(age < 0 ? 0 : 1 - progress)
            .position(x: point.x, y: point.y)
    }
}

/// A white speech bubble with a little tail, readable on any background.
struct WalkingCatBubble: View {
    let text: String

    var body: some View {
        VStack(spacing: 0) {
            Text(text)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(Color(white: 0.12))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white)
                )
            WalkingCatBubbleTail()
                .fill(Color.white)
                .frame(width: 18, height: 9)
        }
        .fixedSize()
        .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
    }
}

struct WalkingCatBubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// A paw print: a pad and four toes, toes pointing up.
struct WalkingCatPawShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addEllipse(in: CGRect(
            x: rect.minX + rect.width * 0.2,
            y: rect.minY + rect.height * 0.42,
            width: rect.width * 0.6,
            height: rect.height * 0.52
        ))
        let toes: [CGPoint] = [
            CGPoint(x: 0.0, y: 0.22),
            CGPoint(x: 0.24, y: 0.0),
            CGPoint(x: 0.54, y: 0.0),
            CGPoint(x: 0.78, y: 0.22),
        ]
        for toe in toes {
            path.addEllipse(in: CGRect(
                x: rect.minX + rect.width * toe.x,
                y: rect.minY + rect.height * toe.y,
                width: rect.width * 0.22,
                height: rect.height * 0.3
            ))
        }
        return path
    }
}

/// The tinted sheet over the blocked window, with a faint trail of paw prints.
struct WalkingCatBlockerView: View {
    private struct Paw {
        let x: CGFloat
        let y: CGFloat
        let angle: Double
    }

    /// A trail from the title bar towards the middle, where the cat sleeps.
    private static let paws: [Paw] = [
        Paw(x: 0.14, y: 0.12, angle: 140),
        Paw(x: 0.20, y: 0.17, angle: 150),
        Paw(x: 0.24, y: 0.24, angle: 138),
        Paw(x: 0.30, y: 0.28, angle: 152),
        Paw(x: 0.33, y: 0.36, angle: 136),
        Paw(x: 0.40, y: 0.39, angle: 150),
        Paw(x: 0.80, y: 0.80, angle: -40),
        Paw(x: 0.86, y: 0.74, angle: -28),
        Paw(x: 0.88, y: 0.66, angle: -44),
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(0.25))
                ForEach(0..<Self.paws.count, id: \.self) { index in
                    let paw = Self.paws[index]
                    WalkingCatPawShape()
                        .fill(Color.white.opacity(0.13))
                        .frame(width: 26, height: 24)
                        .rotationEffect(.degrees(paw.angle))
                        .position(x: geo.size.width * paw.x, y: geo.size.height * paw.y)
                }
            }
        }
    }
}

/// An invisible view that follows the cat and turns clicks into cuddles, and drags into
/// carrying the cat around. Points are global Cocoa coordinates (`NSEvent.mouseLocation`).
final class WalkingCatHitView: NSView {
    var onClick: (() -> Void)?
    var canDrag: () -> Bool = { false }
    var onDragBegan: ((CGPoint) -> Void)?
    var onDragMoved: ((CGPoint) -> Void)?
    var onDragEnded: ((CGPoint) -> Void)?

    /// How far the mouse must move before a click becomes a drag.
    private static let dragThreshold: CGFloat = 5
    private var downLocation: CGPoint?
    private var dragging = false

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        downLocation = NSEvent.mouseLocation
        dragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = downLocation else { return }
        let point = NSEvent.mouseLocation
        if !dragging {
            guard hypot(point.x - start.x, point.y - start.y) >= Self.dragThreshold, canDrag() else { return }
            dragging = true
            onDragBegan?(start)
        }
        onDragMoved?(point)
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            downLocation = nil
            dragging = false
        }
        guard downLocation != nil else { return }
        if dragging {
            onDragEnded?(NSEvent.mouseLocation)
        } else {
            onClick?()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        // Almost transparent, so the window server always routes clicks here.
        NSColor(white: 0, alpha: 0.01).setFill()
        dirtyRect.fill()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

/// Hosting view that reacts to the first click even when Maramao is not the active app,
/// so the skip button works with a single click.
final class WalkingCatFirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
