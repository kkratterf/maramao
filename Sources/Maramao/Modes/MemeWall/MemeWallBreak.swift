import AppKit
import SwiftUI

/// "Muro di meme": every screen becomes a wall of cat memes drawn in code.
/// Each card is a classic meme (bold white caption on top and bottom) over a procedural cat that
/// loops a little animation like a GIF. Cards swap to a new meme every 6-9 seconds, staggered.
@MainActor
final class MemeWallBreak: BreakMode {
    private var windows: [OverlayWindow] = []
    private var walls: [MemeWallModel] = []
    private var timer: Timer?
    private var started = false
    private var ended = false
    private let deck = MemeWallDeck()

    func begin(context: BreakContext) {
        guard !started, !ended else { return }
        started = true

        let userImages = MemeWallUserImages.load()
        // Shorter entrance in a 30 s preview.
        let entranceScale = min(1, max(0.3, context.duration / 60))
        for screen in NSScreen.screens {
            let wall = MemeWallModel(
                cardCount: Self.cardCount(for: screen.frame.size),
                deck: deck,
                userImages: userImages,
                entranceScale: entranceScale
            )
            let window = OverlayWindow(screen: screen)
            window.host(MemeWallView(context: context, wall: wall))
            window.show()
            walls.append(wall)
            windows.append(window)
        }
        walls.forEach { $0.start() }

        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func end() {
        guard !ended else { return }
        ended = true
        timer?.invalidate()
        timer = nil

        let closing = windows
        let exiting = walls
        windows = []
        walls = []
        exiting.forEach { $0.exit() }

        // Cards fly away (~0.6 s), then the windows fade. Strong capture keeps us alive meanwhile.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            closing.forEach { $0.fadeOutAndClose(duration: 0.35) }
            withExtendedLifetime(self) {}
            withExtendedLifetime(exiting) {}
        }
    }

    private func tick() {
        guard !ended else { return }
        let now = Date()
        walls.forEach { $0.tick(now: now) }
    }

    /// Fewer cards on small screens.
    nonisolated static func cardCount(for size: CGSize) -> Int {
        if size.width < 1200 || size.height < 720 { return 3 }
        if size.width < 1700 { return 4 }
        return 6
    }
}
