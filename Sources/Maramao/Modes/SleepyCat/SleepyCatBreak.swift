import AppKit
import SwiftUI

/// "Non svegliare il gatto": a cat sleeps in a cozy night scene on every screen.
/// Moving the mouse, scrolling or typing wakes it up, and it is not pleased about it.
/// The cat tracks how much of the break it managed to sleep.
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
    private var lastTick = Date()
    private var lastInput = Date.distantPast
    private var lastLineDate = Date.distantPast
    private var lastWakeDate = Date.distantPast
    private var lastDecayDate = Date.distantPast
    private var anchor: NSPoint = .zero

    private var asleepSeconds: TimeInterval = 0
    private var totalSeconds: TimeInterval = 0

    /// Input in the first seconds is ignored: the user is still letting go of the mouse.
    private let gracePeriod: TimeInterval = 2
    /// Mouse movement below this distance (points) is jitter.
    private let jitterThreshold: CGFloat = 6
    /// Seconds without input before the cat goes back to sleep.
    private let quietBeforeSleep: TimeInterval = 4
    private let startledDuration: TimeInterval = 0.45
    private let drowsyDuration: TimeInterval = 1.1

    func begin(context: BreakContext) {
        guard !hasBegun, !hasEnded else { return }
        hasBegun = true
        self.context = context

        let palettes: [CatPalette] = [.orange, .gray, .cream]
        let model = SleepyCatModel(palette: palettes.randomElement() ?? .orange)
        self.model = model

        let now = Date()
        startDate = now
        lastTick = now
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

        if let model {
            let percent = currentPercent()
            model.sleepPercent = percent
            model.resultLine = SleepyCatLines.result(percent: percent)
            model.line = ""
            model.setPhase(.stretching)
        }

        let closing = windows
        windows = []
        guard !closing.isEmpty else { return }
        // A short stretch, then fade out. Everything is closed within ~2 s.
        // The task captures self strongly to stay alive after the coordinator lets go.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_100_000_000)
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
        case .asleep, .drowsy:
            model.annoyance = min(model.annoyance + 1, 6)
            model.line = SleepyCatLines.pick(annoyance: model.annoyance, avoiding: model.line)
            model.setPhase(.startled)
            lastLineDate = now
            lastWakeDate = now
        case .startled, .awake:
            // Still fiddling while the cat glares: it gets angrier, one line at a time.
            if now.timeIntervalSince(lastLineDate) > 2.8 {
                model.annoyance = min(model.annoyance + 1, 6)
                model.line = SleepyCatLines.pick(annoyance: model.annoyance, avoiding: model.line)
                lastLineDate = now
            }
        case .stretching:
            break
        }
    }

    // MARK: - Clock

    private func tick() {
        guard !hasEnded, let model else { return }
        let now = Date()
        let dt = min(max(now.timeIntervalSince(lastTick), 0), 0.5)
        lastTick = now

        totalSeconds += dt
        if model.phase == .asleep {
            asleepSeconds += dt
        }
        let percent = currentPercent()
        if percent != model.sleepPercent {
            model.sleepPercent = percent
        }

        if isInGracePeriod {
            // Follow the pointer until the grace period is over, so letting go of the mouse is free.
            anchor = NSEvent.mouseLocation
        } else {
            checkMouseMovement()
        }

        let inPhase = now.timeIntervalSince(model.phaseStart)
        switch model.phase {
        case .startled:
            if inPhase >= startledDuration { model.setPhase(.awake) }
        case .awake:
            if now.timeIntervalSince(lastInput) >= quietBeforeSleep {
                model.line = ""
                model.setPhase(.drowsy)
            }
        case .drowsy:
            if inPhase >= drowsyDuration { model.setPhase(.asleep) }
        case .asleep:
            // A long, quiet nap slowly calms the cat down again.
            if model.annoyance > 0,
               now.timeIntervalSince(lastWakeDate) > 20,
               now.timeIntervalSince(lastDecayDate) > 20 {
                model.annoyance -= 1
                lastDecayDate = now
            }
        case .stretching:
            break
        }

        if let context, model.resultLine == nil, context.remaining <= 3 {
            model.resultLine = SleepyCatLines.result(percent: percent)
        }
    }

    private func currentPercent() -> Int {
        guard totalSeconds > 0.5 else { return 100 }
        return Int((asleepSeconds / totalSeconds * 100).rounded())
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
