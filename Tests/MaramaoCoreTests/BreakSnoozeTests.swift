import XCTest
@testable import MaramaoCore

final class BreakSnoozeTests: XCTestCase {
    func testLedgerCountsPerDay() {
        let ledger = BreakSnoozeLedger(day: "2026-10-25", count: 2)
        XCTAssertEqual(ledger.used(on: "2026-10-25"), 2)
        XCTAssertEqual(ledger.used(on: "2026-10-26"), 0)
    }

    func testRecordingAddsOneAndRollsOverAtMidnight() {
        var ledger = BreakSnoozeLedger(day: "2026-10-25")
        ledger = ledger.recording(on: "2026-10-25")
        ledger = ledger.recording(on: "2026-10-25")
        XCTAssertEqual(ledger, BreakSnoozeLedger(day: "2026-10-25", count: 2))
        ledger = ledger.recording(on: "2026-10-26")
        XCTAssertEqual(ledger, BreakSnoozeLedger(day: "2026-10-26", count: 1))
    }

    func testLedgerNeverNegative() {
        XCTAssertEqual(BreakSnoozeLedger(day: "2026-10-25", count: -3).count, 0)
    }

    func testLedgerCodableRoundTrip() throws {
        let ledger = BreakSnoozeLedger(day: "2026-10-25", count: 3)
        let data = try JSONEncoder().encode(ledger)
        XCTAssertEqual(try JSONDecoder().decode(BreakSnoozeLedger.self, from: data), ledger)
    }

    func testCanSnoozeUntilTheDailyLimit() {
        XCTAssertTrue(BreakSnooze.canSnooze(strictMode: false, isPreview: false, usedToday: 0, dailyLimit: 3))
        XCTAssertTrue(BreakSnooze.canSnooze(strictMode: false, isPreview: false, usedToday: 2, dailyLimit: 3))
        XCTAssertFalse(BreakSnooze.canSnooze(strictMode: false, isPreview: false, usedToday: 3, dailyLimit: 3))
        XCTAssertFalse(BreakSnooze.canSnooze(strictMode: false, isPreview: false, usedToday: 9, dailyLimit: 3))
    }

    func testNeverInStrictModePreviewsOrWhenOff() {
        XCTAssertFalse(BreakSnooze.canSnooze(strictMode: true, isPreview: false, usedToday: 0, dailyLimit: 3))
        XCTAssertFalse(BreakSnooze.canSnooze(strictMode: false, isPreview: true, usedToday: 0, dailyLimit: 3))
        XCTAssertFalse(BreakSnooze.canSnooze(strictMode: false, isPreview: false, usedToday: 0, dailyLimit: 0))
    }

    func testRemaining() {
        XCTAssertEqual(BreakSnooze.remaining(usedToday: 1, dailyLimit: 3), 2)
        XCTAssertEqual(BreakSnooze.remaining(usedToday: 5, dailyLimit: 3), 0)
    }

    func testLabels() {
        XCTAssertEqual(BreakSnooze.buttonLabel(minutes: 5), "Ancora 5 minuti")
        XCTAssertEqual(BreakSnooze.buttonLabel(minutes: 1), "Ancora 1 minuto")
        XCTAssertEqual(BreakSnooze.dailyLimitLabel(0), "Mai")
        XCTAssertEqual(BreakSnooze.dailyLimitLabel(1), "1 volta al giorno")
        XCTAssertEqual(BreakSnooze.dailyLimitLabel(3), "3 volte al giorno")
        XCTAssertTrue(BreakSnooze.dailyLimitOptions.contains(BreakSnooze.defaultDailyLimit))
        XCTAssertTrue(BreakSnooze.minutesOptions.contains(BreakSnooze.defaultMinutes))
    }

    func testTheCatGetsGrumpier() {
        let lines = (1...5).map { BreakSnooze.catLine(count: $0, minutes: 5) }
        XCTAssertEqual(lines[0], "Va bene, 5 minuti. Ma solo 5 minuti. 😼")
        XCTAssertEqual(Set(lines.prefix(4)).count, 4, "each of the first snoozes gets a new line")
        XCTAssertEqual(lines[3], lines[4])
        XCTAssertEqual(BreakSnooze.catLine(count: 1, minutes: 1), "Va bene, un minuto. Ma solo un minuto. 😼")
    }
}
