import AppKit
import SwiftUI

/// "Il gatto sulla finestra": a cat walks in from the edge of the screen, jumps onto the window
/// you are working in, curls up on it and blocks it until the break is over. Switch to another
/// window and the cat follows you there.
@MainActor
final class WalkingCatBreak: BreakMode {
    // MARK: - Choreography types

    private enum Pace {
        case stroll
        case run
        case timed(TimeInterval)
    }

    private enum Move {
        case walk(to: CGPoint, pace: Pace)
        case jump(to: CGPoint, duration: TimeInterval, height: CGFloat)
        case hold(CatPose, duration: TimeInterval)
        case teleport(to: CGPoint)
    }

    private struct Step {
        var move: Move
        /// Width the cat reaches at the end of the step (nil keeps the current one).
        var width: CGFloat?
        var completion: (() -> Void)?

        init(_ move: Move, width: CGFloat? = nil, completion: (() -> Void)? = nil) {
            self.move = move
            self.width = width
            self.completion = completion
        }
    }

    private struct RunningStep {
        let step: Step
        let start: TimeInterval
        let duration: TimeInterval
        let from: CGPoint
        let fromWidth: CGFloat
        let fromPhase: Double
    }

    private struct Delayed {
        let at: TimeInterval
        let action: () -> Void
    }

    /// Where things go for a given target window.
    private struct Layout {
        let screen: NSRect
        let visible: NSRect
        /// The target window clipped to the visible part of its screen.
        let area: NSRect
        let walkWidth: CGFloat
        let sleepWidth: CGFloat
        let groundY: CGFloat
        let ledgeY: CGFloat
        let sleepPoint: CGPoint
        let hudFrame: NSRect
        /// False for the fallback area, where there is no title bar to jump on.
        let hasWindow: Bool
    }

