import Combine
import Foundation
import MaramaoCore
import os

/// Settings → "Automazioni": runs a Shortcut from the Shortcuts app when work starts,
/// a break starts or a break ends. Off by default. Watches the engine's phase from the
/// outside, so the engine knows nothing about it.
@MainActor
final class ShortcutAutomations: ObservableObject {
    static let shared = ShortcutAutomations()

    @Published var isEnabled: Bool { didSet { defaults.set(isEnabled, forKey: Keys.enabled) } }
    /// Shortcut name per trigger; empty means "nothing".
    @Published private(set) var names: [AutomationTrigger: String] = [:]
    /// Shortcuts found by `shortcuts list`, for the picker.
    @Published private(set) var available: [String] = []

    private let defaults: UserDefaults
    private var subscription: AnyCancellable?
    private var lastPhase: PomodoroPhase = .idle
    private var lastBreakMode: BreakModeID?
    nonisolated private static let log = Logger(subsystem: "Maramao", category: "shortcuts")

    private enum Keys {
        static let enabled = "automation.enabled"
        static func name(_ trigger: AutomationTrigger) -> String { "automation.shortcut.\(trigger.rawValue)" }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.bool(forKey: Keys.enabled)
        var loaded: [AutomationTrigger: String] = [:]
        for trigger in AutomationTrigger.allCases {
            loaded[trigger] = defaults.string(forKey: Keys.name(trigger)) ?? ""
        }
        names = loaded
    }

    /// Starts watching the engine. Call once at launch.
    func activate() {
        guard subscription == nil else { return }
        let engine = PomodoroEngine.shared
        lastPhase = engine.phase
        subscription = engine.$phase
            .removeDuplicates()
            .sink { [weak self] newPhase in
                // @Published emits before the engine has stored the phase and set the
                // break mode: read the engine once the current main-actor work is done.
                Task { @MainActor in self?.phaseChanged(to: newPhase) }
            }
    }

    func name(for trigger: AutomationTrigger) -> String {
        names[trigger] ?? ""
    }

    func setName(_ name: String, for trigger: AutomationTrigger) {
        names[trigger] = name
        defaults.set(name, forKey: Keys.name(trigger))
    }

    /// Runs the Shortcut of a trigger right away, for the "Prova" button.
    func test(_ trigger: AutomationTrigger) {
        run(trigger, phase: PomodoroEngine.shared.phase, mode: lastBreakMode)
    }

    /// Asks `shortcuts list` for the user's Shortcuts, off the main thread.
    func refreshAvailable() {
        DispatchQueue.global(qos: .utility).async {
            let output = ShortcutAutomations.execute(arguments: ["list"], input: nil)
            let list = output.status == 0 ? ShortcutCommand.parseList(output.stdout) : []
            if output.status != 0 {
                ShortcutAutomations.log.info("shortcuts list failed (\(output.status)): \(output.stderr, privacy: .public)")
            }
            DispatchQueue.main.async {
                Task { @MainActor in ShortcutAutomations.shared.available = list }
            }
        }
    }

    // MARK: - Internals

    private func phaseChanged(to newPhase: PomodoroPhase) {
        let old = lastPhase
        guard old != newPhase else { return }
        lastPhase = newPhase
        if newPhase.isBreak {
            lastBreakMode = PomodoroEngine.shared.activeBreakMode
        }
        for trigger in AutomationTrigger.triggers(from: old, to: newPhase) {
            run(trigger, phase: newPhase, mode: lastBreakMode)
        }
    }

    private func run(_ trigger: AutomationTrigger, phase: PomodoroPhase, mode: BreakModeID?) {
        guard isEnabled, let arguments = ShortcutCommand.runArguments(name: name(for: trigger)) else { return }
        let input = ShortcutCommand.inputText(trigger: trigger, phase: phase, mode: mode?.rawValue)
        let label = arguments[1]
        DispatchQueue.global(qos: .utility).async {
            let result = ShortcutAutomations.execute(arguments: arguments, input: input)
            if result.status != 0 {
                // A missing or failing Shortcut must never bother the user: log and move on.
                ShortcutAutomations.log.error("Shortcut \"\(label, privacy: .public)\" failed (\(result.status)): \(result.stderr, privacy: .public)")
            }
        }
    }

    /// Runs `/usr/bin/shortcuts` synchronously. Call off the main thread.
    nonisolated private static func execute(arguments: [String], input: String?) -> (status: Int32, stdout: String, stderr: String) {
        let path = ShortcutCommand.executablePath
        guard FileManager.default.isExecutableFile(atPath: path) else {
            return (-1, "", "\(path) not found")
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        do {
            try process.run()
        } catch {
            return (-1, "", error.localizedDescription)
        }
        if let input {
            stdinPipe.fileHandleForWriting.write(Data(input.utf8))
        }
        try? stdinPipe.fileHandleForWriting.close()
        // Read before waiting, so a chatty Shortcut cannot fill the pipe and hang.
        let out = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let err = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (
            process.terminationStatus,
            String(decoding: out, as: UTF8.self),
            String(decoding: err, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
