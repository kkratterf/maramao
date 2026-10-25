import AppKit
import SwiftUI

/// The little cat that peeks up from the bottom of the screen shortly before a break:
/// "Miao, tra un minuto pausa". Click-through, so it never gets in the way.
@MainActor
final class PeekingCatWarning {
    private static let windowSize = NSSize(width: 320, height: 230)
    private static let stayOnScreen: TimeInterval = 6

    private var window: OverlayWindow?
    private var model: PeekingCatModel?
    private var sequence: Task<Void, Never>?

    var isVisible: Bool { window != nil }

    /// Peeks for about six seconds, then slides back down. Replaces a cat already on screen.
    func show(message: String) {
        close()
        guard let screen = Self.targetScreen() else { return }

        let size = Self.windowSize
        let frame = NSRect(
            x: screen.frame.maxX - size.width - 24,
            y: screen.frame.minY,
            width: size.width,
            height: size.height
        )
        let window = OverlayWindow(frame: frame, level: .statusBar, clickThrough: true)
        let model = PeekingCatModel(message: message, palette: CatPalette.random())
        window.host(PeekingCatView(model: model))
        window.show()
        self.window = window
        self.model = model

        sequence = Task { @MainActor [weak self] in
            guard await PeekingCatWarning.wait(0.05) else { return }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) { model.peeking = true }
            guard await PeekingCatWarning.wait(0.55) else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { model.bubbleVisible = true }
            for delay in [0.8, 2.2, 1.6] {
                guard await PeekingCatWarning.wait(delay) else { return }
                model.eyesClosed = true
                guard await PeekingCatWarning.wait(0.16) else { return }
                model.eyesClosed = false
            }
            let elapsed = 0.05 + 0.55 + 0.8 + 2.2 + 1.6 + 3 * 0.16
            guard await PeekingCatWarning.wait(max(0.1, Self.stayOnScreen - elapsed)) else { return }
            self?.dismiss()
        }
    }

    /// Slides the cat back down and closes the window. Safe to call at any time, more than once.
    func dismiss() {
        sequence?.cancel()
        sequence = nil
        guard let window, let model else { return }
        self.window = nil
        self.model = nil
        withAnimation(.easeIn(duration: 0.2)) { model.bubbleVisible = false }
        withAnimation(.easeIn(duration: 0.4)) { model.peeking = false }
        // The task holds the window strongly until it is closed.
        Task { @MainActor in
            _ = await PeekingCatWarning.wait(0.5)
            window.orderOut(nil)
            window.close()
        }
    }

    /// Closes the window right away, without animation.
    func close() {
        sequence?.cancel()
        sequence = nil
        window?.orderOut(nil)
        window?.close()
        window = nil
        model = nil
    }

    /// The screen with the mouse pointer, falling back to the main screen.
    private static func targetScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) {
            return screen
        }
        return NSScreen.main ?? NSScreen.screens.first
    }

    /// Sleeps for `seconds`. Returns false when the task was cancelled.
    private static func wait(_ seconds: Double) async -> Bool {
        do {
            try await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
        } catch {
            return false
        }
        return !Task.isCancelled
    }
}

@MainActor
final class PeekingCatModel: ObservableObject {
    let message: String
    let palette: CatPalette
    @Published var peeking = false
    @Published var bubbleVisible = false
    @Published var eyesClosed = false

    init(message: String, palette: CatPalette) {
        self.message = message
        self.palette = palette
    }
}

struct PeekingCatView: View {
    @ObservedObject var model: PeekingCatModel

    private let catSize = CGSize(width: 150, height: 120)
    /// How far below its resting place the cat sits while peeking: only head and shoulders show.
    private let peekOffset: CGFloat = 48

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.clear
            bubble
                .padding(.trailing, 92)
                .padding(.bottom, catSize.height - peekOffset + 4)
                .scaleEffect(model.bubbleVisible ? 1 : 0.6, anchor: .bottomTrailing)
                .opacity(model.bubbleVisible ? 1 : 0)
            CatView(pose: .sitting, palette: model.palette, eyesClosed: model.eyesClosed)
                .frame(width: catSize.width, height: catSize.height)
                .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
                .padding(.trailing, 8)
                .offset(y: model.peeking ? peekOffset : catSize.height + 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var bubble: some View {
        Text(model.message)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.black)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 180)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                BubbleShape()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
            )
    }
}

/// A rounded speech bubble with a small tail at the bottom right, pointing at the cat.
struct BubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let body = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height)
        var path = Path(roundedRect: body, cornerRadius: 12)
        var tail = Path()
        tail.move(to: CGPoint(x: body.maxX - 30, y: body.maxY - 1))
        tail.addLine(to: CGPoint(x: body.maxX + 6, y: body.maxY + 12))
        tail.addLine(to: CGPoint(x: body.maxX - 14, y: body.maxY - 1))
        tail.closeSubpath()
        path.addPath(tail)
        return path
    }
}
