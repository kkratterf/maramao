import AppKit
import SpriteKit
import SwiftUI

/// "Invasione di gatti": cats rain down on every screen with real physics and pile up
/// until the screen is buried. Clicks are blocked from the start, but the user still
/// sees their work while it disappears under the cats. Clicking a cat makes it jump.
/// At the end the pile scatters and falls off the screen.
@MainActor
final class CatPileBreak: BreakMode {
    private struct Pile {
        let window: OverlayWindow
        let view: SKView
        let scene: CatPileScene
    }

    private var piles: [Pile] = []
    private var hudWindows: [OverlayWindow] = []
    private var hasBegun = false
    private var hasEnded = false

    func begin(context: BreakContext) {
        guard !hasBegun, !hasEnded else { return }
        hasBegun = true

        let screens = BreakScreens.current()
        guard !screens.isEmpty else { return }

        // Render the cats once, at the sharpest backing scale in use.
        let scale = screens.map(\.backingScaleFactor).max() ?? 2
        let artworks = CatPileArt.render(scale: scale)

        // Bury the screen at ~65% of the break: about 20 s in a 30 s preview.
        let fillTime = context.duration * 0.65
        let hudLevel = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)

        for screen in screens {
            let window = OverlayWindow(screen: screen, level: .screenSaver, clickThrough: false)
            let size = screen.frame.size
            let view = CatPileSKView(frame: NSRect(origin: .zero, size: size))
            view.autoresizingMask = [.width, .height]
            view.allowsTransparency = true
            view.ignoresSiblingOrder = true
            view.preferredFramesPerSecond = 60
            let scene = CatPileScene(size: size, artworks: artworks, fillTime: fillTime)
            window.contentView = view
            view.presentScene(scene)
            window.show()
            piles.append(Pile(window: window, view: view, scene: scene))

            hudWindows.append(makeHUDWindow(on: screen, level: hudLevel, context: context))
        }
    }

    func end() {
        guard !hasEnded else { return }
        hasEnded = true

        let closingHUDs = hudWindows
        hudWindows = []
        closingHUDs.forEach { $0.fadeOutAndClose(duration: 0.3) }

        let closingPiles = piles
        piles = []
        guard !closingPiles.isEmpty else { return }
        closingPiles.forEach { $0.scene.scatter() }

        // Let the pile fall for ~1.5 s, then fade out and tear everything down.
        // `self` is captured strongly to stay alive during the exit animation.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            self.close(closingPiles)
        }
    }

    private func close(_ closing: [Pile]) {
        for pile in closing {
            pile.window.fadeOutAndClose(duration: 0.35) {
                pile.scene.isPaused = true
                pile.scene.removeAllActions()
                pile.scene.removeAllChildren()
                pile.view.presentScene(nil)
            }
        }
    }

    private func makeHUDWindow(on screen: NSScreen, level: NSWindow.Level, context: BreakContext) -> OverlayWindow {
        let size = NSSize(width: 480, height: 110)
        let visible = screen.visibleFrame
        let frame = NSRect(
            x: screen.frame.midX - size.width / 2,
            y: visible.maxY - size.height - 8,
            width: size.width,
            height: size.height
        )
        let window = OverlayWindow(frame: frame, level: level, clickThrough: false)
        let hud = BreakHUD(context: context, message: "Invasione di gatti in corso.")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        let hosting = CatPileHUDHostingView(rootView: AnyView(hud))
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.autoresizingMask = [.width, .height]
        window.contentView = hosting
        window.show()
        return window
    }
}

/// Hosts the HUD and lets the skip button work on the first click, even though the
/// window never becomes key.
final class CatPileHUDHostingView: NSHostingView<AnyView> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
