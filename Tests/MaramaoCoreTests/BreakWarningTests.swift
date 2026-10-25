import XCTest
@testable import MaramaoCore

final class BreakWarningTests: XCTestCase {
    private let work: TimeInterval = 25 * 60

    func testWarnsOnceWhenCrossingLeadTime() {
        var warning = BreakWarning(leadTime: 60)
        XCTAssertFalse(warning.shouldWarn(phase: .work, isPaused: false, remaining: 61, phaseDuration: work))
        XCTAssertTrue(warning.shouldWarn(phase: .work, isPaused: false, remaining: 60, phaseDuration: work))
        XCTAssertTrue(warning.hasWarned)
        XCTAssertFalse(warning.shouldWarn(phase: .work, isPaused: false, remaining: 59.75, phaseDuration: work))
        XCTAssertFalse(warning.shouldWarn(phase: .work, isPaused: false, remaining: 10, phaseDuration: work))
    }

    func testFiresOnFirstTickBelowThresholdEvenIfTickSkippedExactValue() {
        var warning = BreakWarning(leadTime: 30)
        XCTAssertFalse(warning.shouldWarn(phase: .work, isPaused: false, remaining: 30.1, phaseDuration: work))
        XCTAssertTrue(warning.shouldWarn(phase: .work, isPaused: false, remaining: 29.85, phaseDuration: work))
    }

    func testOffNeverWarns() {
        var warning = BreakWarning(leadTime: 0)
        XCTAssertFalse(warning.isEnabled)
        for remaining in stride(from: 120.0, through: 0.25, by: -0.25) {
            XCTAssertFalse(warning.shouldWarn(phase: .work, isPaused: false, remaining: remaining, phaseDuration: work))
        }
    }

    func testNoWarningDuringBreaksOrIdle() {
        var warning = BreakWarning(leadTime: 60)
        XCTAssertFalse(warning.shouldWarn(phase: .shortBreak, isPaused: false, remaining: 30, phaseDuration: 300))
        XCTAssertFalse(warning.shouldWarn(phase: .longBreak, isPaused: false, remaining: 30, phaseDuration: 900))
        XCTAssertFalse(warning.shouldWarn(phase: .idle, isPaused: false, remaining: 30, phaseDuration: 0))
        XCTAssertFalse(warning.hasWarned)
    }

    func testNoWarningWhilePausedButWarnsAfterResume() {
        var warning = BreakWarning(leadTime: 60)
        XCTAssertFalse(warning.shouldWarn(phase: .work, isPaused: true, remaining: 45, phaseDuration: work))
        XCTAssertFalse(warning.hasWarned)
        XCTAssertTrue(warning.shouldWarn(phase: .work, isPaused: false, remaining: 45, phaseDuration: work))
    }

    func testNoWarningWhenSessionIsNotLongerThanLeadTime() {
        var warning = BreakWarning(leadTime: 60)
        XCTAssertFalse(warning.shouldWarn(phase: .work, isPaused: false, remaining: 60, phaseDuration: 60))
        XCTAssertFalse(warning.shouldWarn(phase: .work, isPaused: false, remaining: 30, phaseDuration: 45))
        XCTAssertTrue(warning.shouldWarn(phase: .work, isPaused: false, remaining: 60, phaseDuration: 120))
    }

    func testNoWarningAtZeroRemaining() {
        var warning = BreakWarning(leadTime: 60)
        XCTAssertFalse(warning.shouldWarn(phase: .work, isPaused: false, remaining: 0, phaseDuration: work))
    }

    func testResetAllowsWarningInNextSession() {
        var warning = BreakWarning(leadTime: 120)
        XCTAssertTrue(warning.shouldWarn(phase: .work, isPaused: false, remaining: 100, phaseDuration: work))
        warning.reset()
        XCTAssertFalse(warning.hasWarned)
        XCTAssertTrue(warning.shouldWarn(phase: .work, isPaused: false, remaining: 119, phaseDuration: work))
    }

    func testAnnouncedSecondsSnapsToLeadTimeOrUsesRealRemaining() {
        let warning = BreakWarning(leadTime: 60)
        XCTAssertEqual(warning.announcedSeconds(remaining: 60), 60)
        XCTAssertEqual(warning.announcedSeconds(remaining: 59.8), 60)
        XCTAssertEqual(warning.announcedSeconds(remaining: 58.1), 60)
        XCTAssertEqual(warning.announcedSeconds(remaining: 12.2), 13)
        XCTAssertEqual(warning.announcedSeconds(remaining: 0.1), 1)
    }

    func testMessages() {
        XCTAssertEqual(BreakWarning.message(seconds: 60), "Miao, tra un minuto pausa")
        XCTAssertEqual(BreakWarning.message(seconds: 120), "Miao, tra 2 minuti pausa")
        XCTAssertEqual(BreakWarning.message(seconds: 30), "Miao, tra 30 secondi pausa")
        XCTAssertEqual(BreakWarning.message(seconds: 90), "Miao, tra 90 secondi pausa")
        XCTAssertEqual(BreakWarning.message(seconds: 1), "Miao, tra un secondo pausa")
        XCTAssertEqual(BreakWarning.message(seconds: 0), "Miao, tra un secondo pausa")
    }

    func testOptionLabels() {
        XCTAssertEqual(BreakWarning.leadTimeOptions, [0, 30, 60, 120])
        XCTAssertEqual(BreakWarning.defaultLeadTime, 60)
        XCTAssertEqual(BreakWarning.optionLabel(seconds: 0), "Mai")
        XCTAssertEqual(BreakWarning.optionLabel(seconds: 30), "30 secondi prima")
        XCTAssertEqual(BreakWarning.optionLabel(seconds: 60), "1 minuto prima")
        XCTAssertEqual(BreakWarning.optionLabel(seconds: 120), "2 minuti prima")
    }
}
