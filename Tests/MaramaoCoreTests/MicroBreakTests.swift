import XCTest
@testable import MaramaoCore

final class MicroBreakTests: XCTestCase {
    private func schedule(_ minutes: Int = 20) -> MicroBreakSchedule {
        MicroBreakSchedule(intervalMinutes: minutes)
    }

    func testOffByDefault() {
        let micro = MicroBreakSchedule()
        XCTAssertFalse(micro.isEnabled)
        XCTAssertEqual(MicroBreakSchedule.defaultIntervalMinutes, 0)
        XCTAssertEqual(MicroBreakSchedule.suggestedIntervalMinutes, 20)
        XCTAssertEqual(MicroBreakSchedule.duration, 20)
        XCTAssertEqual(MicroBreakSchedule.intervalOptions, [0, 15, 20, 30])
    }

    func testOffNeverShows() {
        var micro = schedule(0)
        for elapsed in stride(from: 60.0, through: 3600, by: 60) {
            XCTAssertFalse(micro.shouldShow(
                phase: .work, isPaused: false, elapsed: elapsed, remaining: 3600, busy: false
            ))
        }
    }

    func testShowsOnceAfterEachInterval() {
        var micro = schedule(20)
        XCTAssertFalse(micro.shouldShow(phase: .work, isPaused: false, elapsed: 1199, remaining: 2400, busy: false))
        XCTAssertTrue(micro.shouldShow(phase: .work, isPaused: false, elapsed: 1200, remaining: 2400, busy: false))
        XCTAssertEqual(micro.shownInSession, 1)
        XCTAssertFalse(micro.shouldShow(phase: .work, isPaused: false, elapsed: 1201, remaining: 2399, busy: false))
        XCTAssertFalse(micro.shouldShow(phase: .work, isPaused: false, elapsed: 2399, remaining: 1201, busy: false))
        XCTAssertTrue(micro.shouldShow(phase: .work, isPaused: false, elapsed: 2400, remaining: 1200, busy: false))
        XCTAssertEqual(micro.shownInSession, 2)
    }

    func testNeverWithinTwoMinutesOfTheBreak() {
        var micro = schedule(20)
        // A 21-minute session: the interval falls inside the guard before the break.
        XCTAssertFalse(micro.shouldShow(phase: .work, isPaused: false, elapsed: 1200, remaining: 60, busy: false))
        XCTAssertFalse(micro.shouldShow(phase: .work, isPaused: false, elapsed: 1250, remaining: 10, busy: false))
        XCTAssertEqual(micro.shownInSession, 0)
        // Once there is more than the guard left again, it fires.
        XCTAssertTrue(micro.shouldShow(phase: .work, isPaused: false, elapsed: 1200, remaining: 121, busy: false))
    }

    func testNeverRightAfterTheBreak() {
        // A very short interval must still not fire in the first two minutes of work.
        var micro = schedule(1)
        XCTAssertFalse(micro.shouldShow(phase: .work, isPaused: false, elapsed: 60, remaining: 1500, busy: false))
        XCTAssertFalse(micro.shouldShow(phase: .work, isPaused: false, elapsed: 120, remaining: 1500, busy: false))
        XCTAssertTrue(micro.shouldShow(phase: .work, isPaused: false, elapsed: 121, remaining: 1500, busy: false))
    }

    func testNeverDuringBreaksIdleOrPause() {
        var micro = schedule(20)
        XCTAssertFalse(micro.shouldShow(phase: .shortBreak, isPaused: false, elapsed: 1200, remaining: 2400, busy: false))
        XCTAssertFalse(micro.shouldShow(phase: .longBreak, isPaused: false, elapsed: 1200, remaining: 2400, busy: false))
        XCTAssertFalse(micro.shouldShow(phase: .idle, isPaused: false, elapsed: 1200, remaining: 2400, busy: false))
        XCTAssertFalse(micro.shouldShow(phase: .work, isPaused: true, elapsed: 1200, remaining: 2400, busy: false))
        XCTAssertEqual(micro.shownInSession, 0)
    }

    func testBusyMissesTheIntervalAndFiresAfterwards() {
        var micro = schedule(20)
        XCTAssertFalse(micro.shouldShow(phase: .work, isPaused: false, elapsed: 1200, remaining: 2400, busy: true))
        XCTAssertEqual(micro.shownInSession, 0)
        XCTAssertTrue(micro.shouldShow(phase: .work, isPaused: false, elapsed: 1320, remaining: 2280, busy: false))
    }

    func testSkippedIntervalsAreNotFiredInARow() {
        var micro = schedule(20)
        // The ticks jumped by an hour (a frozen session that resumed).
        XCTAssertTrue(micro.shouldShow(phase: .work, isPaused: false, elapsed: 3600, remaining: 1200, busy: false))
        XCTAssertEqual(micro.shownInSession, 3)
        XCTAssertFalse(micro.shouldShow(phase: .work, isPaused: false, elapsed: 3601, remaining: 1199, busy: false))
        XCTAssertTrue(micro.shouldShow(phase: .work, isPaused: false, elapsed: 4800, remaining: 1200, busy: false))
    }

    func testResetStartsTheCountAgain() {
        var micro = schedule(20)
        XCTAssertTrue(micro.shouldShow(phase: .work, isPaused: false, elapsed: 1200, remaining: 2400, busy: false))
        micro.reset()
        XCTAssertEqual(micro.shownInSession, 0)
        XCTAssertTrue(micro.shouldShow(phase: .work, isPaused: false, elapsed: 1200, remaining: 2400, busy: false))
    }

    func testTexts() {
        XCTAssertEqual(MicroBreakSchedule.message, "Guarda lontano, almeno 6 metri")
        XCTAssertEqual(MicroBreakSchedule.optionLabel(minutes: 0), "Mai")
        XCTAssertEqual(MicroBreakSchedule.optionLabel(minutes: 20), "Ogni 20 minuti")
    }
}
