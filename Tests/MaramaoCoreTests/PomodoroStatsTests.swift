import XCTest
@testable import MaramaoCore

final class PomodoroStatsTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Rome")!
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    func testRecordsWorkAndFocus() {
        var stats = PomodoroStats()
        let now = date(2026, 10, 25, 10)
        stats.recordWork(completed: true, focusSeconds: 25 * 60, at: now, calendar: calendar)
        stats.recordWork(completed: true, focusSeconds: 25 * 60, at: now, calendar: calendar)
        stats.recordWork(completed: false, focusSeconds: 10 * 60 + 30, at: now, calendar: calendar)
        let today = stats.day(now, calendar: calendar)
        XCTAssertEqual(today.day, "2026-10-25")
        XCTAssertEqual(today.workSessions, 2)
        XCTAssertEqual(today.focusMinutes, 60)
        XCTAssertEqual(today.focusSeconds, 60 * 60 + 30)
    }

    func testNegativeFocusIsIgnored() {
        var stats = PomodoroStats()
        stats.recordWork(completed: false, focusSeconds: -50, at: date(2026, 1, 1), calendar: calendar)
        XCTAssertEqual(stats.day(date(2026, 1, 1), calendar: calendar).focusSeconds, 0)
    }

    func testRecordsBreaksPerMode() {
        var stats = PomodoroStats()
        let now = date(2026, 10, 25)
        stats.recordBreak(completed: true, mode: "walkingCat", at: now, calendar: calendar)
        stats.recordBreak(completed: true, mode: "walkingCat", at: now, calendar: calendar)
        stats.recordBreak(completed: false, mode: "walkingCat", at: now, calendar: calendar)
        stats.recordBreak(completed: false, mode: "catPile", at: now, calendar: calendar)
        let today = stats.day(now, calendar: calendar)
        XCTAssertEqual(today.breaksCompleted, 2)
        XCTAssertEqual(today.breaksSkipped, 2)
        XCTAssertEqual(today.breaksTotal, 4)
        XCTAssertEqual(today.modes["walkingCat"], BreakModeCounts(completed: 2, skipped: 1))
        XCTAssertEqual(today.modes["catPile"], BreakModeCounts(completed: 0, skipped: 1))
        XCTAssertEqual(today.modes["walkingCat"]?.total, 3)
    }

    func testDayRollsOverAtLocalMidnight() {
        var stats = PomodoroStats()
        stats.recordWork(completed: true, focusSeconds: 1500, at: date(2026, 10, 25, 23, 59), calendar: calendar)
        stats.recordWork(completed: true, focusSeconds: 1500, at: date(2026, 10, 26, 0, 1), calendar: calendar)
        XCTAssertEqual(stats.day(date(2026, 10, 25), calendar: calendar).workSessions, 1)
        XCTAssertEqual(stats.day(date(2026, 10, 26), calendar: calendar).workSessions, 1)
        XCTAssertEqual(stats.days.count, 2)
    }

    func testDayKeyFollowsCalendarTimeZone() {
        // 23:30 UTC on 25 Oct is already 26 Oct in Rome (CET, UTC+1 after the DST change).
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let instant = utc.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 23, minute: 30))!
        XCTAssertEqual(PomodoroStats.key(for: instant, calendar: utc), "2026-10-25")
        XCTAssertEqual(PomodoroStats.key(for: instant, calendar: calendar), "2026-10-26")
    }

    func testEmptyDay() {
        let stats = PomodoroStats()
        let day = stats.day(date(2026, 3, 9), calendar: calendar)
        XCTAssertEqual(day.day, "2026-03-09")
        XCTAssertTrue(day.isEmpty)
    }

    func testLastDaysIncludesEmptyDaysOldestFirst() {
        var stats = PomodoroStats()
        stats.recordWork(completed: true, focusSeconds: 1500, at: date(2026, 10, 20), calendar: calendar)
        stats.recordWork(completed: true, focusSeconds: 1500, at: date(2026, 10, 25), calendar: calendar)
        stats.recordWork(completed: true, focusSeconds: 1500, at: date(2026, 10, 25), calendar: calendar)
        stats.recordWork(completed: true, focusSeconds: 1500, at: date(2026, 10, 10), calendar: calendar)
        let week = stats.lastDays(7, endingAt: date(2026, 10, 25, 18), calendar: calendar)
        XCTAssertEqual(week.map(\.day), [
            "2026-10-19", "2026-10-20", "2026-10-21", "2026-10-22", "2026-10-23", "2026-10-24", "2026-10-25",
        ])
        XCTAssertEqual(week.map(\.workSessions), [0, 1, 0, 0, 0, 0, 2])
        XCTAssertTrue(stats.lastDays(0, endingAt: date(2026, 10, 25), calendar: calendar).isEmpty)
    }

    func testLastDaysAcrossMonthAndDSTChange() {
        let days = PomodoroStats().lastDays(3, endingAt: date(2026, 3, 30, 0, 30), calendar: calendar)
        XCTAssertEqual(days.map(\.day), ["2026-03-28", "2026-03-29", "2026-03-30"])
        let newYear = PomodoroStats().lastDays(2, endingAt: date(2027, 1, 1), calendar: calendar)
        XCTAssertEqual(newYear.map(\.day), ["2026-12-31", "2027-01-01"])
    }

    func testTotalOfLastDays() {
        var stats = PomodoroStats()
        stats.recordWork(completed: true, focusSeconds: 1500, at: date(2026, 10, 24), calendar: calendar)
        stats.recordBreak(completed: true, mode: "memeWall", at: date(2026, 10, 24), calendar: calendar)
        stats.recordWork(completed: true, focusSeconds: 1500, at: date(2026, 10, 25), calendar: calendar)
        stats.recordBreak(completed: false, mode: "memeWall", at: date(2026, 10, 25), calendar: calendar)
        stats.recordBreak(completed: true, mode: "sleepyCat", at: date(2026, 10, 25), calendar: calendar)
        // Outside the window.
        stats.recordWork(completed: true, focusSeconds: 1500, at: date(2026, 10, 1), calendar: calendar)
        let week = stats.total(ofLast: 7, endingAt: date(2026, 10, 25), calendar: calendar)
        XCTAssertEqual(week.workSessions, 2)
        XCTAssertEqual(week.focusMinutes, 50)
        XCTAssertEqual(week.breaksCompleted, 2)
        XCTAssertEqual(week.breaksSkipped, 1)
        XCTAssertEqual(week.modes["memeWall"], BreakModeCounts(completed: 1, skipped: 1))
        XCTAssertEqual(week.modes["sleepyCat"], BreakModeCounts(completed: 1, skipped: 0))
    }

    func testStreakCountsConsecutiveDaysEndingToday() {
        var stats = PomodoroStats()
        for day in [21, 22, 23, 24, 25] {
            stats.recordWork(completed: true, focusSeconds: 1500, at: date(2026, 10, day), calendar: calendar)
        }
        stats.recordWork(completed: true, focusSeconds: 1500, at: date(2026, 10, 19), calendar: calendar)
        XCTAssertEqual(stats.streak(endingAt: date(2026, 10, 25, 20), calendar: calendar), 5)
    }

    func testStreakSurvivesTodayWithoutPomodoriYet() {
        var stats = PomodoroStats()
        for day in [23, 24] {
            stats.recordWork(completed: true, focusSeconds: 1500, at: date(2026, 10, day), calendar: calendar)
        }
        XCTAssertEqual(stats.streak(endingAt: date(2026, 10, 25, 9), calendar: calendar), 2)
        // Two days later the streak is broken.
        XCTAssertEqual(stats.streak(endingAt: date(2026, 10, 26, 9), calendar: calendar), 0)
    }

    func testStreakIgnoresDaysWithOnlyBreaksOrEarlyEnds() {
        var stats = PomodoroStats()
        stats.recordWork(completed: true, focusSeconds: 1500, at: date(2026, 10, 25), calendar: calendar)
        stats.recordWork(completed: false, focusSeconds: 600, at: date(2026, 10, 24), calendar: calendar)
        stats.recordBreak(completed: true, mode: "catPile", at: date(2026, 10, 24), calendar: calendar)
        stats.recordWork(completed: true, focusSeconds: 1500, at: date(2026, 10, 23), calendar: calendar)
        XCTAssertEqual(stats.streak(endingAt: date(2026, 10, 25), calendar: calendar), 1)
        XCTAssertEqual(PomodoroStats().streak(endingAt: date(2026, 10, 25), calendar: calendar), 0)
    }

    func testStreakAcrossMonthBoundary() {
        var stats = PomodoroStats()
        for d in [date(2026, 2, 27), date(2026, 2, 28), date(2026, 3, 1)] {
            stats.recordWork(completed: true, focusSeconds: 1500, at: d, calendar: calendar)
        }
        XCTAssertEqual(stats.streak(endingAt: date(2026, 3, 1), calendar: calendar), 3)
    }

    func testResetClearsEverything() {
        var stats = PomodoroStats()
        stats.recordWork(completed: true, focusSeconds: 1500, at: date(2026, 10, 25), calendar: calendar)
        stats.reset()
        XCTAssertTrue(stats.days.isEmpty)
        XCTAssertEqual(stats, PomodoroStats())
    }

    func testPruneDropsOldDays() {
        var stats = PomodoroStats()
        let now = date(2026, 10, 25)
        let old = calendar.date(byAdding: .day, value: -PomodoroStats.retentionDays, to: now)!
        let kept = calendar.date(byAdding: .day, value: -(PomodoroStats.retentionDays - 1), to: now)!
        stats.recordWork(completed: true, focusSeconds: 1500, at: old, calendar: calendar)
        stats.recordWork(completed: true, focusSeconds: 1500, at: kept, calendar: calendar)
        stats.recordWork(completed: true, focusSeconds: 1500, at: now, calendar: calendar)
        stats.prune(now: now, calendar: calendar)
        XCTAssertEqual(stats.days.count, 2)
        XCTAssertNil(stats.days[PomodoroStats.key(for: old, calendar: calendar)])
        XCTAssertNotNil(stats.days[PomodoroStats.key(for: kept, calendar: calendar)])
    }

    func testCodableRoundTrip() throws {
        var stats = PomodoroStats()
        stats.recordWork(completed: true, focusSeconds: 1500, at: date(2026, 10, 25), calendar: calendar)
        stats.recordBreak(completed: false, mode: "walkingCat", at: date(2026, 10, 25), calendar: calendar)
        let data = try JSONEncoder().encode(stats)
        let decoded = try JSONDecoder().decode(PomodoroStats.self, from: data)
        XCTAssertEqual(decoded, stats)
    }

    func testTodayLine() {
        var today = DayStats(day: "2026-10-25", workSessions: 4, breaksCompleted: 3, breaksSkipped: 1)
        XCTAssertEqual(StatsText.todayLine(today: today, streak: 5), "Oggi: 🍅 4 · 🐈 3/4 pause rispettate · 🔥 5 giorni")
        XCTAssertEqual(StatsText.todayLine(today: today, streak: 1), "Oggi: 🍅 4 · 🐈 3/4 pause rispettate · 🔥 1 giorno")
        today.breaksCompleted = 1
        today.breaksSkipped = 0
        XCTAssertEqual(StatsText.todayLine(today: today, streak: 0), "Oggi: 🍅 4 · 🐈 1/1 pausa rispettata")
        XCTAssertEqual(StatsText.todayLine(today: DayStats(day: "x"), streak: 0), "Oggi: 🍅 0")
    }

    func testDurationText() {
        XCTAssertEqual(StatsText.duration(minutes: 0), "0 min")
        XCTAssertEqual(StatsText.duration(minutes: 45), "45 min")
        XCTAssertEqual(StatsText.duration(minutes: 120), "2 h")
        XCTAssertEqual(StatsText.duration(minutes: 65), "1 h 05 min")
        XCTAssertEqual(StatsText.duration(minutes: -3), "0 min")
    }

    func testEmergencyExitsAreCountedAndSummed() {
        var stats = PomodoroStats()
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        stats.recordEmergencyExit(at: now, calendar: calendar)
        stats.recordEmergencyExit(at: now, calendar: calendar)
        XCTAssertEqual(stats.day(now, calendar: calendar).emergencyExits, 2)
        let yesterday = now.addingTimeInterval(-86_400)
        stats.recordEmergencyExit(at: yesterday, calendar: calendar)
        XCTAssertEqual(stats.total(ofLast: 7, endingAt: now, calendar: calendar).emergencyExits, 3)
    }

    func testDecodesStatsSavedWithoutEmergencyExits() throws {
        let json = """
        {"days":{"2026-10-20":{"day":"2026-10-20","workSessions":3,"focusSeconds":4500,\
        "breaksCompleted":2,"breaksSkipped":1,"modes":{"catPile":{"completed":2,"skipped":1}}}}}
        """
        let stats = try JSONDecoder().decode(PomodoroStats.self, from: Data(json.utf8))
        let day = try XCTUnwrap(stats.days["2026-10-20"])
        XCTAssertEqual(day.workSessions, 3)
        XCTAssertEqual(day.breaksSkipped, 1)
        XCTAssertEqual(day.emergencyExits, 0)
        XCTAssertEqual(day.breaksSnoozed, 0)
        XCTAssertEqual(day.modes["catPile"], BreakModeCounts(completed: 2, skipped: 1))
    }

    func testSnoozesAreCountedPerDayAndSummed() {
        var stats = PomodoroStats()
        let now = date(2026, 10, 25, 10)
        stats.recordSnooze(at: now, calendar: calendar)
        stats.recordSnooze(at: now, calendar: calendar)
        stats.recordSnooze(at: date(2026, 10, 24, 10), calendar: calendar)
        let today = stats.day(now, calendar: calendar)
        XCTAssertEqual(today.breaksSnoozed, 2)
        XCTAssertEqual(today.breaksTotal, 0, "A snooze is not a finished break")
        XCTAssertFalse(today.isEmpty)
        XCTAssertEqual(stats.day(date(2026, 10, 26, 10), calendar: calendar).breaksSnoozed, 0, "The count starts again every day")
        XCTAssertEqual(stats.total(ofLast: 7, endingAt: now, calendar: calendar).breaksSnoozed, 3)
    }
}
