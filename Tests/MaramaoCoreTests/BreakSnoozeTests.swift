import XCTest
@testable import MaramaoCore

final class BreakSnoozeTests: XCTestCase {
    func testDefaults() {
        let policy = BreakSnoozePolicy()
        XCTAssertEqual(policy.minutes, 3)
        XCTAssertEqual(policy.dailyLimit, 3)
        XCTAssertEqual(policy.seconds, 180)
        XCTAssertTrue(policy.isEnabled)
        XCTAssertTrue(BreakSnoozePolicy.minuteOptions.contains(BreakSnoozePolicy.defaultMinutes))
        XCTAssertTrue(BreakSnoozePolicy.dailyLimitOptions.contains(BreakSnoozePolicy.defaultDailyLimit))
        XCTAssertEqual(BreakSnoozePolicy.minuteOptions, [1, 3, 5])
    }

    func testValuesAreClamped() {
        XCTAssertEqual(BreakSnoozePolicy(minutes: 0, dailyLimit: -2).minutes, 1)
        XCTAssertEqual(BreakSnoozePolicy(minutes: 0, dailyLimit: -2).dailyLimit, 0)
        XCTAssertFalse(BreakSnoozePolicy(minutes: 5, dailyLimit: 0).isEnabled)
    }

    func testDailyLimit() {
        let policy = BreakSnoozePolicy(minutes: 1, dailyLimit: 3)
        XCTAssertEqual(policy.snoozesLeft(usedToday: 0), 3)
        XCTAssertEqual(policy.snoozesLeft(usedToday: 2), 1)
        XCTAssertEqual(policy.snoozesLeft(usedToday: 3), 0)
        XCTAssertEqual(policy.snoozesLeft(usedToday: 9), 0)
        XCTAssertTrue(policy.canOffer(usedToday: 2, isPreview: false, strictMode: false))
        XCTAssertFalse(policy.canOffer(usedToday: 3, isPreview: false, strictMode: false))
    }

    func testNeverInPreviewsStrictModeOrWhenOff() {
        let policy = BreakSnoozePolicy()
        XCTAssertFalse(policy.canOffer(usedToday: 0, isPreview: true, strictMode: false))
        XCTAssertFalse(policy.canOffer(usedToday: 0, isPreview: false, strictMode: true))
        XCTAssertFalse(BreakSnoozePolicy(minutes: 3, dailyLimit: 0).canOffer(usedToday: 0, isPreview: false, strictMode: false))
    }

    func testOnlyDuringTheFirstHalfOfTheBreak() {
        let policy = BreakSnoozePolicy()
        XCTAssertEqual(policy.offerDuration(breakDuration: 300), 150)
        XCTAssertTrue(policy.canSnooze(usedToday: 0, isPreview: false, strictMode: false, elapsed: 0, breakDuration: 300))
        XCTAssertTrue(policy.canSnooze(usedToday: 0, isPreview: false, strictMode: false, elapsed: 149, breakDuration: 300))
        XCTAssertFalse(policy.canSnooze(usedToday: 0, isPreview: false, strictMode: false, elapsed: 150, breakDuration: 300))
        XCTAssertFalse(policy.canSnooze(usedToday: 0, isPreview: false, strictMode: false, elapsed: -1, breakDuration: 300))
        XCTAssertFalse(policy.canSnooze(usedToday: 3, isPreview: false, strictMode: false, elapsed: 10, breakDuration: 300))
    }

    func testText() {
        XCTAssertEqual(BreakSnoozeText.button(minutes: 3), "Rimanda 3 min")
        XCTAssertEqual(BreakSnoozeText.left(1), "Ancora 1 rinvio oggi")
        XCTAssertEqual(BreakSnoozeText.left(2), "Ancora 2 rinvii oggi")
        XCTAssertEqual(BreakSnoozeText.snoozed(minutes: 1), "Va bene, torno tra un minuto 🐾")
        XCTAssertEqual(BreakSnoozeText.snoozed(minutes: 5), "Va bene, torno tra 5 minuti 🐾")
        XCTAssertEqual(BreakSnoozeText.minutesLabel(1), "1 minuto")
        XCTAssertEqual(BreakSnoozeText.minutesLabel(3), "3 minuti")
        XCTAssertEqual(BreakSnoozeText.limitLabel(0), "Mai")
        XCTAssertEqual(BreakSnoozeText.limitLabel(1), "1 volta al giorno")
        XCTAssertEqual(BreakSnoozeText.limitLabel(5), "5 volte al giorno")
    }
}
