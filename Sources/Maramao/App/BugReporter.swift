import AppKit
import MaramaoCore

/// "Segnala un problema": copies the diagnostics to the clipboard and opens a prefilled
/// GitHub issue in the browser. Nothing is sent anywhere: the user reads the issue and
/// decides whether to submit it.
@MainActor
enum BugReporter {
    static func reportProblem() {
        let report = makeReport()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(report.text, forType: .string)
        if let url = report.issueURL() {
            NSWorkspace.shared.open(url)
        }
    }

    static func makeReport() -> BugReport {
        BugReport(
            appVersion: appVersion,
            macOS: ProcessInfo.processInfo.operatingSystemVersionString,
            mac: "\(hardwareModel) (\(architecture))",
            displays: displays,
            settings: settings(AppSettings.shared),
            log: DiagnosticLog.shared.lines
        )
    }

    /// "0.2.0 (5)", or "dev" when running outside the .app.
    private static var appVersion: String {
        let info = Bundle.main.infoDictionary ?? [:]
        guard let version = info["CFBundleShortVersionString"] as? String else { return "dev" }
        if let build = info["CFBundleVersion"] as? String { return "\(version) (\(build))" }
        return version
    }

    /// e.g. "MacBookAir10,1": the model identifier, not the name the user gave the Mac.
    private static var hardwareModel: String {
        var size = 0
        guard sysctlbyname("hw.model", nil, &size, nil, 0) == 0, size > 0 else { return "unknown" }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname("hw.model", &buffer, &size, nil, 0) == 0 else { return "unknown" }
        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }

    private static var architecture: String {
        #if arch(arm64)
        return "arm64"
        #else
        return "x86_64"
        #endif
    }

    /// Size and scale of each display, the main one first. No display names.
    private static var displays: [String] {
        NSScreen.screens.enumerated().map { index, screen in
            let size = screen.frame.size
            let scale = String(format: "%g", Double(screen.backingScaleFactor))
            let main = index == 0 ? " (main)" : ""
            return "\(Int(size.width))×\(Int(size.height)) @\(scale)x\(main)"
        }
    }

    /// The numeric and on/off settings. Leaves out anything the user typed.
    private static func settings(_ s: AppSettings) -> [BugReport.Setting] {
        [
            .init("Language", Bundle.main.preferredLocalizations.first ?? "unknown"),
            .init("Work", "\(Int(s.workMinutes)) min"),
            .init("Short break", "\(Int(s.shortBreakMinutes)) min"),
            .init("Long break", "\(Int(s.longBreakMinutes)) min every \(s.sessionsBeforeLongBreak)"),
            .init("Break mode", s.breakModeRaw),
            .init("Displays", s.displayScopeRaw),
            .init("Break warning", "\(s.breakWarningSeconds) s"),
            .init("Strict mode", onOff(s.strictMode)),
            .init("Skip after", "\(Int(s.skipUnlockSeconds)) s"),
            .init("Snooze", "\(s.snoozeMinutes) min, \(s.snoozeDailyLimit) a day"),
            .init("Auto start work", onOff(s.autoStartWork)),
            .init("When away", s.awayBehaviorRaw),
            .init("Don't interrupt calls", s.dontInterruptCalls ? "on, max \(s.maxPostponeMinutes) min" : "off"),
            .init("Sounds", s.soundEnabled ? "on, \(Int((s.soundVolume * 100).rounded()))%" : "off"),
            .init("Menu bar", "\(s.menuBarStyleRaw)\(s.menuBarHideSeconds ? ", no seconds" : "")"),
            .init("Animations", s.motionPreferenceRaw),
            .init("Cat companion", onOff(s.companionEnabled)),
        ]
    }

    private static func onOff(_ value: Bool) -> String {
        value ? "on" : "off"
    }
}
