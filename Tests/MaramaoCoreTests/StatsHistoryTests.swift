import XCTest
@testable import MaramaoCore

final class StatsHistoryTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Rome")!
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    func testRangeCoversSevenOrThirtyDays() {
        XCTAssertEqual(StatsRange.week.days, 7)
        XCTAssertEqual(StatsRange.month.days, 30)
        XCTAssertEqual(StatsRange.allCases, [.week, .month])
    }

    func testBestDayPicksMostPomodori() {
        var stats = PomodoroStats()
        for _ in 0..<2 { stats.recordWork(completed: true, focusSeconds: 1500, at: date(2026, 10, 20), calendar: calendar) }
        for _ in 0..<5 { stats.recordWork(completed: true, focusSeconds: 1500, at: date(2026, 10, 22), calendar: calendar) }
        for _ in 0..<3 { stats.recordWork(completed: true, focusSeconds: 1500, at: date(2026, 10, 26), calendar: calendar) }
        let best = stats.bestDay(ofLast: 30, endingAt: date(2026, 10, 26), calendar: calendar)
        XCTAssertEqual(best?.day, "2026-10-22")
        XCTAssertEqual(best?.workSessions, 5)
    }

    func testBestDayPrefersTheMostRecentOnATie() {
        var stats = PomodoroStats()
        stats.recordWork(completed: true, focusSeconds: 1500, at: date(2026, 10, 20), calendar: calendar)
        stats.recordWork(completed: true, focusSeconds: 1500, at: date(2026, 10, 24), calendar: calendar)
        let best = stats.bestDay(ofLast: 30, endingAt: date(2026, 10, 26), calendar: calendar)
        XCTAssertEqual(best?.day, "2026-10-24")
    }

    func testBestDayIgnoresDaysOutsideTheRangeAndDaysWithoutPomodori() {
        var stats = PomodoroStats()
        for _ in 0..<9 { stats.recordWork(completed: true, focusSeconds: 1500, at: date(2026, 9, 1), calendar: calendar) }
        stats.recordBreak(completed: true, mode: "catPile", at: date(2026, 10, 25), calendar: calendar)
        XCTAssertNil(stats.bestDay(ofLast: 7, endingAt: date(2026, 10, 26), calendar: calendar))
        // 1 September is more than 30 days before 26 October, so it stays out.
        XCTAssertNil(stats.bestDay(ofLast: 30, endingAt: date(2026, 10, 26), calendar: calendar))
    }

    func testActiveDaysCountsDaysWithPomodori() {
        var stats = PomodoroStats()
        stats.recordWork(completed: true, focusSeconds: 1500, at: date(2026, 10, 24), calendar: calendar)
        stats.recordWork(completed: true, focusSeconds: 1500, at: date(2026, 10, 26), calendar: calendar)
        stats.recordWork(completed: false, focusSeconds: 600, at: date(2026, 10, 25), calendar: calendar)
        XCTAssertEqual(stats.activeDays(ofLast: 7, endingAt: date(2026, 10, 26), calendar: calendar), 2)
        XCTAssertEqual(stats.activeDays(ofLast: 1, endingAt: date(2026, 10, 25), calendar: calendar), 0)
    }

    func testCSVHasAHeaderAndOneSortedLinePerDay() {
        var stats = PomodoroStats()
        stats.recordWork(completed: true, focusSeconds: 25 * 60, at: date(2026, 10, 26), calendar: calendar)
        stats.recordBreak(completed: true, mode: "catPile", at: date(2026, 10, 26), calendar: calendar)
        stats.recordBreak(completed: false, mode: "memeWall", at: date(2026, 10, 26), calendar: calendar)
        stats.recordEmergencyExit(at: date(2026, 10, 26), calendar: calendar)
        stats.recordSnooze(at: date(2026, 10, 24), calendar: calendar)

        let csv = StatsCSV.export(stats)
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        XCTAssertEqual(lines.first, StatsCSV.header)
        XCTAssertEqual(lines.count, 4, "header, two days and the trailing newline")
        XCTAssertEqual(lines[1], "2026-10-24,0,0,0,0,1,0")
        XCTAssertEqual(lines[2], "2026-10-26,1,25,1,1,0,1")
        XCTAssertEqual(lines.last, "")
    }

    func testCSVOfEmptyHistoryIsJustTheHeader() {
        XCTAssertEqual(StatsCSV.export(PomodoroStats()), StatsCSV.header + "\n")
    }

    func testCSVFileNameCarriesTheDay() {
        XCTAssertEqual(StatsCSV.fileName(for: date(2026, 10, 26), calendar: calendar), "maramao-stats-2026-10-26.csv")
    }
}
