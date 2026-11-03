import AppKit
import SwiftUI
import MaramaoCore

/// A small bubble right under the cat in the menu bar, for a moment, when ⇧⌘M starts,
/// pauses or resumes the timer. Without it a global shortcut gives no sign that it worked,
/// and people end up not knowing whether the timer is running.
///
/// Click-through and non-activating: it never takes focus from the app in front.
@MainActor
final class TimerToast {
    static let shared = TimerToast()

    /// Where the cat is in the menu bar, in screen coordinates, or nil when it cannot be
    /// seen (behind the notch, or a full menu bar). Set by `StatusItemController`.
    var anchor: () -> NSRect? = { nil }

    private var panel: NSPanel?
    private var hideTask: Task<Void, Never>?

    /// Shows what the timer is doing now. `justStarted` tells a fresh start from a resume.
    func showTimerState(justStarted: Bool) {
        let engine = PomodoroEngine.shared
        let clock = formatClock(engine.remaining)
        switch engine.phase {
        case .idle:
            return
        case .work where engine.isPaused:
            show(symbol: "pause.fill", title: String(localized: "Timer sospeso"), detail: clock)
        case .work:
            let title = justStarted ? String(localized: "Timer avviato") : String(localized: "Timer ripreso")
            show(symbol: "play.fill", title: title, detail: clock)
        case .shortBreak, .longBreak:
            // Breaks cannot be paused: say so, instead of doing nothing.
            show(symbol: MenuBarCat.symbolName, title: String(localized: "La pausa gatto non si ferma"), detail: clock)
        }
    }

    /// The menu bar is so full that macOS hides the cat (behind the notch): say so once, at
    /// the top of the screen, with the ways in that still work.
    func showHiddenItemWarning() {
        show(
            symbol: MenuBarCat.symbolName,
            title: String(localized: "La barra dei menu è piena"),
            detail: String(localized: "Il gatto è nascosto dietro il notch. Premi ⇧⌘M per avviare il timer, o riapri Maramao per vedere il menu."),
            stay: 8,
            forceTopCenter: true
        )
    }

    func show(symbol: String, title: String, detail: String?, stay: TimeInterval = 1.6, forceTopCenter: Bool = false) {
        close()
        let hosting = NSHostingView(rootView: TimerToastView(symbol: symbol, title: title, detail: detail))
        let size = hosting.fittingSize
        // A pill for one line, a rounded card when the text wraps.
        let radius = min(size.height / 2, 16)

        let background = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        background.material = .popover
        background.blendingMode = .behindWindow
        background.state = .active
        background.maskImage = NSImage(size: size, flipped: false) { rect in
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        hosting.frame = background.bounds
        hosting.autoresizingMask = [.width, .height]
        background.addSubview(hosting)

        let panel = NSPanel(
            contentRect: NSRect(origin: origin(for: size, forceTopCenter: forceTopCenter), size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.contentView = background
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.invalidateShadow()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 1
        }
        self.panel = panel
        BreakAccessibility.announce(title)

        hideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(max(0.5, stay) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.fadeOut()
        }
    }

    /// Closes the bubble right away. Safe to call at any time.
    func close() {
        hideTask?.cancel()
        hideTask = nil
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
    }

    private func fadeOut() {
        guard let panel else { return }
        self.panel = nil
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
            panel.close()
        })
    }

    /// Centred under the cat, kept on its screen; top centre of the pointer's screen when
    /// the cat cannot be seen.
    private func origin(for size: NSSize, forceTopCenter: Bool) -> NSPoint {
        if !forceTopCenter, let rect = anchor(),
           let screen = NSScreen.screens.first(where: { $0.frame.intersects(rect) }) {
            let visible = screen.visibleFrame
            let x = min(max(rect.midX - size.width / 2, visible.minX + 8), visible.maxX - size.width - 8)
            return NSPoint(x: x, y: rect.minY - size.height - 6)
        }
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        return NSPoint(x: visible.midX - size.width / 2, y: visible.maxY - size.height - 8)
    }
}

private struct TimerToastView: View {
    let symbol: String
    let title: String
    let detail: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
            if let detail, detail.count > 24 {
                // A longer message: title on top, the text wrapped under it.
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(width: 320, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                if let detail {
                    Text(detail)
                        .font(.system(size: 13).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .fixedSize()
    }
}
