import AppKit
import SwiftUI

/// A borderless, transparent window that floats above everything, on every Space.
/// Break modes use it for cats, curtains and click blockers.
final class OverlayWindow: NSWindow {
    /// Whether the window may become key (needed for buttons that take keyboard focus).
    var allowsKey = false

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
