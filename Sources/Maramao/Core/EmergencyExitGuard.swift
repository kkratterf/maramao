import AppKit
import Carbon.HIToolbox
import MaramaoCore
import os

/// The way out of any break, strict mode included, that needs no permission and works even
/// when a break mode's own UI is broken:
/// - the global shortcut ⌃⌥⌘⌫ (a Carbon hot key, which needs no Accessibility permission);
/// - five quick clicks in the top-left corner of any screen, where a tiny invisible window
///   floats above every break overlay.
///
/// The coordinator arms it while a break is on screen and disarms it afterwards.
@MainActor
final class EmergencyExitGuard {
    /// Shown in Settings and in the README.
    static let shortcutLabel = "⌃⌥⌘⌫"
    static let cornerClicks = 5

    private let onTrigger: () -> Void
    private var hotKey: EmergencyHotKey?
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

        let hotKey = EmergencyHotKey { [weak self] in
            Task { @MainActor in self?.fire() }
        }
        if !hotKey.register() {
            Logger.breaks.error("Could not register the emergency shortcut; the corner and the key monitor still work")
        }
        self.hotKey = hotKey

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
        hotKey?.unregister()
        hotKey = nil
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

/// ⌃⌥⌘⌫ as a Carbon hot key. `RegisterEventHotKey` works for background apps and,
/// unlike a global `NSEvent` monitor, does not need the Accessibility permission.
private final class EmergencyHotKey {
    /// "MRMX": tells our hot key apart from any other one registered in the app.
    private static let signature: OSType = 0x4D52_4D58
    private static let identifier: UInt32 = 0xE5C

    private let onPress: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    init(onPress: @escaping () -> Void) {
        self.onPress = onPress
    }

    deinit {
        unregister()
    }

    /// Returns false when the shortcut could not be registered.
    func register() -> Bool {
        guard hotKeyRef == nil else { return true }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                let hotKey = Unmanaged<EmergencyHotKey>.fromOpaque(userData).takeUnretainedValue()
                return hotKey.handle(event)
            },
            1,
            &eventType,
            userData,
            &handlerRef
        )
        guard installStatus == noErr else {
            handlerRef = nil
            return false
        }

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: Self.identifier)
        let modifiers = UInt32(controlKey | optionKey | cmdKey)
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_Delete),
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard registerStatus == noErr else {
            hotKeyRef = nil
            unregister()
            return false
        }
        return true
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRef = nil
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
        handlerRef = nil
    }

    fileprivate func handle(_ event: EventRef) -> OSStatus {
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        // Someone else's hot key: let the next handler have it.
        guard status == noErr, hotKeyID.signature == Self.signature, hotKeyID.id == Self.identifier else {
            return OSStatus(eventNotHandledErr)
        }
        onPress()
        return noErr
    }
}
