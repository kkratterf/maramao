import Foundation

/// A command sent to Maramao from outside: a `maramao://` URL opened by
/// Shortcuts, Raycast, a Stream Deck or `open` in the terminal.
public enum AutomationCommand: Equatable, Sendable {
    /// Start a pomodoro (or resume a paused one).
    case start
    /// Pause the running pomodoro.
    case pause
    /// Resume a paused pomodoro.
    case resume
    /// Start, pause or resume, like the main button.
    case toggle
    /// Take the cat break now.
    case takeBreak
    /// Skip the current phase (a break only once skipping is allowed).
    case skip
    /// Back to idle.
    case reset
    /// Choose the break mode, by `BreakModeID` raw value (case-insensitive).
    case setMode(String)
    /// Preview a break mode for 30 seconds, by `BreakModeID` raw value.
    case preview(String)

    /// URL scheme registered in Info.plist.
    public static let urlScheme = "maramao"

    /// Every URL the scheme understands, for docs and help text.
    public static let documentedURLs: [String] = [
        "maramao://start",
        "maramao://pause",
        "maramao://resume",
        "maramao://toggle",
        "maramao://break",
        "maramao://skip",
        "maramao://reset",
        "maramao://mode/<id>",
        "maramao://preview/<id>",
    ]

    /// Parses a `maramao://` URL. Accepts `maramao://start`, `maramao:start`
    /// and `maramao:///start`, ignores case, trailing slashes and query
    /// strings. Returns nil for anything else.
    public init?(url: URL) {
        guard url.scheme?.lowercased() == AutomationCommand.urlScheme else { return nil }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }

        var parts: [String] = []
        if let host = components.host, !host.isEmpty {
            parts.append(host)
        }
        let pathParts = components.path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map { String($0) }
        parts.append(contentsOf: pathParts)
        parts = parts.map { $0.removingPercentEncoding ?? $0 }
        guard let verb = parts.first?.lowercased() else { return nil }
        let arguments = Array(parts.dropFirst())

        switch (verb, arguments.count) {
        case ("start", 0): self = .start
        case ("pause", 0): self = .pause
        case ("resume", 0): self = .resume
        case ("toggle", 0): self = .toggle
        case ("break", 0): self = .takeBreak
        case ("skip", 0): self = .skip
        case ("reset", 0): self = .reset
        case ("mode", 1):
            let id = arguments[0].trimmingCharacters(in: .whitespaces)
            guard !id.isEmpty else { return nil }
            self = .setMode(id)
        case ("preview", 1):
            let id = arguments[0].trimmingCharacters(in: .whitespaces)
            guard !id.isEmpty else { return nil }
            self = .preview(id)
        default:
            return nil
        }
    }
}
