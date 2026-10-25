import Foundation

/// Launch hooks for the footprint job in CI (`scripts/measure-footprint.sh`), which needs the
/// app in a known state without clicking the menu bar. Read from the environment, so a normal
/// launch never triggers them.
enum MeasurementHooks {
    /// `MARAMAO_MEASURE=work` starts a pomodoro; `MARAMAO_MEASURE=<mode id>` (e.g. `catPile`)
    /// shows that break as a long preview.
    @MainActor
    static func run() {
        guard let value = ProcessInfo.processInfo.environment["MARAMAO_MEASURE"] else { return }
        let engine = PomodoroEngine.shared
        if value == "work" {
            engine.startWork()
        } else if let mode = BreakModeID(rawValue: value) {
            engine.preview(mode, seconds: 600)
        }
    }
}
