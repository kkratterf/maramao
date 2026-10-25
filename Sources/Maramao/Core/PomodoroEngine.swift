import AppKit
import Combine
import MaramaoCore

/// Drives the Pomodoro cycle with a real clock and hands breaks to the cats.
@MainActor
final class PomodoroEngine: ObservableObject {
    static let shared = PomodoroEngine()

    @Published private(set) var phase: PomodoroPhase = .idle
    @Published private(set) var remaining: TimeInterval = 0
    @Published private(set) var phaseDuration: TimeInterval = 0
    @Published private(set) var isPaused = false
    @Published private(set) var completedWorkSessions = 0
    /// Mode of the break on screen, when there is one (also during previews).
    @Published private(set) var activeBreakMode: BreakModeID?

    private let settings: AppSettings
    private let stats: StatsStore
    private let breaks = BreakCoordinator()
    private var cycle: PomodoroCycle
    private var endDate: Date?
    private var ticker: Timer?
    private var breakContext: BreakContext?
    private var previewTimer: Timer?
    private var breakWarning = BreakWarning()
    private let peekingCat = PeekingCatWarning()

    init(settings: AppSettings = .shared, stats: StatsStore? = nil) {
        self.settings = settings
        self.stats = stats ?? StatsStore.shared
        self.cycle = PomodoroCycle(config: settings.pomodoroConfig)
        self.remaining = settings.pomodoroConfig.work
        breaks.onEmergencyExit = { [weak self] context in
            self?.breakForceEnded(context, emergency: true)
        }
        breaks.onWatchdogFired = { [weak self] context in
            self?.breakForceEnded(context, emergency: false)
        }
    }

    var isRunning: Bool { phase != .idle && !isPaused }
    var progress: Double { phaseDuration > 0 ? min(1, 1 - remaining / phaseDuration) : 0 }
    var sessionsInCurrentSet: Int { cycle.sessionsInCurrentSet }
    var canSkipBreak: Bool { breakContext?.canSkipNow ?? false }

    // MARK: - Commands

    func startWork() {
        recordAbandonedBreak()
        endPreview()
        breaks.end()
        cycle.config = settings.pomodoroConfig
        cycle.startWork()
        enterCurrentPhase()
    }

    /// Pauses or resumes a work session. Breaks cannot be paused: the cat does not negotiate.
    func togglePause() {
        guard phase == .work else { return }
        if isPaused {
            endDate = Date().addingTimeInterval(remaining)
            isPaused = false
            startTicker()
        } else {
            tick()
            isPaused = true
            stopTicker()
            peekingCat.dismiss()
        }
    }

    /// Skips the current phase. Work ends straight into a break; a break only ends when skipping is allowed.
    func skip() {
        switch phase {
        case .idle:
            break
        case .work:
            advance()
        case .shortBreak, .longBreak:
            if canSkipBreak { advance() }
        }
    }

    /// "I want my break now": ends the work session early.
    func takeBreakNow() {
        if phase == .idle { cycle.startWork() }
        if cycle.phase == .work { advance() }
    }

    func reset() {
        recordAbandonedBreak()
        endPreview()
        breaks.end()
        breakContext = nil
        activeBreakMode = nil
        stopTicker()
        peekingCat.close()
        cycle.reset()
        cycle.config = settings.pomodoroConfig
        phase = .idle
        isPaused = false
        completedWorkSessions = 0
        phaseDuration = 0
        remaining = settings.pomodoroConfig.work
    }

