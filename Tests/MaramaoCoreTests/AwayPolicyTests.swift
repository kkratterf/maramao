import XCTest
@testable import MaramaoCore

final class AwayPolicyTests: XCTestCase {
    private let rest: TimeInterval = 5 * 60
    private let shortBreak: TimeInterval = 5 * 60

    // MARK: - Idle

    func testIdleThresholdIsTheShortBreakButAtLeastAMinute() {
        XCTAssertEqual(AwayPolicy.idleThreshold(shortBreak: 300), 300)
        XCTAssertEqual(AwayPolicy.idleThreshold(shortBreak: 10), 60)
        XCTAssertFalse(AwayPolicy.isIdleAway(idleSeconds: 299, shortBreak: 300))
        XCTAssertTrue(AwayPolicy.isIdleAway(idleSeconds: 300, shortBreak: 300))
        XCTAssertFalse(AwayPolicy.isIdleAway(idleSeconds: 59, shortBreak: 1))
    }

    // MARK: - Freezing

    func testOnlyRunningWorkFreezes() {
        XCTAssertTrue(AwayPolicy.shouldFreeze(phase: .work, isPaused: false, behavior: .countAsBreak))
        XCTAssertTrue(AwayPolicy.shouldFreeze(phase: .work, isPaused: false, behavior: .pause))
        XCTAssertFalse(AwayPolicy.shouldFreeze(phase: .work, isPaused: false, behavior: .ignore))
        XCTAssertFalse(AwayPolicy.shouldFreeze(phase: .work, isPaused: true, behavior: .countAsBreak))
        XCTAssertFalse(AwayPolicy.shouldFreeze(phase: .shortBreak, isPaused: false, behavior: .countAsBreak))
        XCTAssertFalse(AwayPolicy.shouldFreeze(phase: .longBreak, isPaused: false, behavior: .pause))
        XCTAssertFalse(AwayPolicy.shouldFreeze(phase: .idle, isPaused: false, behavior: .countAsBreak))
    }

    func testRemainingWhenLeftGivesBackTheIdleTime() {
        let now = Date(timeIntervalSinceReferenceDate: 10_000)
        let left = AwayPolicy.remainingWhenLeft(
            remainingNow: 600, now: now, awaySince: now.addingTimeInterval(-300), phaseDuration: 1500
        )
        XCTAssertEqual(left, 900)
    }

    func testRemainingWhenLeftIsCappedAndNeverNegative() {
        let now = Date(timeIntervalSinceReferenceDate: 10_000)
        XCTAssertEqual(AwayPolicy.remainingWhenLeft(
            remainingNow: 1400, now: now, awaySince: now.addingTimeInterval(-300), phaseDuration: 1500
        ), 1500)
        XCTAssertEqual(AwayPolicy.remainingWhenLeft(
            remainingNow: -20, now: now, awaySince: now, phaseDuration: 1500
        ), 0)
        // A future `awaySince` (clock change) gives nothing back.
        XCTAssertEqual(AwayPolicy.remainingWhenLeft(
            remainingNow: 100, now: now, awaySince: now.addingTimeInterval(60), phaseDuration: 1500
        ), 100)
    }

    // MARK: - Coming back to a frozen session

    func testCountAsBreakResetsAfterARest() {
        let action = AwayPolicy.onReturn(
            phase: .work, behavior: .countAsBreak, wasFrozen: true,
            awayDuration: rest, restThreshold: rest, remaining: 600, breakDuration: shortBreak
        )
        XCTAssertEqual(action, .resetRested)
    }

    func testCountAsBreakResumesAfterAShortAbsence() {
        let action = AwayPolicy.onReturn(
            phase: .work, behavior: .countAsBreak, wasFrozen: true,
            awayDuration: 60, restThreshold: rest, remaining: 600, breakDuration: shortBreak
        )
        XCTAssertEqual(action, .resume(remaining: 600))
    }

