import AppKit
import MaramaoCore

/// Accessibility state shared by every break mode: Reduce Motion (system setting plus the
/// in-app override), VoiceOver announcements and the keyboard path to skip.
@MainActor
enum BreakAccessibility {
    /// Frozen when a break starts, so a mode never switches variant halfway through.
    private static var frozenReduceMotion: Bool?

    /// True when break modes should play their calm variant: fades instead of walking,
    /// falling, bouncing and drifting.
    static var reduceMotion: Bool {
        frozenReduceMotion ?? currentReduceMotion
    }

    /// The live value: System Settings → Accessibility → Display, unless overridden in Maramao.
    static var currentReduceMotion: Bool {
        let system = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        return AppSettings.shared.motionPreference.reducesMotion(systemReduceMotion: system)
    }

    static var isVoiceOverOn: Bool {
        NSWorkspace.shared.isVoiceOverEnabled
    }

    static func beginBreak() {
        frozenReduceMotion = currentReduceMotion
    }

    static func endBreak() {
        frozenReduceMotion = nil
    }

    /// Asks VoiceOver (if running) to read `text` out loud.
    static func announce(_ text: String) {
        guard !text.isEmpty else { return }
        let info: [NSAccessibility.NotificationUserInfoKey: Any] = [
            .announcement: text,
            .priority: NSAccessibilityPriorityLevel.high.rawValue,
        ]
        NSAccessibility.post(element: NSApplication.shared, notification: .announcementRequested, userInfo: info)
    }

    /// The global skip shortcut ("⌃⌥⌘S") when it is on and registered: the keyboard path
    /// to the skip button, since break overlays never take the keyboard focus.
    static var skipShortcutLabel: String? {
        let shortcuts = GlobalShortcuts.shared
        guard shortcuts.enabled.contains(.skip), !shortcuts.failed.contains(.skip) else { return nil }
        return GlobalShortcut.skip.combo.displayString
    }

    /// The global "Rimanda" shortcut ("⌃⌥⌘R") when it is on and registered.
    static var snoozeShortcutLabel: String? {
        let shortcuts = GlobalShortcuts.shared
        guard shortcuts.enabled.contains(.snooze), !shortcuts.failed.contains(.snooze) else { return nil }
        return GlobalShortcut.snooze.combo.displayString
    }
}

/// Speaks the break to VoiceOver: "Pausa: 5 minuti" when it starts, the time left once a
/// minute (then at 30 and 10 seconds), and "Pausa finita" at the end.
@MainActor
final class BreakAnnouncer {
    private var timer: Timer?
    private var lastRemaining: TimeInterval = 0
    private weak var context: BreakContext?

    func start(context: BreakContext, modeTitle: String) {
        stop()
        self.context = context
        lastRemaining = context.remaining
        // A moment after the overlays are up, so VoiceOver does not cut the sentence short.
        let text = BreakSpeech.breakStarted(duration: context.duration, modeTitle: modeTitle)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            BreakAccessibility.announce(text)
        }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.check() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        context = nil
    }

    private func check() {
        guard let context else {
            stop()
            return
        }
        let remaining = context.remaining
        let previous = lastRemaining
        lastRemaining = remaining
        guard BreakAccessibility.isVoiceOverOn else { return }
        if let mark = BreakSpeech.milestone(previous: previous, current: remaining) {
            BreakAccessibility.announce(BreakSpeech.remaining(seconds: mark))
        }
    }
}
