import AppKit
import SwiftUI

/// "Caccia al laser": every screen is dimmed and the mouse pointer becomes a glowing red laser
/// dot. A cat chases it around with a bit of steering physics: it runs, slows down near the dot,
/// wiggles its butt when the dot stops and pounces. Land on the dot and it counts as a catch.
/// Leave the mouse alone and the cat sits down to groom itself, waiting for the next round.
///
/// The real cursor is hidden while the break runs (Maramao is activated for that, and the
/// previously active app gets focus back at the end). Every `NSCursor.hide()` is balanced by
/// exactly one `NSCursor.unhide()` in `end()`, even mid-animation.
@MainActor
final class LaserChaseBreak: BreakMode {
    private enum State: Equatable {
        case chasing
        /// Crouched, butt wiggling, about to pounce.
        case wiggling
        case pouncing
        case celebrating
        case missed
        /// Just caught the dot: sitting on it until it moves again.
        case waiting
        /// The mouse has been idle for a while: sitting and licking a paw.
        case grooming
        /// The break is over.
        case proud
    }

    // MARK: - Tuning

    /// The dot must stay still this long before the cat pounces.
    private let stillBeforePounce: TimeInterval = 0.4
    private let wiggleDuration: TimeInterval = 0.6
    /// Seconds without mouse movement before the cat gives up and grooms.
    private let idleBeforeGrooming: TimeInterval = 5
    private let celebrateDuration: TimeInterval = 1.2
    private let missedDuration: TimeInterval = 0.5
    private let exitHold: TimeInterval = 1.7
    private let exitFade: TimeInterval = 0.5

    // MARK: - State

    private var context: BreakContext?
    private let model = LaserChaseModel(palette: CatPalette.random())
    private let status = LaserChaseStatus()
    private var cat = LaserChaseSnapshot()

    private var windows: [OverlayWindow] = []
    private var relay: LaserChaseRelay?
    private var ticker: Timer?
    private var monitor: Any?
    private var previousApp: NSRunningApplication?
    private var cursorHidden = false

    private var began = false
    private var ended = false
    private var finished = false

    private let startUptime = ProcessInfo.processInfo.systemUptime
    private var now: TimeInterval { ProcessInfo.processInfo.systemUptime - startUptime }
    private var lastTick: TimeInterval = 0

    private var state: State = .chasing
    private var stateStart: TimeInterval = 0
    private var vx: CGFloat = 0
    private var vy: CGFloat = 0
    private var stepPhase: Double = 0
    private var walking = true
    private var mouse: CGPoint = .zero
    private var lastMoveAt: TimeInterval = 0
    private var movedThisTick = false
    private var wiggleDot: CGPoint = .zero
    private var pounceFrom: CGPoint = .zero
    private var pounceTo: CGPoint = .zero
    private var pounceDuration: TimeInterval = 0.4
    private var pounceHeight: CGFloat = 0
    private var catchPoint: CGPoint = .zero
    private var catches = 0
    private var bubbleStart: TimeInterval = 0
    private var bubbleEnd: TimeInterval = 0
    private var nextHeartID = 0

    // MARK: - BreakMode

    func begin(context: BreakContext) {
        guard !began, !ended else { return }
        began = true
        self.context = context

        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }

        mouse = NSEvent.mouseLocation
        let home = Self.screen(containing: mouse) ?? screens[0]
        let width = min(230, max(150, home.frame.width * 0.13))
        cat.width = width
        // The cat runs in from the left edge of the screen with the pointer.
        cat.position = CGPoint(x: home.frame.minX - width * 0.3, y: home.frame.minY + home.frame.height * 0.18)
        cat.facingLeft = false
        cat.pose = .walking(step: 0)
        cat.dot = mouse
        cat.trail = [mouse]

