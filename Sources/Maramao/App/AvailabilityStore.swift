import AppKit
import Combine
import MaramaoCore
import os

/// "Pausa per…" and working hours: persists both and wakes Maramao up when a snooze ends,
/// also across restarts, sleep, clock and time zone changes.
@MainActor
final class AvailabilityStore: ObservableObject {
    static let shared = AvailabilityStore()

    /// When the current snooze ends, or nil when Maramao is not snoozed.
    @Published private(set) var snoozedUntil: Date?
    @Published var workingHours: WorkingHours { didSet { saveWorkingHours() } }

    private var resumesWork = false
    private var resumeTimer: Timer?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var phaseSubscription: AnyCancellable?
    private let defaults: UserDefaults
    private let log = Logger(subsystem: "Maramao", category: "availability")

    private enum Keys {
        static let snoozedUntil = "snooze.until"
        static let resumesWork = "snooze.resumesWork"
        static let workingHours = "workingHours.v1"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Keys.workingHours),
           let decoded = try? JSONDecoder().decode(WorkingHours.self, from: data) {
            workingHours = decoded
        } else {
            workingHours = WorkingHours()
        }
        let stored = defaults.double(forKey: Keys.snoozedUntil)
        if stored > 0 {
            snoozedUntil = Date(timeIntervalSince1970: stored)
            resumesWork = defaults.bool(forKey: Keys.resumesWork)
        }
        observeClock()
        // Talk to the engine only on the next run loop turn: the engine may be what is
        // creating this store right now.
        DispatchQueue.main.async { [weak self] in
            Task { @MainActor in self?.attachToEngine() }
        }
    }

    var isSnoozed: Bool { snoozedUntil != nil }

    /// True when Maramao may start work sessions on its own right now.
    func isWorkingTime(_ date: Date = Date()) -> Bool {
        workingHours.contains(date)
    }

    /// Text for the menu: "fino alle 10:30".
    func untilText(now: Date = Date()) -> String {
        guard let snoozedUntil else { return "" }
        return AvailabilityText.until(snoozedUntil, now: now)
    }

    /// Starting work by hand (menu, shortcut) ends the snooze; a restored snooze that is
    /// already over resumes.
    private func attachToEngine() {
        guard phaseSubscription == nil else { return }
        phaseSubscription = PomodoroEngine.shared.$phase
            .removeDuplicates()
            .sink { [weak self] phase in
                guard phase == .work else { return }
                Task { @MainActor in
                    guard let self, self.isSnoozed else { return }
                    self.endSnooze()
                }
            }
        recheck()
    }

    // MARK: - Snooze

    func snooze(_ option: SnoozeOption, now: Date = Date()) {
        let resume = option.resumeDate(from: now, calendar: .current, workingHours: workingHours)
        snoozedUntil = resume
        resumesWork = option.resumesWork
        defaults.set(resume.timeIntervalSince1970, forKey: Keys.snoozedUntil)
        defaults.set(resumesWork, forKey: Keys.resumesWork)
        log.info("Snoozed until \(resume.description, privacy: .public)")
        scheduleResume()
    }

    /// Ends the snooze now. Returns whether a work session should start.
    @discardableResult
    func endSnooze() -> Bool {
        let shouldStart = isSnoozed && resumesWork && isWorkingTime()
        snoozedUntil = nil
        resumesWork = false
        resumeTimer?.invalidate()
        resumeTimer = nil
        defaults.removeObject(forKey: Keys.snoozedUntil)
        defaults.removeObject(forKey: Keys.resumesWork)
        return shouldStart
    }

    /// Resumes when the snooze is over, otherwise (re)schedules the timer.
    func recheck() {
        guard let snoozedUntil else { return }
        if snoozedUntil <= Date() {
            PomodoroEngine.shared.resumeFromSnooze()
        } else {
            scheduleResume()
        }
    }

    private func scheduleResume() {
        resumeTimer?.invalidate()
        resumeTimer = nil
        guard let snoozedUntil else { return }
        let timer = Timer(fire: snoozedUntil, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.recheck() }
        }
        timer.tolerance = 1
        RunLoop.main.add(timer, forMode: .common)
        resumeTimer = timer
    }

    /// Timers drift across sleep and clock changes: check again when either happens.
    private func observeClock() {
        let local = NotificationCenter.default
        let workspace = NSWorkspace.shared.notificationCenter
        let names: [(NotificationCenter, Notification.Name)] = [
            (local, .NSSystemClockDidChange),
            (local, .NSSystemTimeZoneDidChange),
            (workspace, NSWorkspace.didWakeNotification),
        ]
        for (center, name) in names {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.recheck() }
            }
            observers.append((center, token))
        }
    }

    private func saveWorkingHours() {
        if let data = try? JSONEncoder().encode(workingHours) {
            defaults.set(data, forKey: Keys.workingHours)
        }
    }
}

extension PomodoroEngine {
    /// "Pausa per…": stops the timer and sleeps until the chosen time. Not during a break.
    func snooze(_ option: SnoozeOption) {
        guard !phase.isBreak else { return }
        reset()
        AvailabilityStore.shared.snooze(option)
    }

    /// Ends a snooze now, from the menu ("Riprendi") or when its time comes.
    /// Short snoozes start a work session, if within working hours and nothing is running.
    func resumeFromSnooze() {
        let shouldStart = AvailabilityStore.shared.endSnooze()
        if shouldStart && phase == .idle {
            startWork()
        }
    }

    /// Whether a break may roll into the next work session on its own right now.
    var mayAutoStartWork: Bool {
        AvailabilityStore.shared.isWorkingTime() && !AvailabilityStore.shared.isSnoozed
    }
}
