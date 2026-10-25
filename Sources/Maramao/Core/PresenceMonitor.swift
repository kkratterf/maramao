import AppKit
import CoreGraphics

/// Tells the engine when the user leaves the Mac and when they are back.
///
/// "Away" means any of: the Mac is asleep, the displays are asleep, the screen is locked,
/// another user is logged in (fast user switching), or no keyboard/mouse input for longer
/// than `idleThreshold`. None of these needs a permission: idle time comes from
/// `CGEventSource.secondsSinceLastEventType`, which is not an event tap.
@MainActor
final class PresenceMonitor {
    enum Reason: Hashable {
        case systemAsleep
        case screensAsleep
        case locked
        case sessionInactive
        case idle
    }

    private static let idlePollInterval: TimeInterval = 5

    /// Called once when the user goes away, with the moment they left.
    var onAway: ((Date) -> Void)?
    /// Called once when the user is back, with the moment they had left.
    var onReturn: ((Date) -> Void)?
    /// Seconds without input after which the user counts as away.
    var idleThreshold: () -> TimeInterval = { 300 }

    private(set) var reasons: Set<Reason> = []
    private(set) var awaySince: Date?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var distributedObservers: [NSObjectProtocol] = []
    private var idleTimer: Timer?
    private var wantsIdlePolling = false

    var isAway: Bool { !reasons.isEmpty }
    /// Asleep, displays off, locked or switched out: nobody could see a break now.
    var isScreenUnavailable: Bool { !reasons.subtracting([.idle]).isEmpty }

    func start() {
        guard workspaceObservers.isEmpty else { return }
        let workspace = NSWorkspace.shared.notificationCenter
        let pairs: [(NSNotification.Name, Reason, Bool)] = [
            (NSWorkspace.willSleepNotification, .systemAsleep, true),
            (NSWorkspace.didWakeNotification, .systemAsleep, false),
            (NSWorkspace.screensDidSleepNotification, .screensAsleep, true),
            (NSWorkspace.screensDidWakeNotification, .screensAsleep, false),
            (NSWorkspace.sessionDidResignActiveNotification, .sessionInactive, true),
            (NSWorkspace.sessionDidBecomeActiveNotification, .sessionInactive, false),
        ]
        for (name, reason, isLeaving) in pairs {
            let observer = workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.update(reason, isLeaving: isLeaving) }
            }
            workspaceObservers.append(observer)
        }

        let distributed = DistributedNotificationCenter.default()
        let lockPairs: [(String, Bool)] = [
            ("com.apple.screenIsLocked", true),
            ("com.apple.screenIsUnlocked", false),
        ]
        for (name, isLeaving) in lockPairs {
            let observer = distributed.addObserver(
                forName: NSNotification.Name(name),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.update(.locked, isLeaving: isLeaving) }
            }
            distributedObservers.append(observer)
        }
    }

    func stop() {
        let workspace = NSWorkspace.shared.notificationCenter
        for observer in workspaceObservers { workspace.removeObserver(observer) }
        workspaceObservers.removeAll()
        let distributed = DistributedNotificationCenter.default()
        for observer in distributedObservers { distributed.removeObserver(observer) }
        distributedObservers.removeAll()
        idleTimer?.invalidate()
        idleTimer = nil
    }

    /// Turns idle polling on while a work session runs. It also keeps running on its own
    /// while the user is idle, to notice the return.
    func setIdlePolling(_ enabled: Bool) {
        wantsIdlePolling = enabled
        refreshIdleTimer()
    }

    // MARK: - Internals

    private func update(_ reason: Reason, isLeaving: Bool) {
        if isLeaving {
            add(reason, since: Date())
        } else {
            // Waking or unlocking takes input: idle time is fresh again.
            if reason != .idle { checkIdle() }
            remove(reason)
        }
    }

    private func add(_ reason: Reason, since: Date) {
        guard !reasons.contains(reason) else { return }
        let wasAway = isAway
        reasons.insert(reason)
        if !wasAway {
            awaySince = since
            onAway?(since)
        }
        refreshIdleTimer()
    }

    private func remove(_ reason: Reason) {
        guard reasons.contains(reason) else { return }
        reasons.remove(reason)
        if reasons.isEmpty {
            let since = awaySince ?? Date()
            awaySince = nil
            onReturn?(since)
        }
        refreshIdleTimer()
    }

    private func refreshIdleTimer() {
        let needed = wantsIdlePolling || reasons.contains(.idle)
        if needed, idleTimer == nil {
            let timer = Timer(timeInterval: Self.idlePollInterval, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.checkIdle() }
            }
            timer.tolerance = 1
            RunLoop.main.add(timer, forMode: .common)
            idleTimer = timer
        } else if !needed, let timer = idleTimer {
            timer.invalidate()
            idleTimer = nil
        }
    }

    private func checkIdle() {
        let idle = Self.secondsSinceLastInput()
        let threshold = idleThreshold()
        if idle >= threshold {
            // Sleeping or locked already covers it; idle only matters with the screen in use.
            if !reasons.contains(.idle) {
                add(.idle, since: Date().addingTimeInterval(-idle))
            }
        } else if reasons.contains(.idle) {
            remove(.idle)
        }
    }

    /// Seconds since the last keyboard, mouse or trackpad event in this login session.
    private static func secondsSinceLastInput() -> TimeInterval {
        // kCGAnyInputEventType (~0) is a macro Swift does not import.
        if let anyInput = CGEventType(rawValue: ~UInt32(0)) {
            return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
        }
        let types: [CGEventType] = [.mouseMoved, .keyDown, .leftMouseDown, .rightMouseDown, .scrollWheel, .flagsChanged]
        return types
            .map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }
            .min() ?? 0
    }
}
