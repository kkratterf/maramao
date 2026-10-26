import AppKit
import Carbon.HIToolbox

/// A global keyboard shortcut: a virtual key code (`kVK_*`) plus Carbon
/// modifier flags (`cmdKey`, `optionKey`, `controlKey`, `shiftKey`).
struct HotKeyCombo: Equatable {
    var keyCode: UInt32
    var modifiers: UInt32

    /// ⌃⌥⌘ together: rarely used by other apps, so a safe base for defaults.
    static let controlOptionCommand = UInt32(controlKey | optionKey | cmdKey)

    init(keyCode: Int, modifiers: UInt32) {
        self.keyCode = UInt32(keyCode)
        self.modifiers = modifiers
    }

    /// Human readable form in the macOS order, e.g. "⌃⌥⌘P".
    var displayString: String {
        var text = ""
        if modifiers & UInt32(controlKey) != 0 { text += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { text += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { text += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { text += "⌘" }
        return text + HotKeyCombo.keyName(Int(keyCode))
    }

    private static func keyName(_ keyCode: Int) -> String {
        let letters: [Int: String] = [
            kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D",
            kVK_ANSI_E: "E", kVK_ANSI_F: "F", kVK_ANSI_G: "G", kVK_ANSI_H: "H",
            kVK_ANSI_I: "I", kVK_ANSI_J: "J", kVK_ANSI_K: "K", kVK_ANSI_L: "L",
            kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O", kVK_ANSI_P: "P",
            kVK_ANSI_Q: "Q", kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T",
            kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X",
            kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z",
            kVK_Delete: "⌫", kVK_ForwardDelete: "⌦", kVK_Escape: "⎋",
            kVK_Return: "↩", kVK_Space: String(localized: "Spazio"), kVK_Tab: "⇥",
            kVK_F5: "F5",
        ]
        return letters[keyCode] ?? "#\(keyCode)"
    }
}

/// Registers system-wide hot keys with Carbon `RegisterEventHotKey`.
///
/// Unlike `NSEvent.addGlobalMonitorForEvents`, this needs no Accessibility
/// or Input Monitoring permission. Every registration has a string id, so
/// independent features can each own their shortcuts:
///
///     HotKeyCenter.shared.register(id: "startPause", combo: combo) { ... }
///     HotKeyCenter.shared.unregister(id: "startPause")
///
/// Registering an id again replaces its previous combo and action.
/// Use it from the main thread only; actions run on the main thread.
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    /// Four-char code that marks our hot keys ("MRMO"), so events for hot
    /// keys registered by other code are passed on untouched.
    fileprivate static let signature: OSType = 0x4D52_4D4F

    private struct Registration {
        let numericID: UInt32
        let ref: EventHotKeyRef
        let combo: HotKeyCombo
        let action: () -> Void
    }

    private var registrations: [String: Registration] = [:]
    private var nextNumericID: UInt32 = 1
    private var eventHandler: EventHandlerRef?

    private init() {}

    /// The combo currently registered for `id`, if any.
    func combo(for id: String) -> HotKeyCombo? {
        registrations[id]?.combo
    }

    /// Registers `combo` under `id`. Returns false when macOS refuses it,
    /// usually because another app already owns the same combination.
    @discardableResult
    func register(id: String, combo: HotKeyCombo, action: @escaping () -> Void) -> Bool {
        unregister(id: id)
        guard installEventHandlerIfNeeded() else { return false }

        let numericID = nextNumericID
        nextNumericID += 1
        let hotKeyID = EventHotKeyID(signature: HotKeyCenter.signature, id: numericID)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            combo.keyCode,
            combo.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else { return false }
        registrations[id] = Registration(numericID: numericID, ref: ref, combo: combo, action: action)
        return true
    }

    func unregister(id: String) {
        guard let registration = registrations.removeValue(forKey: id) else { return }
        UnregisterEventHotKey(registration.ref)
    }

    func unregisterAll() {
        for id in Array(registrations.keys) {
            unregister(id: id)
        }
    }

    /// Called by the Carbon handler. Returns true when the hot key is ours.
    fileprivate func handle(numericID: UInt32) -> Bool {
        guard let registration = registrations.values.first(where: { $0.numericID == numericID }) else {
            return false
        }
        registration.action()
        return true
    }

    private func installEventHandlerIfNeeded() -> Bool {
        if eventHandler != nil { return true }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        var handler: EventHandlerRef?
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyEventCallback,
            1,
            &eventType,
            nil,
            &handler
        )
        guard status == noErr, let handler else { return false }
        eventHandler = handler
        return true
    }
}

/// Carbon callback for `kEventHotKeyPressed`. A plain function, because a C
/// function pointer cannot capture context.
private func hotKeyEventCallback(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event else { return OSStatus(eventNotHandledErr) }
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
    guard status == noErr, hotKeyID.signature == HotKeyCenter.signature else {
        return OSStatus(eventNotHandledErr)
    }
    return HotKeyCenter.shared.handle(numericID: hotKeyID.id) ? noErr : OSStatus(eventNotHandledErr)
}
