import AppKit
import Carbon.HIToolbox
import MaramaoCore

/// The way out of any break, strict mode included, that needs no permission and works even
/// when a break mode's own UI is broken:
/// - the global shortcut ⌃⌥⌘⌫ (a Carbon hot key via `HotKeyCenter`, no Accessibility needed);
/// - five quick clicks in the top-left corner of any screen, where a tiny invisible window
///   floats above every break overlay.
///
/// The coordinator arms it while a break is on screen and disarms it afterwards.
@MainActor
final class EmergencyExitGuard {
    /// ⌃⌥⌘⌫. A Carbon hot key: it works while another app is active and, unlike a global
    /// `NSEvent` monitor, needs no Accessibility permission.
    static let shortcut = HotKeyCombo(keyCode: kVK_Delete, modifiers: HotKeyCombo.controlOptionCommand)
    /// Shown in Settings ("⌃⌥⌘⌫").
    static var shortcutLabel: String { shortcut.displayString }
    private static let hotKeyID = "emergencyExit"
    static let cornerClicks = 5

    private let onTrigger: () -> Void
    private var localMonitor: Any?
    private var cornerWindows: [EmergencyCornerWindow] = []
    private var screenObserver: NSObjectProtocol?
    private var clicks = RapidClickDetector(requiredClicks: EmergencyExitGuard.cornerClicks, window: 3)

    private(set) var isArmed = false

    init(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
    }

    func arm() {
        guard !isArmed else { return }
        isArmed = true
        clicks.reset()

        let registered = HotKeyCenter.shared.register(id: Self.hotKeyID, combo: Self.shortcut) { [weak self] in
            Task { @MainActor in self?.fire() }
        }
        if !registered {
            DiagnosticLog.breaks.error("Could not register the emergency shortcut; the corner and the key monitor still work")
        }

        // Belt and braces: when one of our windows is key the local monitor sees the shortcut
        // even if the hot key could not be registered (e.g. another app owns it).
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard Self.isEmergencyShortcut(event) else { return event }
            Task { @MainActor in self?.fire() }
            return nil
        }

        buildCornerWindows()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.buildCornerWindows() }
        }
    }

    func disarm() {
        guard isArmed else { return }
        isArmed = false
        HotKeyCenter.shared.unregister(id: Self.hotKeyID)
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        localMonitor = nil
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        screenObserver = nil
        closeCornerWindows()
        clicks.reset()
    }

    private func fire() {
        guard isArmed else { return }
        onTrigger()
    }

    private func cornerClicked(at time: TimeInterval) {
        guard isArmed else { return }
        if clicks.registerClick(at: time) {
            fire()
        }
    }

    private func buildCornerWindows() {
        closeCornerWindows()
        guard isArmed else { return }
        for screen in NSScreen.screens {
            let window = EmergencyCornerWindow(screen: screen) { [weak self] time in
                self?.cornerClicked(at: time)
            }
            window.orderFrontRegardless()
            cornerWindows.append(window)
        }
    }

    private func closeCornerWindows() {
        for window in cornerWindows {
            window.orderOut(nil)
            window.close()
        }
        cornerWindows.removeAll()
    }

    nonisolated private static func isEmergencyShortcut(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let wanted: NSEvent.ModifierFlags = [.control, .option, .command]
        return event.keyCode == UInt16(kVK_Delete) && flags.intersection([.control, .option, .command, .shift]) == wanted
    }
}

/// A 20×20 pt window in the top-left corner of a screen, above every break overlay.
/// Nearly invisible, but it catches clicks.
private final class EmergencyCornerWindow: NSWindow {
    static let side: CGFloat = 20
    /// Above the break overlays (`.screenSaver`) and their HUDs (`.screenSaver + 1`).
    static let cornerLevel = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 2)

    init(screen: NSScreen, onClick: @escaping (TimeInterval) -> Void) {
        let frame = NSRect(
            x: screen.frame.minX,
            y: screen.frame.maxY - Self.side,
            width: Self.side,
            height: Self.side
        )
        super.init(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        level = Self.cornerLevel
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        // Set explicitly, so the window takes clicks even where it is transparent.
        ignoresMouseEvents = false
        isReleasedWhenClosed = false
        isMovable = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        let view = EmergencyCornerView(frame: NSRect(origin: .zero, size: frame.size))
        view.onClick = onClick
        contentView = view
        setFrame(frame, display: false)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class EmergencyCornerView: NSView {
    var onClick: ((TimeInterval) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        // Almost transparent: invisible on top of a cat, but a real hit target.
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.02).cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    // Maramao is never the active app during a break: the first click must count.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        onClick?(event.timestamp)
    }
}
