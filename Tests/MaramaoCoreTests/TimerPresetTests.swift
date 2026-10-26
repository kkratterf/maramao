import XCTest
@testable import MaramaoCore

final class TimerPresetTests: XCTestCase {
    private let custom = PomodoroConfig(work: 30 * 60, shortBreak: 7 * 60, longBreak: 20 * 60, sessionsBeforeLongBreak: 3)

    func testFixedPresetsHaveTheirDurations() {
        XCTAssertEqual(
            TimerPreset.classic.config(custom: custom),
            PomodoroConfig(work: 25 * 60, shortBreak: 5 * 60, longBreak: 15 * 60, sessionsBeforeLongBreak: 3)
        )
        XCTAssertEqual(
            TimerPreset.long.config(custom: custom),
            PomodoroConfig(work: 50 * 60, shortBreak: 10 * 60, longBreak: 30 * 60, sessionsBeforeLongBreak: 3)
        )
        XCTAssertEqual(
            TimerPreset.deep.config(custom: custom),
            PomodoroConfig(work: 90 * 60, shortBreak: 20 * 60, longBreak: 30 * 60, sessionsBeforeLongBreak: 3)
        )
    }

    func testCustomIsTheSettingsConfig() {
        XCTAssertEqual(TimerPreset.custom.config(custom: custom), custom)
        XCTAssertNil(TimerPreset.custom.minutes)
    }

    func testPresetsKeepTheLongBreakRhythm() {
        for preset in TimerPreset.allCases {
            XCTAssertEqual(preset.config(custom: custom).sessionsBeforeLongBreak, 3, preset.rawValue)
        }
    }

    func testDefaultIsCustomSoUpdatesChangeNothing() {
        XCTAssertEqual(TimerPreset.defaultPreset, .custom)
    }

    func testParsesIdsIgnoringCase() {
        XCTAssertEqual(TimerPreset(id: "classic"), .classic)
        XCTAssertEqual(TimerPreset(id: "DEEP"), .deep)
        XCTAssertEqual(TimerPreset(id: " long "), .long)
        XCTAssertEqual(TimerPreset(id: "custom"), .custom)
        XCTAssertNil(TimerPreset(id: "turbo"))
        XCTAssertNil(TimerPreset(id: ""))
    }

    func testMenuTitles() {
        XCTAssertEqual(TimerPreset.allCases.map { $0.menuTitle(custom: custom) }, [
            "Classico 25/5",
            "Lungo 50/10",
            "Profondo 90/20",
            "Personalizzato 30/7",
        ])
    }
}
