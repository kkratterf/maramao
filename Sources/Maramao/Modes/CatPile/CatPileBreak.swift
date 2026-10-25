import AppKit
import SwiftUI

/// Placeholder until the full concept lands: a dimmed curtain with a cat and the countdown.
@MainActor
final class CatPileBreak: BreakMode {
    private var windows: [OverlayWindow] = []

    func begin(context: BreakContext) {
        windows = NSScreen.screens.map { screen in
            let window = OverlayWindow(screen: screen)
            window.host(PlaceholderCurtain(context: context))
            window.show()
            return window
        }
    }

    func end() {
        let closing = windows
        windows = []
        closing.forEach { $0.fadeOutAndClose() }
    }
}
