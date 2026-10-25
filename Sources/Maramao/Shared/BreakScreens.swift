import AppKit
import SwiftUI
import MaramaoCore

/// The single place where break modes get their screens, honouring the "Schermi" setting.
///
/// The coordinator calls `beginBreak()` when a break starts, which freezes the selection for
/// that break (so "the screen with the mouse" does not jump around) and lightly dims the
/// screens left out, so the break is still visible there. `endBreak()` undoes both.
@MainActor
enum BreakScreens {
    private static var selection: [NSScreen]?
    private static var dimWindows: [OverlayWindow] = []

    /// Screens the current break covers. Outside a break, the selection for the setting right now.
    static func current() -> [NSScreen] {
        let connected = NSScreen.screens
        if let selection {
            let stillThere = selection.filter { connected.contains($0) }
            if !stillThere.isEmpty { return stillThere }
        }
        return select(scope: AppSettings.shared.displayScope)
    }

    /// The screen among `screens` that gets the HUD and the main scene: the one with the key
    /// window if covered, else the one with the mouse, else the first.
    static func primary(in screens: [NSScreen]) -> NSScreen? {
        if let main = NSScreen.main, screens.contains(main) { return main }
        let mouse = NSEvent.mouseLocation
        if let underMouse = screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) { return underMouse }
        return screens.first
    }

    static func select(scope: DisplayScope) -> [NSScreen] {
        let screens = NSScreen.screens
        let mouse = NSEvent.mouseLocation
        let mouseIndex = screens.firstIndex { NSMouseInRect(mouse, $0.frame, false) }
        return scope.selectedIndices(displayCount: screens.count, mouseIndex: mouseIndex).map { screens[$0] }
    }

    static func beginBreak() {
        endBreak()
        let chosen = select(scope: AppSettings.shared.displayScope)
        selection = chosen
        for screen in NSScreen.screens where !chosen.contains(screen) {
            // Click-through and below the break overlays: just a hint that it is break time.
            let window = OverlayWindow(screen: screen, level: .floating, clickThrough: true)
            window.host(Color.black.opacity(0.28).ignoresSafeArea())
            window.alphaValue = 0
            window.show()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.5
                window.animator().alphaValue = 1
            }
            dimWindows.append(window)
        }
    }

    static func endBreak() {
        selection = nil
        let closing = dimWindows
        dimWindows = []
        for window in closing {
            window.fadeOutAndClose(duration: 0.4)
        }
    }
}
