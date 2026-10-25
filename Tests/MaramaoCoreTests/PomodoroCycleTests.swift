import XCTest
@testable import MaramaoCore

final class PomodoroCycleTests: XCTestCase {
    func testWorkIsFollowedByShortBreak() {
        var cycle = PomodoroCycle()
        cycle.startWork()
        XCTAssertEqual(cycle.advance(), .shortBreak)
        XCTAssertEqual(cycle.completedWorkSessions, 1)
    }

    func testEveryFourthSessionGivesLongBreak() {
        var cycle = PomodoroCycle(config: PomodoroConfig(sessionsBeforeLongBreak: 4))
        var breaks: [PomodoroPhase] = []
        for _ in 0..<8 {
            cycle.startWork()
            breaks.append(cycle.advance())
        }
        XCTAssertEqual(breaks, [
            .shortBreak, .shortBreak, .shortBreak, .longBreak,
            .shortBreak, .shortBreak, .shortBreak, .longBreak,
        ])
    }

    func testBreakEndsInIdleUnlessAutoStart() {
        var cycle = PomodoroCycle()
        cycle.startWork()
        cycle.advance()
        XCTAssertEqual(cycle.advance(autoStartWork: false), .idle)

        cycle.startWork()
        cycle.advance()
        XCTAssertEqual(cycle.advance(autoStartWork: true), .work)
    }

    func testDurationsFollowConfig() {
        var cycle = PomodoroCycle(config: PomodoroConfig(work: 50, shortBreak: 10, longBreak: 30, sessionsBeforeLongBreak: 1))
        XCTAssertEqual(cycle.currentDuration, 0)
        cycle.startWork()
        XCTAssertEqual(cycle.currentDuration, 50)
        cycle.advance()
        XCTAssertEqual(cycle.phase, .longBreak)
        XCTAssertEqual(cycle.currentDuration, 30)
    }

    func testSessionsBeforeLongBreakIsAtLeastOne() {
        XCTAssertEqual(PomodoroConfig(sessionsBeforeLongBreak: 0).sessionsBeforeLongBreak, 1)
    }

    func testResetClearsProgress() {
        var cycle = PomodoroCycle()
        cycle.startWork()
        cycle.advance()
        cycle.reset()
        XCTAssertEqual(cycle.phase, .idle)
        XCTAssertEqual(cycle.completedWorkSessions, 0)
    }

    func testFormatClock() {
        XCTAssertEqual(formatClock(0), "00:00")
        XCTAssertEqual(formatClock(59.2), "01:00")
        XCTAssertEqual(formatClock(25 * 60), "25:00")
        XCTAssertEqual(formatClock(3725), "1:02:05")
        XCTAssertEqual(formatClock(-4), "00:00")
    }

    func testSecondsUntilClockChanges() {
        XCTAssertEqual(secondsUntilClockChanges(remaining: 1500), 1)
        XCTAssertEqual(secondsUntilClockChanges(remaining: 1234.25), 0.25, accuracy: 1e-9)
        XCTAssertEqual(secondsUntilClockChanges(remaining: 0.4), 0.4, accuracy: 1e-9)
        XCTAssertEqual(secondsUntilClockChanges(remaining: 0), 0)
        XCTAssertEqual(secondsUntilClockChanges(remaining: -3), 0)
    }

    func testClockChangesRightAfterTheWait() {
        for remaining in [1500, 1234.25, 61.999, 0.4, 7.5] {
            let wait = secondsUntilClockChanges(remaining: remaining)
            XCTAssertEqual(formatClock(remaining - wait + 0.001), formatClock(remaining), "\(remaining)")
            XCTAssertNotEqual(formatClock(remaining - wait - 0.001), formatClock(remaining), "\(remaining)")
        }
    }
}

final class PomodoroCycleAbandonTests: XCTestCase {
    func testAbandonWorkGoesIdleWithoutCounting() {
        var cycle = PomodoroCycle()
        cycle.startWork()
        cycle.advance()
        cycle.advance(autoStartWork: true)
        XCTAssertEqual(cycle.phase, .work)
        cycle.abandonWork()
        XCTAssertEqual(cycle.phase, .idle)
        XCTAssertEqual(cycle.completedWorkSessions, 1)
    }

    func testAbandonWorkIgnoresBreaks() {
        var cycle = PomodoroCycle()
        cycle.startWork()
        cycle.advance()
        cycle.abandonWork()
        XCTAssertEqual(cycle.phase, .shortBreak)
    }
}

final class PomodoroCycleSnoozeTests: XCTestCase {
    func testSnoozeBringsTheSameBreakBackAndCountsOnce() {
        var cycle = PomodoroCycle(config: PomodoroConfig(sessionsBeforeLongBreak: 2))
        cycle.startWork()
        XCTAssertEqual(cycle.advance(), .shortBreak)
        cycle.startWork()
        XCTAssertEqual(cycle.advance(), .longBreak)
        XCTAssertEqual(cycle.completedWorkSessions, 2)
        cycle.snoozeBreak()
        XCTAssertEqual(cycle.phase, .work)
        XCTAssertEqual(cycle.completedWorkSessions, 1)
        XCTAssertEqual(cycle.advance(), .longBreak)
        XCTAssertEqual(cycle.completedWorkSessions, 2)
    }

    func testSnoozeOutsideABreakDoesNothing() {
        var cycle = PomodoroCycle()
        cycle.snoozeBreak()
        XCTAssertEqual(cycle.phase, .idle)
        cycle.startWork()
        cycle.snoozeBreak()
        XCTAssertEqual(cycle.phase, .work)
        XCTAssertEqual(cycle.completedWorkSessions, 0)
    }
}