    private static let blockerLevel = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue - 1)
    private static let catLevel = NSWindow.Level.screenSaver
    private static let hudLevel = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
    private static let hudSize = NSSize(width: 400, height: 90)
    private static let lines = [
        "Questa finestra adesso è mia.",
        "Riposati, umano.",
        "Mrrr.",
        "Niente lavoro, solo coccole.",
        "Fai due passi, io resto qui.",
    ]

    // MARK: - State

    private var context: BreakContext?
    private let model = WalkingCatModel(palette: CatPalette.random())
    private var cat = WalkingCatSnapshot()
    private var stepPhase: Double = 0

    private var stageWindows: [OverlayWindow] = []
    private var hitWindow: OverlayWindow?
    private var blockerWindow: OverlayWindow?
    private var hudWindow: OverlayWindow?

    private var tickRelay: WalkingCatRelay?
    private var ticker: Timer?
    private var activationRelay: WalkingCatRelay?

    private var target = WalkingCatTarget(windowNumber: nil, frame: .zero)
    private var queue: [Step] = []
    private var running: RunningStep?
    private var delayed: [Delayed] = []

    private let startUptime = ProcessInfo.processInfo.systemUptime
    private var nextPollAt: TimeInterval = 1
    private var nextBubbleAt: TimeInterval = .greatestFiniteMagnitude
    private var bubbleStart: TimeInterval = 0
    private var bubbleEnd: TimeInterval = 0
    private var lastLine: String?
    private var nextHeartID = 0
    private var frameCount = 0

    private var settled = false
    private var began = false
    private var ended = false
    private var finished = false

    /// 1 for a real break, smaller for the 30 s preview: shortens the slow parts.
    private var timeScale: Double = 1
    private var holdScale: Double { max(0.45, timeScale) }

    private lazy var purrSound: NSSound? = NSSound(named: NSSound.Name("Purr"))

    private var now: TimeInterval { ProcessInfo.processInfo.systemUptime - startUptime }

    // MARK: - BreakMode

    func begin(context: BreakContext) {
        guard !began, !ended else { return }
        began = true
        self.context = context
        timeScale = min(1, max(0.2, context.duration / 90))

        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }

        target = WalkingCatWindowFinder.frontmostWindow() ?? WalkingCatWindowFinder.fallbackTarget()
        let layout = makeLayout(for: target)

        for screen in screens {
            let window = OverlayWindow(screen: screen, level: Self.catLevel, clickThrough: true)
            window.host(WalkingCatStageView(model: model, screenFrame: screen.frame))
            window.show()
            stageWindows.append(window)
        }

        let blocker = OverlayWindow(frame: target.frame, level: Self.blockerLevel, clickThrough: false)
        blocker.host(WalkingCatBlockerView())
        blocker.alphaValue = 0
        blockerWindow = blocker
        if target.windowNumber != nil {
            blocker.show()
            fade(blocker, to: 1, duration: 0.5)
        }

        let hit = OverlayWindow(frame: NSRect(x: 0, y: 0, width: 10, height: 10), level: Self.catLevel, clickThrough: false)
        let hitView = WalkingCatHitView(frame: NSRect(x: 0, y: 0, width: 10, height: 10))
        hitView.autoresizingMask = [.width, .height]
        hitView.onClick = { [weak self] in self?.catTapped() }
        hit.contentView = hitView
        hitWindow = hit

        let hud = OverlayWindow(frame: layout.hudFrame, level: Self.hudLevel, clickThrough: false)
        let hudView = BreakHUD(context: context, message: "Il gatto ha preso la tua finestra.")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        let hosting = WalkingCatFirstMouseHostingView(rootView: hudView)
        hosting.frame = NSRect(origin: .zero, size: layout.hudFrame.size)
        hosting.autoresizingMask = [.width, .height]
        hud.contentView = hosting
        hudWindow = hud
        hud.alphaValue = 0
        hud.show()
        fade(hud, to: 1, duration: 0.4)

        planEntrance(layout)
        updateDerivedState(at: now)
        model.snapshot = cat
        updateHitWindow()
        hit.show()

        // Strong capture on purpose: the timer keeps the mode alive through the exit
        // animation after the coordinator lets go. finish() breaks the cycle.
        let relay = WalkingCatRelay { _ in self.tick() }
        tickRelay = relay
        let timer = Timer(timeInterval: 1.0 / 30.0, target: relay, selector: #selector(WalkingCatRelay.fire(_:)), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer

        let activation = WalkingCatRelay { [weak self] sender in self?.appActivated(sender) }
        activationRelay = activation
        NSWorkspace.shared.notificationCenter.addObserver(
            activation,
            selector: #selector(WalkingCatRelay.fire(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    func end() {
        guard !ended else { return }
        ended = true
        stopObserving()

        guard began, ticker != nil else {
            finish()
            return
        }

        // Give the window back right away; the cat takes its time to leave.
        if let blocker = blockerWindow {
            blocker.ignoresMouseEvents = true
            fade(blocker, to: 0, duration: 0.35)
        }
        if let hud = hudWindow {
            hud.ignoresMouseEvents = true
            fade(hud, to: 0, duration: 0.3)
        }
        hitWindow?.orderOut(nil)

        queue.removeAll()
        running = nil
        settled = false
        cat.bubble = nil

        let screen = WalkingCatWindowFinder.screen(containing: cat.position)?.frame ?? cat.frameRect
        var steps: [Step] = []
        if cat.pose == .sleeping || cat.pose == .sitting {
            steps.append(Step(.hold(.stretching, duration: 0.8)))
        }
        let exitWidth = max(130, cat.width * 0.75)
        let goLeft = cat.position.x - screen.minX < screen.maxX - cat.position.x
        let exitX = goLeft ? screen.minX - exitWidth * 0.8 : screen.maxX + exitWidth * 0.8
        steps.append(Step(
            .walk(to: CGPoint(x: exitX, y: cat.position.y), pace: .timed(1.5)),
            width: exitWidth,
            completion: { [weak self] in self?.finish() }
        ))
        queue = steps
        // Hard deadline: everything is gone within 3 seconds whatever happens.
        after(2.7) { [weak self] in self?.finish() }
    }

    // MARK: - Lifecycle

    private func stopObserving() {
        if let activation = activationRelay {
            NSWorkspace.shared.notificationCenter.removeObserver(activation)
        }
        activationRelay = nil
    }

    /// Closes every window and stops the clock. Safe to call more than once.
    private func finish() {
        guard !finished else { return }
        finished = true
        stopObserving()
        ticker?.invalidate()
        ticker = nil
        // finish() may run inside the timer's own callback: let the relay go on the next turn.
        if let relay = tickRelay {
            Task { @MainActor in withExtendedLifetime(relay) {} }
        }
        tickRelay = nil
        queue.removeAll()
        running = nil
        delayed.removeAll()

        hitWindow?.orderOut(nil)
        hitWindow?.close()
        hitWindow = nil
        for window in stageWindows {
            window.fadeOutAndClose(duration: 0.2)
        }
        stageWindows = []
        for window in [blockerWindow, hudWindow].compactMap({ $0 }) {
            window.orderOut(nil)
            window.close()
        }
        blockerWindow = nil
        hudWindow = nil
    }

    private func after(_ delay: TimeInterval, _ action: @escaping () -> Void) {
        delayed.append(Delayed(at: now + delay, action: action))
    }

    private func fade(_ window: NSWindow, to alpha: CGFloat, duration: TimeInterval) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = duration
            window.animator().alphaValue = alpha
        }
    }

    // MARK: - Frame loop

    private func tick() {
        guard !finished else { return }
        let time = now

        if !delayed.isEmpty {
            let due = delayed.filter { $0.at <= time }
            if !due.isEmpty {
                delayed.removeAll { $0.at <= time }
                for item in due { item.action() }
                if finished { return }
            }
        }

        advanceMotion(at: time)
        updateDerivedState(at: time)

        if !ended {
            if time >= nextPollAt {
                nextPollAt = time + 1
                checkTarget()
            }
            if settled, cat.bubble == nil, time >= nextBubbleAt {
                sayRandomLine()
            }
            updateHitWindow()
        }

        // While the cat just sleeps, 15 fps is plenty for breathing and the "z"s.
        frameCount += 1
        let idle = settled && running == nil && queue.isEmpty && cat.hearts.isEmpty
            && (cat.bubble == nil || (cat.bubbleAge > 0.3 && cat.bubbleRemaining > 0.4))
        if idle && frameCount % 2 == 1 { return }
        model.snapshot = cat
    }

    private func advanceMotion(at time: TimeInterval) {
        var guardCount = 0
        while guardCount < 32 {
            guardCount += 1
            if running == nil {
                if queue.isEmpty { return }
                let step = queue.removeFirst()
                startStep(step, at: time)
            }
            guard let current = running else { return }
            let t = current.duration > 0 ? min(1, max(0, (time - current.start) / current.duration)) : 1
            apply(current, t: t)
            if t < 1 { return }
            running = nil
            current.step.completion?()
            if finished { return }
        }
    }

    private func startStep(_ step: Step, at time: TimeInterval) {
        var duration: TimeInterval = 0
        switch step.move {
        case .walk(let to, let pace):
            let distance = Double(hypot(to.x - cat.position.x, to.y - cat.position.y))
            switch pace {
            case .stroll:
                duration = min(distance / 170, 2.5 + 3.5 * timeScale)
            case .run:
                duration = min(distance / 380, 2.0)
            case .timed(let seconds):
                duration = seconds
            }
            if abs(to.x - cat.position.x) > 1 {
                cat.facingLeft = to.x < cat.position.x
            }
        case .jump(let to, let seconds, _):
            duration = seconds
            if abs(to.x - cat.position.x) > 6 {
                cat.facingLeft = to.x < cat.position.x
            }
        case .hold(let pose, let seconds):
            duration = seconds
            cat.pose = pose
        case .teleport(let to):
            cat.position = to
        }
        running = RunningStep(
            step: step,
            start: time,
            duration: duration,
            from: cat.position,
            fromWidth: cat.width,
            fromPhase: stepPhase
        )
    }

    private func apply(_ current: RunningStep, t: Double) {
        let tt = CGFloat(t)
        if let width = current.step.width {
            let eased = CGFloat(t * t * (3 - 2 * t))
            cat.width = current.fromWidth + (width - current.fromWidth) * eased
        }
        switch current.step.move {
        case .walk(let to, _):
            let x = current.from.x + (to.x - current.from.x) * tt
            let y = current.from.y + (to.y - current.from.y) * tt
            cat.position = CGPoint(x: x, y: y)
            let traveled = hypot(x - current.from.x, y - current.from.y)
            let stride = max(40, cat.width * 0.5)
            stepPhase = current.fromPhase + Double(traveled / stride) * 2 * Double.pi
            cat.pose = .walking(step: stepPhase)
        case .jump(let to, _, let height):
            let x = current.from.x + (to.x - current.from.x) * tt
            let y = current.from.y + (to.y - current.from.y) * tt + 4 * height * tt * (1 - tt)
            cat.position = CGPoint(x: x, y: y)
            cat.pose = .walking(step: Double.pi / 2)
        case .hold:
            break
        case .teleport:
            break
        }
    }

    /// Breathing, tail, blinking, bubble and hearts bookkeeping.
    private func updateDerivedState(at time: TimeInterval) {
        cat.time = time
        let blinkCycle = 4.6
        let blinking = time.truncatingRemainder(dividingBy: blinkCycle) > blinkCycle - 0.35
        switch cat.pose {
        case .sleeping:
            let breath = sin(time * 2 * Double.pi / 3.4)
            cat.breathY = CGFloat(1 + 0.035 * breath)
            cat.breathX = CGFloat(1 + 0.01 * breath)
            cat.tailWag = 0.5 * sin(time * 0.7)
            cat.eyesClosed = true
        case .sitting:
            let breath = sin(time * 2 * Double.pi / 2.6)
            cat.breathY = CGFloat(1 + 0.012 * breath)
            cat.breathX = 1
            cat.tailWag = 0.45 * sin(time * 1.4)
            cat.eyesClosed = blinking
        case .stretching:
            cat.breathY = 1
            cat.breathX = 1
            cat.tailWag = 0.3 * sin(time * 3)
            cat.eyesClosed = true
        case .walking:
            cat.breathY = 1
            cat.breathX = 1
            cat.tailWag = 0
            cat.eyesClosed = blinking
        }

        if cat.bubble != nil {
            cat.bubbleAge = time - bubbleStart
            cat.bubbleRemaining = bubbleEnd - time
            if cat.bubbleRemaining <= 0 {
                cat.bubble = nil
            }
        }
        if !cat.hearts.isEmpty {
            cat.hearts.removeAll { time - $0.birth > WalkingCatHeart.lifetime }
        }
    }

    private func updateHitWindow() {
        guard let hit = hitWindow else { return }
        let rect = cat.bodyRect.insetBy(dx: -8, dy: -8).integral
        if rect.width < 4 || rect.height < 4 { return }
        let current = hit.frame
        if abs(current.minX - rect.minX) > 0.5 || abs(current.minY - rect.minY) > 0.5
            || abs(current.width - rect.width) > 0.5 || abs(current.height - rect.height) > 0.5 {
            hit.setFrame(rect, display: false)
        }
    }

    // MARK: - Layout

    private func makeLayout(for target: WalkingCatTarget) -> Layout {
        let screenObject = WalkingCatWindowFinder.screen(for: target.frame)
        let screen = screenObject?.frame ?? target.frame
        let visible = screenObject?.visibleFrame ?? screen

        var area = target.frame.intersection(visible)
        if area.isNull || area.width < 120 || area.height < 90 {
            area = target.frame.intersection(screen)
        }
        if area.isNull || area.width < 120 || area.height < 90 {
            area = NSRect(x: visible.midX - visible.width / 4, y: visible.midY - visible.height / 4,
                          width: visible.width / 2, height: visible.height / 2)
        }

        let walkWidth = min(130, max(90, visible.width * 0.1))
        var sleepWidth = min(420, max(160, area.width * 0.4))
        sleepWidth = max(walkWidth, min(sleepWidth, visible.width * 0.5))
        let walkHeight = walkWidth * 0.8
        let sleepHeight = sleepWidth * 0.8

        let groundY = visible.minY + 2
        let ledgeY = max(groundY, min(area.maxY, screen.maxY - walkHeight))

        var sleepY = area.midY - sleepHeight * 0.22
        sleepY = min(sleepY, screen.maxY - sleepHeight * 0.6)
        sleepY = max(sleepY, visible.minY)
        let sleepPoint = CGPoint(x: area.midX, y: sleepY)

        let size = Self.hudSize
        let hudOrigin: CGPoint
        if area.width >= size.width + 20 && area.height >= 300 {
            hudOrigin = CGPoint(x: area.midX - size.width / 2, y: area.minY + 14)
        } else {
            hudOrigin = CGPoint(x: visible.midX - size.width / 2, y: visible.maxY - size.height - 8)
        }
        let hudFrame = NSRect(origin: hudOrigin, size: size)

        return Layout(
            screen: screen,
            visible: visible,
            area: area,
            walkWidth: walkWidth,
            sleepWidth: sleepWidth,
            groundY: groundY,
            ledgeY: ledgeY,
            sleepPoint: sleepPoint,
            hudFrame: hudFrame,
            hasWindow: target.windowNumber != nil
        )
    }

    private func clampX(_ x: CGFloat, in layout: Layout) -> CGFloat {
        let margin = layout.walkWidth * 0.6
        return min(max(x, layout.screen.minX + margin), layout.screen.maxX - margin)
    }

    // MARK: - Routes

    private func planEntrance(_ layout: Layout) {
        let walkWidth = layout.walkWidth
        let screen = layout.screen
        let fromLeft = (layout.area.midX - screen.minX) <= (screen.maxX - layout.area.midX)
        let startX = fromLeft ? screen.minX - walkWidth * 0.7 : screen.maxX + walkWidth * 0.7
        cat.position = CGPoint(x: startX, y: layout.groundY)
        cat.width = walkWidth
        cat.facingLeft = !fromLeft
        cat.pose = .walking(step: 0)

        let belowX = clampX(fromLeft ? layout.area.minX + walkWidth * 0.7 : layout.area.maxX - walkWidth * 0.7, in: layout)
        var steps: [Step] = []
        steps.append(Step(.walk(to: CGPoint(x: belowX, y: layout.groundY), pace: .stroll)))
        appendClimb(from: CGPoint(x: belowX, y: layout.groundY), layout: layout, pace: .stroll, into: &steps)
        appendSettle(layout: layout, sit: 3.0 * holdScale, announce: true, into: &steps)
        queue = steps
        running = nil
    }

    /// Follows the user to another window, starting from wherever the cat is now.
    private func planFollow(_ layout: Layout) {
        queue.removeAll()
        running = nil
        settled = false
        let walkWidth = layout.walkWidth
        var steps: [Step] = []

        // Wake up first if needed.
        if cat.pose == .sleeping || cat.width > walkWidth + 1 {
            steps.append(Step(.hold(.sitting, duration: 0.25)))
            steps.append(Step(.hold(.stretching, duration: 0.6), width: walkWidth))
            if cat.bubble == nil && Double.random(in: 0...1) < 0.5 {
                say("Mrrr?", duration: 1.8)
            }
        }

        let currentScreenObject = WalkingCatWindowFinder.screen(containing: cat.position)
        let currentScreen = currentScreenObject?.frame ?? layout.screen
        let currentGround = (currentScreenObject?.visibleFrame ?? layout.visible).minY + 2
        let sameScreen = currentScreen == layout.screen
        let onGround = abs(cat.position.y - currentGround) < 4

        if sameScreen && !onGround && layout.hasWindow {
            // Leap straight from window to window.
            let margin = walkWidth * 0.6
            let lo = layout.area.minX + margin
            let hi = max(lo, layout.area.maxX - margin)
            let entryX = min(max(cat.position.x, lo), hi)
            let dy = abs(layout.ledgeY - cat.position.y)
            let dx = abs(entryX - cat.position.x)
            let duration = 0.5 + min(0.4, Double(dy / 1500 + dx / 3000))
            steps.append(Step(.jump(to: CGPoint(x: entryX, y: layout.ledgeY), duration: duration, height: 60 + dy * 0.12)))
            steps.append(Step(.walk(to: CGPoint(x: layout.area.midX, y: layout.ledgeY), pace: .run)))
        } else {
            var x = cat.position.x
            if !onGround {
                steps.append(Step(.jump(to: CGPoint(x: x, y: currentGround), duration: 0.5, height: 30)))
            }
            if !sameScreen {
                let goRight = layout.screen.midX >= currentScreen.midX
                let exitX = goRight ? currentScreen.maxX + walkWidth * 0.7 : currentScreen.minX - walkWidth * 0.7
                steps.append(Step(.walk(to: CGPoint(x: exitX, y: currentGround), pace: .run)))
                let enterX = goRight ? layout.screen.minX - walkWidth * 0.7 : layout.screen.maxX + walkWidth * 0.7
                steps.append(Step(.teleport(to: CGPoint(x: enterX, y: layout.groundY))))
                x = enterX
            }
            let nearLeft = x < layout.area.midX
            let belowX = clampX(nearLeft ? layout.area.minX + walkWidth * 0.7 : layout.area.maxX - walkWidth * 0.7, in: layout)
            steps.append(Step(.walk(to: CGPoint(x: belowX, y: layout.groundY), pace: .run)))
            appendClimb(from: CGPoint(x: belowX, y: layout.groundY), layout: layout, pace: .run, into: &steps)
        }
        appendSettle(layout: layout, sit: 0.9, announce: false, into: &steps)
        queue = steps
    }

    /// From the ground below the window up to the middle of its title bar.
    private func appendClimb(from point: CGPoint, layout: Layout, pace: Pace, into steps: inout [Step]) {
        guard layout.hasWindow else {
            steps.append(Step(.walk(to: CGPoint(x: layout.area.midX, y: point.y), pace: pace)))
            return
        }
        let dy = layout.ledgeY - point.y
        if dy > 24 {
            steps.append(Step(.hold(.sitting, duration: 0.35 * holdScale)))
            let duration = 0.55 + min(0.45, Double(dy) / 1600)
            steps.append(Step(.jump(to: CGPoint(x: point.x, y: layout.ledgeY), duration: duration, height: 50 + dy * 0.15)))
        }
        steps.append(Step(.walk(to: CGPoint(x: layout.area.midX, y: layout.ledgeY), pace: pace)))
    }

    /// Sit on the title bar, hop onto the middle of the window, grow big and fall asleep.
    private func appendSettle(layout: Layout, sit: TimeInterval, announce: Bool, into steps: inout [Step]) {
        steps.append(Step(.hold(.sitting, duration: 0), completion: { [weak self] in
            if announce { self?.say("Questa finestra adesso è mia.", duration: max(2.2, sit + 0.6)) }
        }))
        steps.append(Step(.hold(.sitting, duration: sit)))
        steps.append(Step(.jump(to: layout.sleepPoint, duration: 0.65, height: 40), width: layout.sleepWidth))
        steps.append(Step(.hold(.sitting, duration: 0.45 * holdScale)))
        steps.append(Step(.hold(.sleeping, duration: 0), completion: { [weak self] in
            self?.didSettle()
        }))
    }

    private func didSettle() {
        settled = true
        let gap = Double.random(in: 14...30) * max(0.35, timeScale)
        nextBubbleAt = now + gap
    }

    // MARK: - Following the focused window

    private func appActivated(_ sender: Any?) {
        guard !ended else { return }
        if let note = sender as? Notification,
           let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
           app.processIdentifier == ProcessInfo.processInfo.processIdentifier {
            return
        }
        // The window list catches up a moment after the activation.
        after(0.3) { [weak self] in self?.checkTarget() }
    }

    private func checkTarget() {
        guard !ended, began else { return }
        guard let found = WalkingCatWindowFinder.frontmostWindow() else { return }
        if found.windowNumber == target.windowNumber {
            let old = target.frame
            let new = found.frame
            let delta = max(abs(new.midX - old.midX), abs(new.midY - old.midY),
                            abs(new.width - old.width), abs(new.height - old.height))
            if delta > 40 {
                retarget(found)
            } else if delta > 1 {
                nudge(found)
            }
        } else {
            retarget(found)
        }
    }

    private func retarget(_ newTarget: WalkingCatTarget) {
        target = newTarget
        let layout = makeLayout(for: newTarget)
        moveBlockerAndHUD(layout)
        planFollow(layout)
    }

    /// Small move of the same window: shift everything along without a new walk.
    private func nudge(_ newTarget: WalkingCatTarget) {
        let dx = newTarget.frame.midX - target.frame.midX
        let dy = newTarget.frame.midY - target.frame.midY
        target = newTarget
        let layout = makeLayout(for: newTarget)
        blockerWindow?.setFrame(newTarget.frame, display: true)
        hudWindow?.setFrame(layout.hudFrame, display: true)
        if running == nil && queue.isEmpty {
            cat.position = CGPoint(x: cat.position.x + dx, y: cat.position.y + dy)
        }
    }

    private func moveBlockerAndHUD(_ layout: Layout) {
        if let blocker = blockerWindow {
            if target.windowNumber != nil {
                if blocker.alphaValue < 0.01 {
                    blocker.setFrame(target.frame, display: true)
                    blocker.show()
                } else {
                    NSAnimationContext.runAnimationGroup { ctx in
                        ctx.duration = 0.35
                        blocker.animator().setFrame(target.frame, display: true)
                    }
                }
                blocker.ignoresMouseEvents = false
                fade(blocker, to: 1, duration: 0.35)
            } else {
                blocker.ignoresMouseEvents = true
                fade(blocker, to: 0, duration: 0.35)
            }
        }
        if let hud = hudWindow {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.35
                hud.animator().setFrame(layout.hudFrame, display: true)
            }
        }
    }

    // MARK: - Cuddles and chatter

    private func catTapped() {
        guard !ended else { return }
        let body = cat.bodyRect
        let headX = cat.facingLeft ? body.minX + body.width * 0.25 : body.maxX - body.width * 0.25
        let time = now
        for index in 0..<3 {
            let heart = WalkingCatHeart(
                id: nextHeartID,
                origin: CGPoint(x: headX + CGFloat.random(in: -16...16), y: body.maxY - 6),
                birth: time + Double(index) * 0.12,
                drift: CGFloat.random(in: -24...24),
                size: CGFloat.random(in: 16...26)
            )
            nextHeartID += 1
            cat.hearts.append(heart)
        }
        if cat.hearts.count > 24 {
            cat.hearts.removeFirst(cat.hearts.count - 24)
        }
        purr()
        if settled && cat.bubble == nil && Double.random(in: 0...1) < 0.4 {
            say(["Mrrr.", "Prrr…", "Ancora coccole."].randomElement() ?? "Mrrr.", duration: 2.2)
        }
    }

    private func purr() {
        guard let sound = purrSound else { return }
        if sound.isPlaying { sound.stop() }
        sound.play()
    }

    private func say(_ text: String, duration: TimeInterval = 3.8) {
        let time = now
        cat.bubble = text
        cat.bubbleAge = 0
        cat.bubbleRemaining = duration
        bubbleStart = time
        bubbleEnd = time + duration
        lastLine = text
    }

    private func sayRandomLine() {
        let options = Self.lines.filter { $0 != lastLine }
        say(options.randomElement() ?? "Mrrr.")
        nextBubbleAt = now + Double.random(in: 18...35) * max(0.35, timeScale)
    }
}
