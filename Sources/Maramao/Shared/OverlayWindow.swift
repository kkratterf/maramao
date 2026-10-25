import AppKit
import SwiftUI

/// A borderless, transparent window that floats above everything, on every Space.
/// Break modes use it for cats, curtains and click blockers.
final class OverlayWindow: NSWindow {
    /// Whether the window may become key (needed for buttons that take keyboard focus).
    var allowsKey = false
    /// True for windows that belong to a break. The coordinator closes every live break
    /// overlay by force when a break mode fails to clean up (see `closeAllBreakOverlays`).
    /// Set it to false for windows that live outside breaks, like the peeking cat.
    var isBreakOverlay = true

    /// Every overlay window that has not been closed yet. Weak, so a window a mode forgot
    /// about still disappears from here once it is deallocated.
    private static let live = NSHashTable<OverlayWindow>.weakObjects()

    init(frame: NSRect, level: NSWindow.Level = .screenSaver, clickThrough: Bool = false) {
        super.init(contentRect: frame, styleMask: [.borderless, .fullSizeContentView], backing: .buffered, defer: false)
        self.level = level
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = clickThrough
        isReleasedWhenClosed = false
        isMovable = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        OverlayWindow.live.add(self)
    }

    /// Covers a whole screen.
    convenience init(screen: NSScreen, level: NSWindow.Level = .screenSaver, clickThrough: Bool = false) {
        self.init(frame: screen.frame, level: level, clickThrough: clickThrough)
        setFrame(screen.frame, display: false)
    }

    override var canBecomeKey: Bool { allowsKey }
    override var canBecomeMain: Bool { false }

    /// Hosts a SwiftUI view as the whole content of the window.
    func host<Content: View>(_ view: Content) {
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: frame.size)
        hosting.autoresizingMask = [.width, .height]
        contentView = hosting
    }

    func show() {
        orderFrontRegardless()
    }

    override func close() {
        OverlayWindow.live.remove(self)
        super.close()
    }

    /// Number of break overlays still open.
    static var openBreakOverlayCount: Int {
        live.allObjects.filter { $0.isBreakOverlay }.count
    }

    /// Closes every break overlay that is still open, right away and without animation.
    /// The last line of defence against a break mode that hangs or forgets a window.
    /// Returns how many windows were closed.
    @discardableResult
    static func closeAllBreakOverlays() -> Int {
        let windows = live.allObjects.filter { $0.isBreakOverlay }
        for window in windows {
            window.orderOut(nil)
            window.close()
        }
        return windows.count
    }

    /// Fades the window out and closes it.
    func fadeOutAndClose(duration: TimeInterval = 0.4, completion: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = duration
            animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
            self.close()
            completion?()
        })
    }
}

extension NSScreen {
    /// Height of the primary screen, used to flip Quartz (top-left) coordinates into Cocoa (bottom-left).
    static var primaryHeight: CGFloat { NSScreen.screens.first?.frame.height ?? 0 }

    /// Converts a rect from Quartz window-server coordinates (as returned by
    /// `CGWindowListCopyWindowInfo`) to Cocoa global coordinates.
    static func cocoaRect(fromQuartz rect: CGRect) -> NSRect {
        NSRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }
}
