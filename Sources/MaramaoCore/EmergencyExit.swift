import Foundation

/// Detects a burst of rapid clicks, e.g. five clicks within three seconds in the
/// emergency corner. Pure state: the app feeds it the time of every click.
public struct RapidClickDetector: Equatable, Sendable {
    /// Clicks needed to trigger.
    public let requiredClicks: Int
    /// Every click of the burst must land within this many seconds of the first one.
    public let window: TimeInterval
    /// Timestamps of the clicks in the current burst, oldest first.
    public private(set) var clicks: [TimeInterval] = []

    public init(requiredClicks: Int = 5, window: TimeInterval = 3) {
        self.requiredClicks = max(1, requiredClicks)
        self.window = max(0, window)
    }

    /// Records a click at `time` (seconds on any monotonic clock). Returns true when this
    /// click completes a burst; the burst then starts over, so the next trigger needs a
    /// whole new burst.
    public mutating func registerClick(at time: TimeInterval) -> Bool {
        // A clock that went backwards (should not happen) starts a fresh burst.
        if let last = clicks.last, time < last { clicks.removeAll() }
        clicks.append(time)
        clicks.removeAll { time - $0 > window }
        guard clicks.count >= requiredClicks else { return false }
        clicks.removeAll()
        return true
    }

    public mutating func reset() {
        clicks.removeAll()
    }
}

/// Decides when a break overlay has outstayed its welcome and must be torn down
/// by force, whatever the break mode is doing.
public enum BreakWatchdog {
    /// Seconds a break may stay on screen after its planned end before it is closed by force.
    public static let defaultGrace: TimeInterval = 30

    /// True when a break that should have ended at `endDate` is still on screen at `now`
    /// more than `grace` seconds later.
    public static func isOverdue(now: Date, endDate: Date, grace: TimeInterval = defaultGrace) -> Bool {
        now.timeIntervalSince(endDate) > max(0, grace)
    }
}
