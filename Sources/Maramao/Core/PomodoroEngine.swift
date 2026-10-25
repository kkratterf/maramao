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
    /// "Bentornato! …" after the user came back from being away, shown in the menu.
    @Published private(set) var awayNotice: String?
    /// True while "Riprendi da dove ero" can undo a reset caused by being away.
    @Published private(set) var canUndoAwayReset = false
    /// True while a break postponed with "Rimanda" waits to come back. The phase stays the
    /// break's; the countdown is the snooze.
    @Published private(set) var isBreakSnoozed = false
    /// True while the break is held back because the user is in a call or presenting.
    @Published private(set) var isBreakPostponed = false

    private let settings: AppSettings
    private let stats: StatsStore
    private let companion: CatCompanionStore
    private let breaks = BreakCoordinator()
    private var cycle: PomodoroCycle
    private var endDate: Date?
    private var ticker: Timer?
    private var breakContext: BreakContext?
    private var previewTimer: Timer?
    private var breakWarning = BreakWarning()
    private let peekingCat = PeekingCatWarning()
    private let presence = PresenceMonitor()
    /// The mode of the snoozed break: the same cat comes back.
    private var snoozedMode: BreakModeID?
    private var postponer = BreakPostponer()
    /// True while a work session is paused because the user is away (not by the user).
    private var frozenByAway = false
    /// Work time left when a session was reset by an absence, for "Riprendi da dove ero".
    private var awayResetRemaining: TimeInterval?

    init(settings: AppSettings = .shared, stats: StatsStore? = nil, companion: CatCompanionStore? = nil) {
        self.settings = settings
        self.stats = stats ?? StatsStore.shared
        self.companion = companion ?? CatCompanionStore.shared
        self.cycle = PomodoroCycle(config: settings.pomodoroConfig)
        self.remaining = settings.pomodoroConfig.work
        breaks.onEmergencyExit = { [weak self] context in
            self?.breakForceEnded(context, emergency: true)
        }
        breaks.onWatchdogFired = { [weak self] context in
            self?.breakForceEnded(context, emergency: false)
        }
        presence.idleThreshold = { [weak settings] in
            AwayPolicy.idleThreshold(shortBreak: (settings?.shortBreakMinutes ?? 5) * 60)
        }
        presence.onAway = { [weak self] since in
            self?.userWentAway(since: since)
        }
        presence.onReturn = { [weak self] since in
            self?.userCameBack(awaySince: since)
        }
        presence.start()
    }

    var isRunning: Bool { phase != .idle && !isPaused }
    var progress: Double { phaseDuration > 0 ? min(1, 1 - remaining / phaseDuration) : 0 }
    var sessionsInCurrentSet: Int { cycle.sessionsInCurrentSet }
    var canSkipBreak: Bool {
        if isBreakSnoozed { return !settings.strictMode }
        return breakContext?.canSkipNow ?? false
    }
    var canSnoozeBreak: Bool { breakContext?.canSnoozeNow ?? false }

    // MARK: - Commands

    func startWork() {
        clearAwayState()
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
        clearAwayState()
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
        updateIdlePolling()
    }

    /// Skips the current phase. Work ends straight into a break; a break only ends when skipping is allowed.
    func skip() {
        // During a "Prova un concept" preview, skipping closes the preview (e.g. from the
        // global skip shortcut) instead of touching the real cycle.
        if previewTimer != nil {
            endPreview()
            return
        }
        switch phase {
        case .idle:
            break
        case .work:
            advance()
        case .shortBreak, .longBreak:
            if canSkipBreak { advance() }
        }
    }

    /// "Rimanda": ends the break on screen and brings the same break back, from the top,
    /// after the snooze length. Limited per day; never in strict mode or previews.
    func snoozeBreak() {
        guard previewTimer == nil, phase.isBreak, !isBreakSnoozed,
              let context = breakContext, context.canSnoozeNow,
              settings.snoozePolicy.canOffer(usedToday: stats.today.breaksSnoozed, isPreview: false, strictMode: settings.strictMode)
        else { return }
        let seconds = settings.snoozePolicy.seconds
        snoozedMode = activeBreakMode
        breaks.end()
        breakContext = nil
        activeBreakMode = nil
        isBreakSnoozed = true
        stats.recordSnooze()
        phaseDuration = seconds
        remaining = seconds
        endDate = Date().addingTimeInterval(seconds)
        startTicker()
        peekingCat.show(message: BreakSnoozeText.snoozed(minutes: settings.snoozePolicy.minutes))
    }

    /// The snooze is over, or the user asked for the break now: the cat comes back.
    private func resumeSnoozedBreak() {
        guard isBreakSnoozed else { return }
        let mode = snoozedMode
        enterCurrentPhase(breakMode: mode)
    }

    /// "I want my break now": ends the work session early (or a snooze).
    func takeBreakNow() {
        if isBreakSnoozed {
            resumeSnoozedBreak()
            return
        }
        if phase == .idle { cycle.startWork() }
        if cycle.phase == .work { advance() }
    }

    func reset() {
        clearAwayState()
        recordAbandonedBreak()
        endPreview()
        breaks.end()
        breakContext = nil
        activeBreakMode = nil
        isBreakSnoozed = false
        snoozedMode = nil
        stopTicker()
        peekingCat.close()
        cycle.reset()
        cycle.config = settings.pomodoroConfig
        phase = .idle
        isPaused = false
        completedWorkSessions = 0
        phaseDuration = 0
        remaining = settings.pomodoroConfig.work
        updateIdlePolling()
    }

    /// "Riprendi da dove ero": undoes a reset caused by an absence the app took for a rest.
    func undoAwayReset() {
        guard canUndoAwayReset, phase == .idle, let left = awayResetRemaining, left > 0 else {
            clearAwayState()
            return
        }
        clearAwayState()
        peekingCat.dismiss()
        cycle.config = settings.pomodoroConfig
        cycle.startWork()
        enterCurrentPhase()
        // The focus before the absence is already in the stats: the rest of the session
        // runs as a shorter one.
        phaseDuration = left
        remaining = left
        endDate = Date().addingTimeInterval(left)
        startTicker()
    }

    /// Hides the "Bentornato" line in the menu.
    func dismissAwayNotice() {
        clearAwayState()
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
        companion.breakBegan()
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
        CatSounds.shared.chirp()
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
            if emergency { stats.recordEmergencyExit() }
            advance()
        }
        if emergency {
            peekingCat.show(message: String(localized: "Ok, ti lascio andare… stavolta"))
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
        cycle.advance(autoStartWork: settings.autoStartWork && mayAutoStartWork)
        if wasBreak {
            breaks.end()
            breakContext = nil
            activeBreakMode = nil
            CatSounds.shared.breakOverChime()
        }
        enterCurrentPhase()
    }

    // MARK: - Calls and presentations

    /// The work session just ran out. While the user is in a call or presenting, keeps it
    /// going one more minute (up to the maximum in Settings) and returns true.
    private func postponeBreakIfBusy() -> Bool {
        postponer.isEnabled = settings.dontInterruptCalls
        postponer.maxPostpone = TimeInterval(settings.maxPostponeMinutes * 60)
        guard postponer.isEnabled else { return false }
        switch postponer.decide(busy: BusyDetector.current()) {
        case .startBreak:
            return false
        case .postpone(let seconds, let announce):
            isBreakPostponed = true
            remaining = seconds
            endDate = Date().addingTimeInterval(seconds)
            startTicker()
            if announce {
                peekingCat.show(message: BreakPostponer.announcement)
            }
            return true
        }
    }

    // MARK: - Away from the Mac

    private var awayBehavior: AwayBehavior {
        AwayBehavior(rawValue: settings.awayBehaviorRaw) ?? .defaultBehavior
    }

    private func updateIdlePolling() {
        presence.setIdlePolling(phase == .work && !isPaused && awayBehavior != .ignore)
    }

    private func clearAwayState() {
        frozenByAway = false
        awayNotice = nil
        canUndoAwayReset = false
        awayResetRemaining = nil
    }

    /// The Mac went to sleep, the screen locked or the user stopped touching it.
    private func userWentAway(since: Date) {
        guard AwayPolicy.shouldFreeze(phase: phase, isPaused: isPaused, behavior: awayBehavior),
              let endDate else { return }
        remaining = AwayPolicy.remainingWhenLeft(
            remainingNow: endDate.timeIntervalSinceNow,
            now: Date(),
            awaySince: since,
            phaseDuration: phaseDuration
        )
        isPaused = true
        frozenByAway = true
        stopTicker()
        peekingCat.dismiss()
    }

    /// The user is back after `awaySince`. Breaks just go on: being away is resting.
    private func userCameBack(awaySince: Date) {
        let now = Date()
        let wasFrozen = frozenByAway && phase == .work && isPaused
        frozenByAway = false
        guard phase == .work, wasFrozen || !isPaused else { return }

        let nextBreak: TimeInterval = (cycle.completedWorkSessions + 1) % cycle.config.sessionsBeforeLongBreak == 0
            ? cycle.config.longBreak
            : cycle.config.shortBreak
        let left = wasFrozen ? remaining : (endDate?.timeIntervalSince(now) ?? remaining)
        let action = AwayPolicy.onReturn(
            phase: phase,
            behavior: awayBehavior,
            wasFrozen: wasFrozen,
            awayDuration: now.timeIntervalSince(awaySince),
            restThreshold: settings.shortBreakMinutes * 60,
            remaining: left,
            breakDuration: nextBreak
        )

        switch action {
        case .none:
            break
        case .resume(let newRemaining):
            remaining = newRemaining
            endDate = now.addingTimeInterval(newRemaining)
            isPaused = false
            startTicker()
        case .stayPaused:
            remaining = left
        case .resetRested:
            stats.recordWork(completed: false, focusSeconds: max(0, phaseDuration - left))
            awayResetRemaining = left
            cycle.abandonWork()
            enterCurrentPhase()
            canUndoAwayReset = left > 0
        case .skipBreakRested:
            stats.recordWork(completed: true, focusSeconds: phaseDuration)
            cycle.advance()
            cycle.advance(autoStartWork: settings.autoStartWork)
            enterCurrentPhase()
        }
        updateIdlePolling()

        if let message = AwayPolicy.message(for: action) {
            awayNotice = message
            peekingCat.show(message: message)
        }
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
            if let mode = realBreakMode {
                // A snoozed break that ends now was skipped while it waited.
                let respected = finished && !isBreakSnoozed
                stats.recordBreak(completed: respected, mode: mode)
                companion.recordBreak(respected: respected, mode: mode)
            }
        }
    }

    /// A real break left through "start work" or "reset" counts as skipped.
    private func recordAbandonedBreak() {
        guard phase.isBreak, let mode = realBreakMode else { return }
        stats.recordBreak(completed: false, mode: mode)
        companion.recordBreak(respected: false, mode: mode)
    }

    /// The mode of the real (not preview) break in progress, on screen or snoozed.
    private var realBreakMode: BreakModeID? {
        if isBreakSnoozed { return snoozedMode ?? settings.breakMode.resolved() }
        return breakContext != nil ? activeBreakMode : nil
    }

    private func enterCurrentPhase(breakMode: BreakModeID? = nil) {
        isBreakSnoozed = false
        snoozedMode = nil
        phase = cycle.phase
        completedWorkSessions = cycle.completedWorkSessions
        isPaused = false
        frozenByAway = false
        postponer.reset()
        isBreakPostponed = false
        breakWarning.reset()
        if phase != .work { peekingCat.dismiss() }
        if phase != .idle { canUndoAwayReset = false }
        updateIdlePolling()

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
            CatSounds.shared.randomMeow()
            let unlock: Date? = settings.strictMode ? nil : Date().addingTimeInterval(settings.skipUnlockSeconds)
            let snooze = settings.snoozePolicy
            let usedToday = stats.today.breaksSnoozed
            let offersSnooze = snooze.canOffer(usedToday: usedToday, isPreview: false, strictMode: settings.strictMode)
            let context = BreakContext(
                duration: duration,
                isLongBreak: phase == .longBreak,
                isPreview: false,
                skipUnlockDate: unlock,
                onSkip: { [weak self] in self?.skip() },
                snoozeMinutes: snooze.minutes,
                snoozeDeadline: offersSnooze ? Date().addingTimeInterval(snooze.offerDuration(breakDuration: duration)) : nil,
                snoozesLeft: snooze.snoozesLeft(usedToday: usedToday),
                onSnooze: { [weak self] in self?.snoozeBreak() }
            )
            breakContext = context
            companion.breakBegan()
            // A Focus filter may change the mode, or turn the cats off: the break
            // then only counts down in the menu bar. A snoozed break brings its own cat back.
            if let mode = breakMode ?? FocusFilterState.shared.breakMode(default: settings.breakMode) {
                breaks.start(mode: mode, context: context)
            }
            activeBreakMode = breaks.currentModeID
        }
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
            if isBreakSnoozed {
                resumeSnoozedBreak()
                return
            }
            // Never start a break nobody can see: wait for the wake or unlock.
            if phase == .work, presence.isScreenUnavailable { return }
            if phase == .work, postponeBreakIfBusy() { return }
            advance()
            return
        }
        checkBreakWarning()
    }

    /// Lets a cat peek from the bottom of the screen shortly before the break.
    private func checkBreakWarning() {
        // A break preview is on screen: the user is looking at cats already.
        guard previewTimer == nil, FocusFilterState.shared.policy.catsEnabled else { return }
        breakWarning.leadTime = TimeInterval(settings.breakWarningSeconds)
        guard breakWarning.shouldWarn(
            phase: phase,
            isPaused: isPaused,
            remaining: remaining,
            phaseDuration: phaseDuration
        ) else { return }
        let seconds = breakWarning.announcedSeconds(remaining: remaining)
        peekingCat.show(message: BreakWarning.message(seconds: seconds))
        CatSounds.shared.chirp()
    }
}