        let mainScreen = NSScreen.main ?? screens[0]
        let fadeIn = min(0.6, context.duration / 40)
        for screen in screens {
            let window = OverlayWindow(screen: screen)
            window.acceptsMouseMovedEvents = true
            let scene = LaserChaseScene(
                model: model,
                status: status,
                context: context,
                screenFrame: screen.frame,
                isMain: screen == mainScreen
            )
            let hosting = LaserChaseHostingView(rootView: AnyView(scene))
            hosting.frame = NSRect(origin: .zero, size: screen.frame.size)
            hosting.autoresizingMask = [.width, .height]
            window.contentView = hosting
            window.alphaValue = 0
            window.show()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = fadeIn
                window.animator().alphaValue = 1
            }
            windows.append(window)
        }

        takeOverPointer()
        installMonitor()

        let time = now
        lastTick = time
        lastMoveAt = time
        enter(.chasing)
        say(LaserChaseLines.start.randomElement() ?? "Mrrr?", duration: 2.4)
        updateDerivedState(at: time)
        model.snapshot = cat
        syncStatus()

        let relay = LaserChaseRelay { [weak self] in self?.tick() }
        self.relay = relay
        let timer = Timer(timeInterval: 1.0 / 60.0, target: relay, selector: #selector(LaserChaseRelay.fire(_:)), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    func end() {
        guard !ended else { return }
        ended = true
        removeMonitor()
        // The real cursor comes back right away, whatever the cat is doing.
        releasePointer()

        guard began, ticker != nil, !windows.isEmpty else {
            finish()
            return
        }

        cat.dotVisible = false
        cat.trail = []
        vx = 0
        vy = 0
        enter(.proud)
        if let screen = Self.screen(containing: cat.position) {
            cat.facingLeft = cat.position.x > screen.frame.midX
        }
        say(LaserChaseLines.result(catches: catches), duration: exitHold + exitFade + 0.5)
        status.ending = true
        syncStatus()

        // The cat sits proudly for a moment, then everything fades. Closed within ~2.5 s.
        // The task captures self strongly to stay alive after the coordinator lets go.
        let hold = UInt64(exitHold * 1_000_000_000)
        let fade = exitFade
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: hold)
            let closing = self.windows
            self.windows = []
            for window in closing {
                window.fadeOutAndClose(duration: fade)
            }
            try? await Task.sleep(nanoseconds: UInt64((fade + 0.15) * 1_000_000_000))
            self.finish()
        }
    }

    // MARK: - Lifecycle

    /// Stops the clock and closes whatever is still open. Safe to call more than once.
    private func finish() {
        guard !finished else { return }
        finished = true
        removeMonitor()
        releasePointer()
        ticker?.invalidate()
        ticker = nil
        // finish() never runs inside the timer callback, but keep the relay one more turn anyway.
        if let relay {
            Task { @MainActor in withExtendedLifetime(relay) {} }
        }
        relay = nil
        for window in windows {
            window.orderOut(nil)
            window.close()
        }
        windows = []
        context = nil
    }

    /// Activates Maramao so the cursor can be hidden, remembering who had the focus.
    private func takeOverPointer() {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        if let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != ownPID {
            previousApp = front
        }
        NSApp.activate(ignoringOtherApps: true)
        if !cursorHidden {
            NSCursor.hide()
            cursorHidden = true
        }
    }

    /// Shows the cursor again (once) and gives the focus back to the previous app.
    private func releasePointer() {
        if cursorHidden {
            NSCursor.unhide()
            cursorHidden = false
        }
        if let app = previousApp {
            previousApp = nil
            // Only if the user did not switch app on their own in the meantime.
            if NSApp.isActive && !app.isTerminated {
                app.activate(options: [.activateIgnoringOtherApps])
            }
        }
    }

    private func installMonitor() {
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        monitor = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            let owner = self
            Task { @MainActor in owner?.pointerMoved() }
            return event
        })
    }

    private func removeMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    // MARK: - Input

    /// Reads the pointer. Called by the event monitor and polled every frame, since the
    /// monitor only sees events delivered to Maramao.
    private func pointerMoved() {
        guard !ended else { return }
        let location = NSEvent.mouseLocation
        if hypot(location.x - mouse.x, location.y - mouse.y) > 1.5 {
            lastMoveAt = now
            movedThisTick = true
        }
        mouse = location
    }

    // MARK: - Frame loop

    private func tick() {
        guard !finished else { return }
        let time = now
        let dt = CGFloat(min(max(time - lastTick, 0), 0.05))
        lastTick = time

        if !ended {
            pointerMoved()
            cat.dot = mouse
            cat.trail.append(mouse)
            if cat.trail.count > 10 {
                cat.trail.removeFirst(cat.trail.count - 10)
            }
        }

        step(at: time, dt: dt)
        movedThisTick = false
        updateDerivedState(at: time)
        model.snapshot = cat
        syncStatus()
    }

    private func enter(_ newState: State) {
        state = newState
        stateStart = now
    }

    private func step(at time: TimeInterval, dt: CGFloat) {
        let inState = time - stateStart
        let idleFor = time - lastMoveAt
        let w = cat.width

        switch state {
        case .chasing:
            if idleFor >= idleBeforeGrooming {
                enter(.grooming)
                return
            }
            steer(toward: chaseTarget(), dt: dt)
            if idleFor >= stillBeforePounce && pawDistance() < w * 1.7 {
                faceDot()
                wiggleDot = mouse
                enter(.wiggling)
            }
        case .wiggling:
            brake(dt)
            faceDot()
            if hypot(mouse.x - wiggleDot.x, mouse.y - wiggleDot.y) > w * 0.3 {
                enter(.chasing)
            } else if inState >= wiggleDuration {
                startPounce()
            }
        case .pouncing:
            let t = pounceDuration > 0 ? min(1, max(0, (time - stateStart) / pounceDuration)) : 1
            let tt = CGFloat(t)
            cat.position = CGPoint(
                x: pounceFrom.x + (pounceTo.x - pounceFrom.x) * tt,
                y: pounceFrom.y + (pounceTo.y - pounceFrom.y) * tt
            )
            cat.lift = 4 * pounceHeight * tt * (1 - tt)
            if t >= 1 {
                cat.lift = 0
                land()
            }
        case .celebrating:
            brake(dt)
            if inState >= celebrateDuration { enter(.waiting) }
        case .missed:
            brake(dt)
            if inState >= missedDuration { enter(.chasing) }
        case .waiting:
            brake(dt)
            faceDot()
            if hypot(mouse.x - catchPoint.x, mouse.y - catchPoint.y) > w * 0.45 {
                enter(.chasing)
            } else if idleFor >= idleBeforeGrooming {
                enter(.grooming)
            }
        case .grooming:
            brake(dt)
            if movedThisTick {
                say(LaserChaseLines.wakeUp.randomElement() ?? "Mrrr?!", duration: 1.4)
                enter(.chasing)
            }
        case .proud:
            brake(dt)
            if cat.lift > 0 {
                cat.lift = max(0, cat.lift - dt * 900)
            }
        }
    }

    // MARK: - Physics

    /// Where the cat's body should be so that its front paws land on the dot.
    private func chaseTarget() -> CGPoint {
        let dir: CGFloat = cat.facingLeft ? -1 : 1
        let raw = CGPoint(x: mouse.x - dir * cat.width * 0.27, y: mouse.y - cat.height * 0.08)
        return clampToScreen(raw, of: mouse)
    }

    private var pawPoint: CGPoint {
        let dir: CGFloat = cat.facingLeft ? -1 : 1
        return CGPoint(x: cat.position.x + dir * cat.width * 0.27, y: cat.position.y + cat.height * 0.08)
    }

    private func pawDistance() -> CGFloat {
        let paw = pawPoint
        return hypot(mouse.x - paw.x, mouse.y - paw.y)
    }

    /// Seek with arrival: accelerate towards the target, capped speed, slowing down close to it.
    private func steer(toward target: CGPoint, dt: CGFloat) {
        let w = cat.width
        let dx = target.x - cat.position.x
        let dy = target.y - cat.position.y
        let distance = hypot(dx, dy)
        let maxSpeed = w * 5.5
        let slowRadius = w * 1.4
        var desiredX: CGFloat = 0
        var desiredY: CGFloat = 0
        if distance > 0.5 {
            let speed = maxSpeed * min(1, distance / slowRadius)
            desiredX = dx / distance * speed
            desiredY = dy / distance * speed
        }
        var steerX = desiredX - vx
        var steerY = desiredY - vy
        let maxAccel = w * 16 * dt
        let steerLength = hypot(steerX, steerY)
        if steerLength > maxAccel && steerLength > 0 {
            steerX *= maxAccel / steerLength
            steerY *= maxAccel / steerLength
        }
        vx += steerX
        vy += steerY
        move(dt)

        let speed = hypot(vx, vy)
        if abs(vx) > w * 0.6 {
            cat.facingLeft = vx < 0
        } else if speed < w * 0.3 {
            faceDot()
        }
    }

    private func brake(_ dt: CGFloat) {
        let keep = CGFloat(pow(0.002, Double(dt)))
        vx *= keep
        vy *= keep
        if hypot(vx, vy) < 1 {
            vx = 0
            vy = 0
        }
        move(dt)
    }

    private func move(_ dt: CGFloat) {
        cat.position.x += vx * dt
        cat.position.y += vy * dt
        let stride = max(30, cat.width * 0.45)
        stepPhase += Double(hypot(vx, vy) * dt / stride) * 2 * Double.pi
    }

    /// Turns towards the dot, with a little dead zone so it does not flip back and forth.
    private func faceDot() {
        let margin = cat.width * 0.1
        if mouse.x < cat.position.x - margin {
            cat.facingLeft = true
        } else if mouse.x > cat.position.x + margin {
            cat.facingLeft = false
        }
    }

    private func startPounce() {
        let target = chaseTarget()
        pounceFrom = cat.position
        pounceTo = target
        let distance = hypot(target.x - pounceFrom.x, target.y - pounceFrom.y)
        pounceDuration = 0.34 + min(0.22, Double(distance) / 1800)
        pounceHeight = cat.height * 0.3 + distance * 0.25
        vx = 0
        vy = 0
        enter(.pouncing)
    }

    private func land() {
        if pawDistance() <= cat.width * 0.24 {
            catches += 1
            catchPoint = mouse
            spawnHearts()
            say(String(localized: "Preso! 🐾"), duration: 1.5)
            CatSounds.shared.chirp()
            enter(.celebrating)
        } else {
            if Double.random(in: 0...1) < 0.5 {
                say(LaserChaseLines.missed.randomElement() ?? "Mrr?", duration: 1.3)
            }
            enter(.missed)
        }
    }

    private func clampToScreen(_ point: CGPoint, of anchor: CGPoint) -> CGPoint {
        guard let frame = Self.screen(containing: anchor)?.frame else { return point }
        let w = cat.width
        let h = cat.height
        let minX = frame.minX + w * 0.45
        let maxX = max(minX, frame.maxX - w * 0.45)
        let minY = frame.minY + 2
        let maxY = max(minY, frame.maxY - h * 0.6)
        return CGPoint(x: min(max(point.x, minX), maxX), y: min(max(point.y, minY), maxY))
    }

    // MARK: - Looks

    private func updateDerivedState(at time: TimeInterval) {
        cat.time = time
        let inState = time - stateStart
        let w = cat.width
        let blinkCycle = 4.2
        let blinking = time.truncatingRemainder(dividingBy: blinkCycle) > blinkCycle - 0.3
        cat.jitter = 0
        cat.squashY = 1

        switch state {
        case .chasing:
            let speed = hypot(vx, vy)
            if walking && speed < w * 0.15 {
                walking = false
            } else if !walking && speed > w * 0.3 {
                walking = true
            }
            cat.pose = walking ? .walking(step: stepPhase) : .sitting
            cat.tailWag = walking ? 0 : 0.5 * sin(time * 5)
            cat.eyesClosed = blinking
        case .wiggling:
            // Crouched low, the butt shaking faster and faster.
            let p = min(1, inState / wiggleDuration)
            cat.pose = .walking(step: 0)
            cat.squashY = CGFloat(1 - 0.12 * min(1, p * 3))
            cat.jitter = CGFloat(sin(time * (40 + 30 * p))) * w * 0.014
            cat.tailWag = sin(time * 18) * 0.5
            cat.eyesClosed = false
        case .pouncing:
            cat.pose = .walking(step: Double.pi / 2)
            cat.squashY = 1.05
            cat.tailWag = 0.6
            cat.eyesClosed = false
        case .celebrating:
            walking = false
            cat.pose = .sitting
            let bounce = max(0, sin(inState * 9)) * max(0, 1 - inState / celebrateDuration)
            cat.squashY = CGFloat(1 + 0.05 * bounce)
            cat.tailWag = sin(time * 9) * 0.7
            cat.eyesClosed = inState < 0.5
        case .missed:
            walking = false
            cat.pose = .sitting
            cat.tailWag = sin(time * 14) * 0.4
            cat.eyesClosed = false
        case .waiting:
            walking = false
            cat.pose = .sitting
            cat.tailWag = sin(time * 2.5) * 0.4
            cat.eyesClosed = blinking
        case .grooming:
            walking = false
            cat.pose = .sitting
            // Eyes mostly closed while licking a paw, with a quick peek now and then.
            let groomCycle = 2.6
            let phase = inState.truncatingRemainder(dividingBy: groomCycle)
            cat.eyesClosed = !(phase > groomCycle - 0.35)
            cat.squashY = CGFloat(1 + 0.018 * sin(time * 9))
            cat.tailWag = sin(time * 1.1) * 0.3
        case .proud:
            walking = false
            cat.pose = .sitting
            cat.squashY = CGFloat(1 + 0.04 * min(1, inState / 0.4))
            cat.tailWag = sin(time * 1.6) * 0.45
            cat.eyesClosed = inState > 0.3 && inState < 1.2
        }

        if cat.bubble != nil {
            cat.bubbleAge = time - bubbleStart
            cat.bubbleRemaining = bubbleEnd - time
            if cat.bubbleRemaining <= 0 {
                cat.bubble = nil
            }
        }
        if !cat.hearts.isEmpty {
            cat.hearts.removeAll { time - $0.birth > LaserChaseHeart.lifetime }
        }
    }

    private func spawnHearts() {
        let time = now
        let paw = pawPoint
        for index in 0..<5 {
            let heart = LaserChaseHeart(
                id: nextHeartID,
                origin: CGPoint(x: paw.x + CGFloat.random(in: -30...30), y: paw.y + cat.height * CGFloat.random(in: 0.3...0.7)),
                birth: time + Double(index) * 0.1,
                drift: CGFloat.random(in: -30...30),
                size: CGFloat.random(in: 18...30)
            )
            nextHeartID += 1
            cat.hearts.append(heart)
        }
        if cat.hearts.count > 30 {
            cat.hearts.removeFirst(cat.hearts.count - 30)
        }
    }

    private func say(_ text: String, duration: TimeInterval) {
        let time = now
        cat.bubble = text
        cat.bubbleAge = 0
        cat.bubbleRemaining = duration
        bubbleStart = time
        bubbleEnd = time + duration
    }

    private func syncStatus() {
        let message: String
        switch state {
        case .chasing, .missed:
            message = String(localized: "Il gatto insegue il puntino. Tu riposa.")
        case .wiggling, .pouncing:
            message = String(localized: "Attenzione… sta per saltare!")
        case .celebrating, .waiting:
            message = String(localized: "Preso! Muovi il puntino per un'altra caccia.")
        case .grooming:
            message = String(localized: "Il gatto si lecca la zampa.")
        case .proud:
            message = String(localized: "Pausa finita. Il gatto è fiero di sé.")
        }
        if status.message != message { status.message = message }
        if status.catches != catches { status.catches = catches }
        let hint = state == .grooming
        if status.showHint != hint { status.showHint = hint }
    }

    // MARK: - Screens

    /// The screen containing `point`, or the closest one.
    private static func screen(containing point: CGPoint) -> NSScreen? {
        let screens = NSScreen.screens
        if let hit = screens.first(where: { $0.frame.contains(point) }) { return hit }
        var best: NSScreen?
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for screen in screens {
            let frame = screen.frame
            let dx = max(frame.minX - point.x, 0, point.x - frame.maxX)
            let dy = max(frame.minY - point.y, 0, point.y - frame.maxY)
            let distance = dx * dx + dy * dy
            if distance < bestDistance {
                bestDistance = distance
                best = screen
            }
        }
        return best ?? NSScreen.main
    }
}