    func testPauseStaysPausedAfterARest() {
        let action = AwayPolicy.onReturn(
            phase: .work, behavior: .pause, wasFrozen: true,
            awayDuration: 3600, restThreshold: rest, remaining: 600, breakDuration: shortBreak
        )
        XCTAssertEqual(action, .stayPaused)
    }

    func testPauseResumesAfterAShortAbsence() {
        let action = AwayPolicy.onReturn(
            phase: .work, behavior: .pause, wasFrozen: true,
            awayDuration: 30, restThreshold: rest, remaining: 600, breakDuration: shortBreak
        )
        XCTAssertEqual(action, .resume(remaining: 600))
    }

    func testResumeNeverEndsWorkRightAfterWake() {
        let action = AwayPolicy.onReturn(
            phase: .work, behavior: .countAsBreak, wasFrozen: true,
            awayDuration: 20, restThreshold: rest, remaining: 2, breakDuration: shortBreak
        )
        XCTAssertEqual(action, .resume(remaining: AwayPolicy.wakeGrace))
    }

    // MARK: - Coming back to a session that kept counting ("Ignora")

    func testIgnoreDoesNothingWhenPlentyOfTimeIsLeft() {
        let action = AwayPolicy.onReturn(
            phase: .work, behavior: .ignore, wasFrozen: false,
            awayDuration: 3600, restThreshold: rest, remaining: 600, breakDuration: shortBreak
        )
        XCTAssertEqual(action, .none)
    }

    func testIgnoreGivesAGraceWhenWorkIsAboutToEnd() {
        let action = AwayPolicy.onReturn(
            phase: .work, behavior: .ignore, wasFrozen: false,
            awayDuration: 30, restThreshold: rest, remaining: 3, breakDuration: shortBreak
        )
        XCTAssertEqual(action, .resume(remaining: AwayPolicy.wakeGrace))
    }

    func testWorkThatEndedWhileLockedStartsTheBreakAfterGraceWhenStillRelevant() {
        // The session ended 2 minutes ago, the break would last 5: still worth taking.
        let action = AwayPolicy.onReturn(
            phase: .work, behavior: .ignore, wasFrozen: false,
            awayDuration: 600, restThreshold: rest, remaining: -120, breakDuration: shortBreak
        )
        XCTAssertEqual(action, .resume(remaining: AwayPolicy.wakeGrace))
    }

    func testWorkThatEndedLongAgoSkipsTheBreak() {
        let action = AwayPolicy.onReturn(
            phase: .work, behavior: .ignore, wasFrozen: false,
            awayDuration: 3600, restThreshold: rest, remaining: -1800, breakDuration: shortBreak
        )
        XCTAssertEqual(action, .skipBreakRested)
    }

    // MARK: - Breaks and idle

    func testBreaksAndIdleAreLeftAlone() {
        for phase in [PomodoroPhase.idle, .shortBreak, .longBreak] {
            for behavior in AwayBehavior.allCases {
                let action = AwayPolicy.onReturn(
                    phase: phase, behavior: behavior, wasFrozen: false,
                    awayDuration: 7200, restThreshold: rest, remaining: -10, breakDuration: shortBreak
                )
                XCTAssertEqual(action, .none, "\(phase) \(behavior)")
            }
        }
    }

    func testMessages() {
        XCTAssertEqual(AwayPolicy.message(for: .resetRested), "Bentornato! Ti sei già riposato")
        XCTAssertNotNil(AwayPolicy.message(for: .stayPaused))
        XCTAssertNotNil(AwayPolicy.message(for: .skipBreakRested))
        XCTAssertNil(AwayPolicy.message(for: .none))
        XCTAssertNil(AwayPolicy.message(for: .resume(remaining: 30)))
    }

    func testBehaviorTitlesAndDefault() {
        XCTAssertEqual(AwayBehavior.defaultBehavior, .countAsBreak)
        XCTAssertEqual(AwayBehavior.pause.title, "Metti in pausa")
        XCTAssertEqual(AwayBehavior.countAsBreak.title, "Considera pausa fatta")
        XCTAssertEqual(AwayBehavior.ignore.title, "Ignora")
    }
}
