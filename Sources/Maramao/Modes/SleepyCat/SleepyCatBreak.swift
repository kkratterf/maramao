import AppKit
import SwiftUI
import MaramaoCore

/// "Non svegliare il gatto": a big photo of a sleeping cat over a blurred desktop, on every
/// screen. Moving the mouse, scrolling or typing wakes it up: the same break's angry cat
/// glares, and a passive-aggressive line shows up under it, a new one at every wake-up.
/// Leave everything alone for a few seconds and it falls asleep again.
///
/// Each break picks one sleeping cat and one angry cat and keeps them for the whole break;
/// the next break picks another pair.
///
/// Input is observed with local and global `NSEvent` monitors. Global key events need
/// Accessibility; without it they are silently missing and mouse input is enough.
/// Mouse movement is also polled, so the cat notices it even when no monitor fires.
@MainActor
final class SleepyCatBreak: BreakMode {
    private var windows: [OverlayWindow] = []
    private var model: SleepyCatModel?
    private var context: BreakContext?
    private var monitors: [Any] = []
    private var tickTimer: Timer?

    private var hasBegun = false
    private var hasEnded = false

    private var startDate = Date()
    private var lastInput = Date.distantPast
    private var lastPhotoDate = Date.distantPast
    private var anchor: NSPoint = .zero
    private var wakeUps = 0
    private var lines = ShuffleBag(count: 0)

    /// Input in the first seconds is ignored: the user is still letting go of the mouse.
    private let gracePeriod: TimeInterval = 1.5
    /// Mouse movement below this distance (points) is jitter.
    private let jitterThreshold: CGFloat = 3
    /// Seconds without input before the cat goes back to sleep.
    private let quietBeforeSleep: TimeInterval = 2.5
    /// Still fiddling while the cat glares: another remark after this long.
    private let photoInterval: TimeInterval = 2.5

    func begin(context: BreakContext) {
        guard !hasBegun, !hasEnded else { return }
        hasBegun = true
        self.context = context

        let model = SleepyCatModel(
            sleepingPhoto: CatPhotos.shared.next(.sleeping),
            angryPhoto: CatPhotos.shared.next(.angry),
            line: SleepyCatLines.asleep
        )
        self.model = model
        lines = ShuffleBag(count: angryLines().count)

        startDate = Date()
        anchor = NSEvent.mouseLocation

        let screens = BreakScreens.current()
        let mainScreen = BreakScreens.primary(in: screens)
        windows = screens.map { screen in
            let window = OverlayWindow(screen: screen)
            window.acceptsMouseMovedEvents = true
            let isMain = screen == mainScreen
            window.host(SleepyCatScene(model: model, context: context, isMain: isMain))
            window.alphaValue = 0
            window.show()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = min(0.8, context.duration / 20)
                window.animator().alphaValue = 1
            }
            return window
        }

        installMonitors()

        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            let owner = self
            Task { @MainActor in owner?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer
    }

    func end() {
        guard !hasEnded else { return }
        hasEnded = true
        removeMonitorsAndTimers()

        let closing = windows
        windows = []
        guard !closing.isEmpty else { return }
        // Fade out. Everything is closed within ~1 s.
        // The task captures self strongly to stay alive after the coordinator lets go.
        Task { @MainActor in
            for window in closing {
                window.fadeOutAndClose(duration: 0.6)
            }
            self.model = nil
            self.context = nil
        }
    }

    // MARK: - Input

    private func installMonitors() {
        // Clicks on our own windows are not counted: they may be on the HUD skip button.
        let localMask: NSEvent.EventTypeMask = [.mouseMoved, .scrollWheel, .keyDown]
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: localMask, handler: { [weak self] event in
            let owner = self
            if let input = sleepyInput(from: event) {
                Task { @MainActor in owner?.handle(input) }
            }
            return event
        }) {
            monitors.append(monitor)
        }

        let globalMask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDown, .rightMouseDown, .scrollWheel, .keyDown]
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: globalMask, handler: { [weak self] event in
            let owner = self
            if let input = sleepyInput(from: event) {
                Task { @MainActor in owner?.handle(input) }
            }
        }) {
            monitors.append(monitor)
        }
    }

    private func removeMonitorsAndTimers() {
        for monitor in monitors {
            NSEvent.removeMonitor(monitor)
        }
        monitors = []
        tickTimer?.invalidate()
        tickTimer = nil
    }

    private var isInGracePeriod: Bool {
        Date().timeIntervalSince(startDate) < gracePeriod
    }

    private func handle(_ input: SleepyInput) {
        guard !hasEnded, !isInGracePeriod else { return }
        switch input {
        case .move:
            checkMouseMovement()
        case .scroll(let amount):
            if amount > 1 { disturb() }
        case .key, .click:
            disturb()
        }
    }

    private func checkMouseMovement() {
        let location = NSEvent.mouseLocation
        let dx = location.x - anchor.x
        let dy = location.y - anchor.y
        guard (dx * dx + dy * dy).squareRoot() >= jitterThreshold else { return }
        anchor = location
        disturb()
    }

    private func disturb() {
        guard let model, !hasEnded else { return }
        let now = Date()
        lastInput = now
        switch model.phase {
        case .asleep:
            wakeUps += 1
            // The cat hisses or grumbles, every time it is woken up.
            CatSounds.shared.angry()
            say(nextAngryLine(), awake: true)
            lastPhotoDate = now
        case .awake:
            // Still fiddling while the cat glares: another remark, not too often.
            if now.timeIntervalSince(lastPhotoDate) > photoInterval {
                say(nextAngryLine(), awake: true)
                lastPhotoDate = now
            }
        }
    }

    private func say(_ line: String, awake: Bool) {
        guard let model else { return }
        if awake {
            model.wake(saying: line)
        } else {
            model.fallAsleep(saying: line)
        }
        BreakAccessibility.announce(line)
    }

    private func angryLines() -> [String] {
        let minutes = Int(((context?.duration ?? 300) / 60).rounded())
        return SleepyCatLines.angry(breakMinutes: minutes, wakeUps: wakeUps)
    }

    private func nextAngryLine() -> String {
        let all = angryLines()
        guard let index = lines.next(), index < all.count else { return all.first ?? "" }
        return all[index]
    }

    // MARK: - Clock

    private func tick() {
        guard !hasEnded, let model else { return }
        if isInGracePeriod {
            // Follow the pointer until the grace period is over, so letting go of the mouse is free.
            anchor = NSEvent.mouseLocation
        } else {
            checkMouseMovement()
        }
        if model.phase == .awake, Date().timeIntervalSince(lastInput) >= quietBeforeSleep {
            say(SleepyCatLines.asleep, awake: false)
        }
    }
}

/// The kinds of input that can wake the cat.
private enum SleepyInput {
    case move
    case scroll(Double)
    case key
    case click
}

/// Reads an event into a plain value. Not actor-isolated: monitors may call it from any context.
private func sleepyInput(from event: NSEvent) -> SleepyInput? {
    switch event.type {
    case .mouseMoved:
        return .move
    case .scrollWheel:
        return .scroll(abs(Double(event.scrollingDeltaX)) + abs(Double(event.scrollingDeltaY)))
    case .keyDown:
        return .key
    case .leftMouseDown, .rightMouseDown:
        return .click
    default:
        return nil
    }
}
