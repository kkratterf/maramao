import Foundation

/// Launch hooks for the footprint and screenshot jobs in CI (`scripts/measure-footprint.sh`,
/// `scripts/render-screenshots.sh`), which need the app in a known state without clicking the
/// menu bar. Read from the environment, so a normal launch never triggers them.
enum MeasurementHooks {
    /// `MARAMAO_MEASURE=work` starts a pomodoro; `MARAMAO_MEASURE=<mode id>` (e.g. `catPile`)
    /// shows that break as a long preview.
    @MainActor
    static func run() {
        probeLocalization()
        if let value = ProcessInfo.processInfo.environment["MARAMAO_MEASURE"] {
            let engine = PomodoroEngine.shared
            if value == "work" {
                engine.startWork()
            } else if let mode = BreakModeID(rawValue: value) {
                engine.preview(mode, seconds: 600)
            }
        }
        // `MARAMAO_SHOTS=<directory>`: snapshot the windows of whatever is on screen.
        ScreenshotHooks.run()
    }

    /// `MARAMAO_L10N_PROBE=1` prints a few localized strings and quits. CI runs the built app
    /// with `-AppleLanguages "(en)"` and `"(it)"` to check that the translations are in the bundle.
    private static func probeLocalization() {
        guard ProcessInfo.processInfo.environment["MARAMAO_L10N_PROBE"] != nil else { return }
        let lines = [
            String(localized: "Inizia a lavorare"),
            String(localized: "\(1) pomodori"),
            String(localized: "\(4) pomodori"),
            BreakModeID.walkingCat.title,
        ]
        print(lines.joined(separator: "\n"))
        fflush(stdout)
        exit(0)
    }
}
