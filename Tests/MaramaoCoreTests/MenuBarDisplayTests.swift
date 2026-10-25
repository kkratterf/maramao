import XCTest
@testable import MaramaoCore

final class MenuBarDisplayTests: XCTestCase {
    func testWithSecondsMatchesFormatClock() {
        XCTAssertEqual(formatMenuBarClock(25 * 60, showSeconds: true), "25:00")
        XCTAssertEqual(formatMenuBarClock(59.2, showSeconds: true), formatClock(59.2))
    }

    func testMinutesOnlyRoundsUp() {
        XCTAssertEqual(formatMenuBarClock(25 * 60, showSeconds: false), "25m")
        XCTAssertEqual(formatMenuBarClock(24 * 60 + 1, showSeconds: false), "25m")
        XCTAssertEqual(formatMenuBarClock(24 * 60, showSeconds: false), "24m")
        XCTAssertEqual(formatMenuBarClock(23 * 60 + 59.5, showSeconds: false), "24m")
    }

    func testMinutesOnlyNeverSaysZeroWhileTimeIsLeft() {
        XCTAssertEqual(formatMenuBarClock(0.25, showSeconds: false), "1m")
        XCTAssertEqual(formatMenuBarClock(59, showSeconds: false), "1m")
        XCTAssertEqual(formatMenuBarClock(0, showSeconds: false), "0m")
        XCTAssertEqual(formatMenuBarClock(-5, showSeconds: false), "0m")
    }

    func testMinutesOnlyWithHours() {
        XCTAssertEqual(formatMenuBarClock(60 * 60, showSeconds: false), "1h 00m")
        XCTAssertEqual(formatMenuBarClock(64 * 60 + 30, showSeconds: false), "1h 05m")
        XCTAssertEqual(formatMenuBarClock(120 * 60, showSeconds: false), "2h 00m")
    }

    func testRingStepQuantizes() {
        XCTAssertEqual(menuBarRingStep(progress: 0, steps: 40), 0)
        XCTAssertEqual(menuBarRingStep(progress: 0.024, steps: 40), 0)
        XCTAssertEqual(menuBarRingStep(progress: 0.026, steps: 40), 1)
        XCTAssertEqual(menuBarRingStep(progress: 0.5, steps: 40), 20)
        XCTAssertEqual(menuBarRingStep(progress: 1, steps: 40), 40)
    }

    func testRingStepClampsBadInput() {
        XCTAssertEqual(menuBarRingStep(progress: -1, steps: 40), 0)
        XCTAssertEqual(menuBarRingStep(progress: 2, steps: 40), 40)
        XCTAssertEqual(menuBarRingStep(progress: .nan, steps: 40), 0)
        XCTAssertEqual(menuBarRingStep(progress: 0.5, steps: 0), 0)
    }

    func testStyles() {
        XCTAssertEqual(MenuBarStyle.defaultStyle, .catAndCountdown)
        XCTAssertTrue(MenuBarStyle.catAndCountdown.showsCountdown)
        XCTAssertTrue(MenuBarStyle.countdownOnly.showsCountdown)
        XCTAssertFalse(MenuBarStyle.catOnly.showsCountdown)
        XCTAssertFalse(MenuBarStyle.catWithRing.showsCountdown)
        XCTAssertEqual(MenuBarStyle(rawValue: "catWithRing"), .catWithRing)
        XCTAssertEqual(Set(MenuBarStyle.allCases.map(\.title)).count, MenuBarStyle.allCases.count)
    }
}
