import AppKit
import MaramaoCore
import os

extension Logger {
    /// Break lifecycle: watchdog, emergency exit, stray windows.
    static let breaks = Logger(subsystem: "com.kkratterf.maramao", category: "breaks")
}

/// Creates the break mode for each break and tears it down when the break is over.
///
/// It also keeps the user safe from a broken break mode:
/// - an emergency exit (`EmergencyExitGuard`) is armed while any break is on screen;
/// - a watchdog closes every overlay by force when a break is still up 30 s after its end;
/// - a few seconds after each break, any overlay the mode forgot to close is swept away.
@MainActor
final class BreakCoordinator {
    /// Seconds a mode gets to play its exit animation before stray windows are swept.
    private static let sweepDelay: TimeInterval = 4
    private static let watchdogInterval: TimeInterval = 5

    private var current: BreakMode?
    private var currentContext: BreakContext?
    private(set) var currentModeID: BreakModeID?
    private var watchdog: Timer?
    private let announcer = BreakAnnouncer()
    /// Bumped on every start, so a late sweep never closes the windows of a newer break.
    private var generation = 0
    private lazy var emergencyExit = EmergencyExitGuard { [weak self] in
        self?.emergencyExitTriggered()
    }

    /// Called when the user takes the emergency exit. The owner should end the break
    /// (skip rules do not apply); the coordinator has already closed every overlay.
    var onEmergencyExit: ((BreakContext) -> Void)?
    /// Called when the watchdog had to close a break by force.
    var onWatchdogFired: ((BreakContext) -> Void)?

    var isActive: Bool { current != nil }

    func start(mode: BreakModeID, context: BreakContext) {
        end()
        generation += 1
        let resolved = mode.resolved()
        let breakMode = Self.make(resolved)
        current = breakMode
        currentContext = context
        currentModeID = resolved
        emergencyExit.arm()
        startWatchdog()
        BreakAccessibility.beginBreak()
        BreakScreens.beginBreak()
        breakMode.begin(context: context)
        announcer.start(context: context, modeTitle: resolved.title)
    }

    func end() {
        guard let breakMode = current else { return }
        current = nil
        currentContext = nil
        currentModeID = nil
        stopWatchdog()
        emergencyExit.disarm()
        breakMode.end()
        announcer.stop()
        BreakAccessibility.announce(BreakSpeech.breakEnded)
        BreakAccessibility.endBreak()
        BreakScreens.endBreak()
        scheduleSweep()
    }

    /// Ends the break and closes every overlay right away, without exit animations.
    func forceEnd() {
        end()
        let closed = OverlayWindow.closeAllBreakOverlays()
        if closed > 0 {
            Logger.breaks.notice("Force-closed \(closed, privacy: .public) break overlay(s)")
        }
    }

    // MARK: - Safety nets

    private func emergencyExitTriggered() {
        guard let context = currentContext else { return }
        Logger.breaks.notice("Emergency exit taken")
        forceEnd()
        onEmergencyExit?(context)
    }

    private func startWatchdog() {
        stopWatchdog()
        let timer = Timer(timeInterval: Self.watchdogInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkWatchdog() }
        }
        RunLoop.main.add(timer, forMode: .common)
        watchdog = timer
    }

    private func stopWatchdog() {
        watchdog?.invalidate()
        watchdog = nil
    }

    private func checkWatchdog() {
        guard let context = currentContext else {
            stopWatchdog()
            return
        }
        guard BreakWatchdog.isOverdue(now: Date(), endDate: context.endDate) else { return }
        Logger.breaks.error("Watchdog: break still on screen \(Int(-context.endDate.timeIntervalSinceNow), privacy: .public)s after its end, closing it by force")
        forceEnd()
        onWatchdogFired?(context)
    }

    /// After the exit animation, closes any break overlay the mode left behind.
    private func scheduleSweep() {
        let expected = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.sweepDelay) { [weak self] in
            Task { @MainActor in
                guard let self, self.generation == expected, !self.isActive else { return }
                let closed = OverlayWindow.closeAllBreakOverlays()
                if closed > 0 {
                    Logger.breaks.error("Swept \(closed, privacy: .public) overlay(s) left open after the break ended")
                }
            }
        }
    }

    private static func make(_ id: BreakModeID) -> BreakMode {
        switch id {
        case .walkingCat: return WalkingCatBreak()
        case .memeWall: return MemeWallBreak()
        case .sleepyCat: return SleepyCatBreak()
        case .catPile: return CatPileBreak()
        case .laserChase: return LaserChaseBreak()
        case .keyboardCat: return KeyboardCatBreak()
        case .birdWatching: return BirdWatchingBreak()
        case .random: return WalkingCatBreak()
        }
    }
}
