import Foundation
import CoreGraphics

/// What is keeping the user busy right now. Read from device state, no permissions.
public struct BusySignals: Equatable, Sendable {
    public var microphoneInUse: Bool
    public var cameraInUse: Bool
    /// A presentation, video or call app fills the screen.
    public var presenting: Bool

    public init(microphoneInUse: Bool = false, cameraInUse: Bool = false, presenting: Bool = false) {
        self.microphoneInUse = microphoneInUse
        self.cameraInUse = cameraInUse
        self.presenting = presenting
    }

    public static let idle = BusySignals()

    public var isBusy: Bool { microphoneInUse || cameraInUse || presenting }
}

/// What to do when a work session ends.
public enum PostponeDecision: Equatable, Sendable {
    /// Start the break now.
    case startBreak
    /// Keep working for `seconds` more, then ask again. `announce` is true the first time
    /// in a work session, to show "Ti aspetto dopo la call" once.
    case postpone(seconds: TimeInterval, announce: Bool)
}

/// Holds a break back while the user is in a call, sharing the screen or presenting:
/// one minute at a time, up to a maximum. Pure state, reset at every new phase.
public struct BreakPostponer: Equatable, Sendable {
    /// Length of one postponement.
    public static let step: TimeInterval = 60
    /// Maximum postponement choices in Settings, in minutes. 0 means "wait as long as it takes".
    public static let maxMinutesOptions: [Int] = [5, 10, 15, 30, 0]
    public static let defaultMaxMinutes = 10

    public var isEnabled: Bool
    /// Maximum total postponement in seconds. 0 or less: no limit.
    public var maxPostpone: TimeInterval
    /// Total postponement so far in this work session.
    public private(set) var postponed: TimeInterval = 0
    public private(set) var hasAnnounced = false

    public init(isEnabled: Bool = true, maxPostpone: TimeInterval = TimeInterval(BreakPostponer.defaultMaxMinutes * 60)) {
        self.isEnabled = isEnabled
        self.maxPostpone = maxPostpone
    }

    public var waitsForever: Bool { maxPostpone <= 0 }
    public var isPostponing: Bool { postponed > 0 }

    /// Called when a work session runs out. Postpones while `busy`, until the maximum.
    public mutating func decide(busy: BusySignals) -> PostponeDecision {
        guard isEnabled, busy.isBusy else { return .startBreak }
        guard waitsForever || postponed + Self.step <= maxPostpone + 0.5 else { return .startBreak }
        postponed += Self.step
        let announce = !hasAnnounced
        hasAnnounced = true
        return .postpone(seconds: Self.step, announce: announce)
    }

    /// Call when a new phase starts.
    public mutating func reset() {
        postponed = 0
        hasAnnounced = false
    }

    /// The Italian line the peeking cat says the first time.
    public static var announcement: String { String(localized: "Ti aspetto dopo la call 🐈") }

    /// Italian label for a maximum in Settings.
    public static func maxLabel(minutes: Int) -> String {
        minutes <= 0 ? String(localized: "Aspetta sempre") : String(localized: "Al massimo \(minutes) min")
    }
}

/// Recognises a fullscreen presentation, video or call from window geometry.
public enum PresentationDetector {
    /// Apps whose fullscreen windows mean "someone is watching": slides, video, calls.
    /// A fullscreen code editor or browser does not count, or breaks would never start.
    public static let presentationBundleIDs: Set<String> = [
        "com.apple.iWork.Keynote",
        "com.microsoft.Powerpoint",
        "com.apple.QuickTimePlayerX",
        "com.apple.TV",
        "com.apple.FaceTime",
        "org.videolan.vlc",
        "com.colliderli.iina",
        "us.zoom.xos",
        "com.microsoft.teams",
        "com.microsoft.teams2",
        "Cisco-Systems.Spark",
        "com.webex.meetingmanager",
        "com.google.Chrome.app.kjgfgldnnfoeklkmfkjfagphfepbbdan", // Google Meet PWA
        "com.apple.Photos",
        "com.apple.Preview",
    ]

    public static func isPresentationApp(bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return presentationBundleIDs.contains(bundleID)
    }

    /// True when one of `windows` covers a whole screen (within `tolerance` points).
    /// Both must be in the same coordinate space.
    public static func coversAScreen(windows: [CGRect], screens: [CGRect], tolerance: CGFloat = 2) -> Bool {
        for window in windows where window.width > 0 && window.height > 0 {
            for screen in screens {
                if abs(window.minX - screen.minX) <= tolerance,
                   abs(window.minY - screen.minY) <= tolerance,
                   abs(window.width - screen.width) <= tolerance,
                   abs(window.height - screen.height) <= tolerance {
                    return true
                }
            }
        }
        return false
    }
}
