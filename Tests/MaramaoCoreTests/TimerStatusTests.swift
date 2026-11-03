import XCTest
@testable import MaramaoCore

final class TimerStatusTests: XCTestCase {
    private func status(_ phase: PomodoroPhase, paused: Bool = false, snoozed: Bool = false, off: String? = nil) -> TimerStatus {
        TimerStatus(phase: phase, isPaused: paused, remaining: 18 * 60 + 32, isBreakSnoozed: snoozed, offUntil: off)
    }

    func testMapsEveryState() {
        XCTAssertEqual(status(.idle), .ready)
        XCTAssertEqual(status(.idle, off: "fino alle 10:30"), .off(until: "fino alle 10:30"))
        XCTAssertEqual(status(.work), .working(remaining: 18 * 60 + 32))
        XCTAssertEqual(status(.work, paused: true), .paused(remaining: 18 * 60 + 32))
        XCTAssertEqual(status(.shortBreak), .onBreak(remaining: 18 * 60 + 32))
        XCTAssertEqual(status(.longBreak, snoozed: true), .breakSnoozed(remaining: 18 * 60 + 32))
    }

    func testPrimaryActionFollowsTheClockApp() {
        XCTAssertEqual(status(.idle).primaryAction, .start)
        XCTAssertEqual(status(.work).primaryAction, .pause)
        XCTAssertEqual(status(.work, paused: true).primaryAction, .resume)
        XCTAssertEqual(status(.idle, off: "fino a domani").primaryAction, .resume)
        // Breaks cannot be paused: the cat does not negotiate.
        XCTAssertNil(status(.shortBreak).primaryAction)
        XCTAssertNil(status(.shortBreak, snoozed: true).primaryAction)
    }

    func testStopOnlyDuringWork() {
        XCTAssertTrue(status(.work).canStop)
        XCTAssertTrue(status(.work, paused: true).canStop)
        XCTAssertFalse(status(.idle).canStop)
        XCTAssertFalse(status(.shortBreak).canStop)
    }

    func testTitleShowsTheClock() {
        XCTAssertTrue(status(.work).title.contains("18:32"))
        XCTAssertTrue(status(.work, paused: true).title.contains("18:32"))
        XCTAssertTrue(status(.shortBreak).title.contains("18:32"))
        XCTAssertTrue(status(.idle, off: "fino alle 10:30").title.contains("fino alle 10:30"))
        XCTAssertNotEqual(status(.work).title, status(.work, paused: true).title)
    }
}
