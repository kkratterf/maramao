import Foundation

/// Moments when Maramao can run a Shortcut from the Shortcuts app.
public enum AutomationTrigger: String, CaseIterable, Identifiable, Sendable {
    case workStarts
    case breakStarts
    case breakEnds

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .workStarts: return "Quando inizia il lavoro"
        case .breakStarts: return "Quando inizia la pausa"
        case .breakEnds: return "Quando finisce la pausa"
        }
    }

    /// The triggers fired by a phase change, in order. A break that rolls straight into
    /// work fires "break ends" then "work starts". Same phase twice fires nothing.
    public static func triggers(from old: PomodoroPhase, to new: PomodoroPhase) -> [AutomationTrigger] {
        guard old != new else { return [] }
        var result: [AutomationTrigger] = []
        if old.isBreak && !new.isBreak { result.append(.breakEnds) }
        if new == .work { result.append(.workStarts) }
        if new.isBreak { result.append(.breakStarts) }
        return result
    }
}

/// How Maramao calls `/usr/bin/shortcuts`.
public enum ShortcutCommand {
    public static let executablePath = "/usr/bin/shortcuts"

    /// The Shortcut name as typed by the user, trimmed; nil when empty.
    public static func cleanName(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Arguments for `shortcuts run`, reading the input text from standard input.
    /// Nil when the name is empty.
    public static func runArguments(name: String) -> [String]? {
        guard let clean = cleanName(name) else { return nil }
        return ["run", clean, "--input-path", "-"]
    }

    /// The text passed to the Shortcut as input: a small JSON object, keys sorted,
    /// e.g. `{"event":"breakStarts","mode":"walkingCat","phase":"shortBreak"}`.
    /// Use "Get Dictionary from Input" in the Shortcut to read it.
    public static func inputText(trigger: AutomationTrigger, phase: PomodoroPhase, mode: String?) -> String {
        var pairs: [(String, String)] = [("event", trigger.rawValue)]
        if let mode, !mode.isEmpty { pairs.append(("mode", mode)) }
        pairs.append(("phase", phase.rawValue))
        let body = pairs.map { "\"\(escape($0.0))\":\"\(escape($0.1))\"" }.joined(separator: ",")
        return "{\(body)}"
    }

    /// Shortcut names from the output of `shortcuts list`: one per line, blanks dropped,
    /// duplicates removed, sorted case-insensitively.
    public static func parseList(_ output: String) -> [String] {
        var seen = Set<String>()
        var names: [String] = []
        for line in output.split(whereSeparator: \.isNewline) {
            guard let name = cleanName(String(line)), !seen.contains(name) else { continue }
            seen.insert(name)
            names.append(name)
        }
        return names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private static func escape(_ text: String) -> String {
        var out = ""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default:
                if scalar.value < 0x20 {
                    out += String(format: "\\u%04x", scalar.value)
                } else {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        return out
    }
}
