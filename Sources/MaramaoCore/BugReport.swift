import Foundation

/// The last `capacity` log lines, oldest first. Bounded, in memory only.
public struct LogRing: Equatable, Sendable {
    public static let defaultCapacity = 200

    public let capacity: Int
    private var storage: [String] = []
    /// Index of the oldest line once the buffer is full.
    private var head = 0

    public init(capacity: Int = LogRing.defaultCapacity) {
        self.capacity = max(0, capacity)
        storage.reserveCapacity(self.capacity)
    }

    public mutating func append(_ line: String) {
        guard capacity > 0 else { return }
        if storage.count < capacity {
            storage.append(line)
        } else {
            storage[head] = line
            head = (head + 1) % capacity
        }
    }

    /// Every line kept, oldest first.
    public var lines: [String] {
        Array(storage[head...]) + Array(storage[..<head])
    }
}

/// What "Segnala un problema" copies and puts in the GitHub issue.
///
/// Only technical facts: versions, display sizes, the numeric and on/off settings, and
/// the in-memory log, whose lines are fixed messages written by the app. Nothing typed
/// by the user (cat names, shortcut names, folders) belongs here.
public struct BugReport: Equatable, Sendable {
    public var appVersion: String
    public var macOS: String
    /// Hardware model and architecture, e.g. "MacBookAir10,1 (arm64)".
    public var mac: String
    /// One line per display, e.g. "1440×900 @2x (main)".
    public var displays: [String]
    /// Settings as (name, value) pairs, in display order.
    public var settings: [Setting]
    public var log: [String]

    public struct Setting: Equatable, Sendable {
        public var name: String
        public var value: String

        public init(_ name: String, _ value: String) {
            self.name = name
            self.value = value
        }
    }

    public init(appVersion: String, macOS: String, mac: String, displays: [String], settings: [Setting], log: [String]) {
        self.appVersion = appVersion
        self.macOS = macOS
        self.mac = mac
        self.displays = displays
        self.settings = settings
        self.log = log
    }

    /// The repository's "new issue" page, using the bug form.
    public static let newIssueURL = "https://github.com/kkratterf/maramao/issues/new"
    /// GitHub refuses very long URLs; stay well below its limit.
    public static let maxURLLength = 7000

    /// Plain-text report, for the clipboard and the issue form.
    public var text: String {
        var out = "Maramao \(appVersion)\n"
        out += "macOS: \(macOS)\n"
        out += "Mac: \(mac)\n"
        out += "Displays: \(displays.isEmpty ? "none" : displays.joined(separator: "; "))\n"
        out += "\nSettings:\n"
        for setting in settings {
            out += "- \(setting.name): \(setting.value)\n"
        }
        out += "\nLog (last \(log.count) lines):\n"
        out += log.isEmpty ? "(empty)\n" : log.joined(separator: "\n") + "\n"
        return out
    }

    /// A prefilled "new issue" URL for the bug form (`.github/ISSUE_TEMPLATE/bug.yml`).
    /// Drops the oldest log lines until the URL fits `maxLength`; the clipboard keeps the
    /// whole report.
    public func issueURL(maxLength: Int = BugReport.maxURLLength) -> URL? {
        var trimmed = self
        var url = trimmed.buildIssueURL()
        while url.count > maxLength, !trimmed.log.isEmpty {
            trimmed.log.removeFirst()
            url = trimmed.buildIssueURL()
        }
        return URL(string: url)
    }

    private func buildIssueURL() -> String {
        let items: [(String, String)] = [
            ("template", "bug.yml"),
            ("version", appVersion),
            ("macos", "\(macOS), \(mac), \(displays.count) display(s)"),
            ("diagnostics", text),
        ]
        let query = items.map { "\($0.0)=\(Self.encode($0.1))" }.joined(separator: "&")
        return "\(Self.newIssueURL)?\(query)"
    }

    /// Percent-encodes everything but unreserved characters, so "+", "&" and "=" in
    /// the report survive as text.
    static func encode(_ value: String) -> String {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    }
}