    /// Shows a break mode for a few seconds without touching the cycle.
    func preview(_ mode: BreakModeID, seconds: TimeInterval = 30) {
        guard !phase.isBreak else { return }
        endPreview()
        let context = BreakContext(
            duration: seconds,
            isLongBreak: false,
            isPreview: true,
            skipUnlockDate: Date(),
            onSkip: { [weak self] in self?.endPreview() }
        )
        breaks.start(mode: mode, context: context)
        activeBreakMode = breaks.currentModeID
        previewTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.endPreview() }
        }
    }

    /// Shows the peeking cat warning right away, without touching the cycle.
    func previewBreakWarning() {
        guard !phase.isBreak else { return }
        let seconds = settings.breakWarningSeconds > 0 ? settings.breakWarningSeconds : BreakWarning.defaultLeadTime
        peekingCat.show(message: BreakWarning.message(seconds: seconds))
        playSound("Tink")
    }

    /// Closes every break window right away. Called when the app quits.
    func shutdown() {
        previewTimer?.invalidate()
        previewTimer = nil
        breaks.forceEnd()
        OverlayWindow.closeAllBreakOverlays()
        peekingCat.close()
    }

    // MARK: - Internals

    /// The coordinator closed a break by force: the emergency exit or the watchdog.
    /// Moves the cycle on as if the break had been skipped, whatever the skip rules say.
    private func breakForceEnded(_ context: BreakContext, emergency: Bool) {
        if context.isPreview {
            endPreview()
        } else if let breakContext, breakContext === context, phase.isBreak {
            advance()
        }
        if emergency {
            peekingCat.show(message: "Ok, ti lascio andare… stavolta")
        }
    }

    private func endPreview() {
        guard let timer = previewTimer else { return }
        timer.invalidate()
        previewTimer = nil
        breaks.end()
        activeBreakMode = nil
    }

    private func advance() {
        recordEndOfPhase()
        let wasBreak = cycle.phase.isBreak
        cycle.advance(autoStartWork: settings.autoStartWork)
        if wasBreak {
            breaks.end()
            breakContext = nil
            activeBreakMode = nil
            playSound("Glass")
        }
        enterCurrentPhase()
    }

    // MARK: - Stats

    /// Records the phase that is ending. The tick sets `remaining` to 0 before advancing,
    /// so a phase that ends with time left was ended early by the user.
    private func recordEndOfPhase() {
        let finished = remaining <= 0
        switch phase {
        case .idle:
            break
        case .work:
            let focused = finished ? phaseDuration : phaseDuration - remaining
            stats.recordWork(completed: finished, focusSeconds: max(0, focused))
        case .shortBreak, .longBreak:
            if let mode = activeBreakMode, breakContext != nil {
                stats.recordBreak(completed: finished, mode: mode)
            }
        }
    }

    /// A real break left through "start work" or "reset" counts as skipped.
    private func recordAbandonedBreak() {
        guard phase.isBreak, breakContext != nil, let mode = activeBreakMode else { return }
        stats.recordBreak(completed: false, mode: mode)
    }

    private func enterCurrentPhase() {
        phase = cycle.phase
        completedWorkSessions = cycle.completedWorkSessions
        isPaused = false
        breakWarning.reset()
        if phase != .work { peekingCat.dismiss() }

        guard phase != .idle else {
            stopTicker()
            endDate = nil
            phaseDuration = 0
            remaining = settings.pomodoroConfig.work
            return
        }

        let duration = cycle.currentDuration
        phaseDuration = duration
        remaining = duration
        endDate = Date().addingTimeInterval(duration)
        startTicker()

        if phase.isBreak {
            endPreview()
            peekingCat.close()
            playSound("Purr")
            let unlock: Date? = settings.strictMode ? nil : Date().addingTimeInterval(settings.skipUnlockSeconds)
            let context = BreakContext(
                duration: duration,
                isLongBreak: phase == .longBreak,
                isPreview: false,
                skipUnlockDate: unlock,
                onSkip: { [weak self] in self?.skip() }
            )
            breakContext = context
            breaks.start(mode: settings.breakMode, context: context)
            activeBreakMode = breaks.currentModeID
        }
    }

    private func playSound(_ name: NSSound.Name) {
        guard settings.soundEnabled else { return }
        NSSound(named: name)?.play()
    }

    /// Ticks once a second, right after the clock in the menu bar changes, instead of
    /// polling: the Mac can stay asleep in between. Restarted on every phase change and
    /// resume, so the ticks stay aligned with the new countdown.
    private func startTicker() {
        stopTicker()
        guard let endDate else { return }
        // A few milliseconds past the change, so the tick never lands just before it.
        let firstTick = Date().addingTimeInterval(
            secondsUntilClockChanges(remaining: endDate.timeIntervalSinceNow) + 0.01
        )
        let timer = Timer(fire: firstTick, interval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        // Lets macOS coalesce this wakeup with others; 50 ms late is invisible in a clock.
        timer.tolerance = 0.05
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        guard let endDate, !isPaused else { return }
        remaining = max(0, endDate.timeIntervalSinceNow)
        if remaining <= 0 {
            advance()
            return
        }
        checkBreakWarning()
    }

    /// Lets a cat peek from the bottom of the screen shortly before the break.
    private func checkBreakWarning() {
        // A break preview is on screen: the user is looking at cats already.
        guard previewTimer == nil else { return }
        breakWarning.leadTime = TimeInterval(settings.breakWarningSeconds)
        guard breakWarning.shouldWarn(
            phase: phase,
            isPaused: isPaused,
            remaining: remaining,
            phaseDuration: phaseDuration
        ) else { return }
        let seconds = breakWarning.announcedSeconds(remaining: remaining)
        peekingCat.show(message: BreakWarning.message(seconds: seconds))
        playSound("Tink")
    }
}
