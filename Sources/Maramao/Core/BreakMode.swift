import AppKit
import MaramaoCore

/// What a break mode knows about the break it is enforcing.
@MainActor
final class BreakContext {
    let duration: TimeInterval
    let endDate: Date
    let isLongBreak: Bool
    /// True when started from "Prova un concept" in the menu.
    let isPreview: Bool
    /// When the skip button may appear. `nil` means the break cannot be skipped.
    let skipUnlockDate: Date?
    /// Minutes of work a snooze gives ("Ancora 5 minuti"), or `nil` when this break cannot be
    /// snoozed (strict mode, preview, daily limit reached, snoozing off).
    let snoozeMinutes: Int?
    private let onSkip: () -> Void
    private let onSnooze: (() -> Void)?
    /// The cat's suggestion for this break, picked once and shared by every screen.
    lazy var tip: String = BreakTipStore.shared.nextTip(isLongBreak: isLongBreak)

    init(
        duration: TimeInterval,
        isLongBreak: Bool,
        isPreview: Bool,
        skipUnlockDate: Date?,
        snoozeMinutes: Int? = nil,
        onSkip: @escaping () -> Void,
        onSnooze: (() -> Void)? = nil
    ) {
        self.duration = duration
        self.endDate = Date().addingTimeInterval(duration)
        self.isLongBreak = isLongBreak
        self.isPreview = isPreview
        self.skipUnlockDate = skipUnlockDate
        self.snoozeMinutes = onSnooze == nil ? nil : snoozeMinutes
        self.onSkip = onSkip
        self.onSnooze = onSnooze
    }

    var remaining: TimeInterval { max(0, endDate.timeIntervalSinceNow) }
    /// 0 at the start of the break, 1 at the end.
    var progress: Double { duration > 0 ? min(1, 1 - remaining / duration) : 1 }
    var canSkipNow: Bool {
        guard let skipUnlockDate else { return false }
        return Date() >= skipUnlockDate
    }

    /// Asks to end the break early. Ignored until `canSkipNow` is true.
    /// The coordinator then calls `end()` on the mode.
    func requestSkip() {
        guard canSkipNow else { return }
        onSkip()
    }

    /// True when the HUD may offer "Ancora N minuti".
    var canSnooze: Bool { snoozeMinutes != nil }

    /// Asks to put the break off for `snoozeMinutes` of work. Ignored when `canSnooze` is false.
    /// The coordinator then calls `end()` on the mode, and the break comes back later.
    func requestSnooze() {
        guard canSnooze, let onSnooze else { return }
        onSnooze()
    }
}

/// A way of enforcing a break with cats.
///
/// Contract:
/// - `begin(context:)` is called once, on the main thread, when the break starts. Put your windows on screen.
/// - `end()` is called once when the break is over (timer finished or skip). Play a short exit
///   animation if you like (≤ 3 s), then close every window you opened. `end()` may arrive while the
///   entrance animation is still running, so it must be safe at any time.
/// - The coordinator drops its reference right after `end()`: keep yourself alive during the exit
///   animation by capturing `self` strongly in its completion handler.
/// - Never call `NSApp.terminate`, never steal focus permanently, never require permissions to work.
@MainActor
protocol BreakMode: AnyObject {
    func begin(context: BreakContext)
    func end()
}
