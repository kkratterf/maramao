import XCTest
@testable import MaramaoCore

final class AvailabilityTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Rome")!
        return c
    }()

    /// 2026-10-26 is a Monday.
    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    private let officeHours = WorkingHours(isEnabled: true, weekdays: [2, 3, 4, 5, 6], startMinute: 9 * 60, endMinute: 18 * 60)

    // MARK: - WorkingHours.contains

    func testDisabledHoursAlwaysContain() {
        let hours = WorkingHours(isEnabled: false)
        XCTAssertTrue(hours.contains(date(2026, 10, 25, 3), calendar: calendar))
        XCTAssertTrue(hours.contains(date(2026, 10, 26, 23, 59), calendar: calendar))
    }

    func testOfficeHoursOnWeekdays() {
        XCTAssertTrue(officeHours.contains(date(2026, 10, 26, 9, 0), calendar: calendar))
        XCTAssertTrue(officeHours.contains(date(2026, 10, 26, 17, 59), calendar: calendar))
        XCTAssertFalse(officeHours.contains(date(2026, 10, 26, 18, 0), calendar: calendar))
        XCTAssertFalse(officeHours.contains(date(2026, 10, 26, 8, 59), calendar: calendar))
        XCTAssertFalse(officeHours.contains(date(2026, 10, 26, 21, 0), calendar: calendar))
    }

    func testWeekendIsOutside() {
        XCTAssertFalse(officeHours.contains(date(2026, 10, 24, 11), calendar: calendar)) // Saturday
        XCTAssertFalse(officeHours.contains(date(2026, 10, 25, 11), calendar: calendar)) // Sunday
        XCTAssertTrue(officeHours.contains(date(2026, 10, 30, 11), calendar: calendar)) // Friday
    }

    func testOvernightHoursBelongToTheStartDay() {
        // Friday 22:00 to 02:00.
        let night = WorkingHours(isEnabled: true, weekdays: [6], startMinute: 22 * 60, endMinute: 2 * 60)
        XCTAssertTrue(night.contains(date(2026, 10, 30, 23), calendar: calendar))
        XCTAssertTrue(night.contains(date(2026, 10, 31, 1, 30), calendar: calendar)) // Saturday early morning
        XCTAssertFalse(night.contains(date(2026, 10, 31, 2, 0), calendar: calendar))
        XCTAssertFalse(night.contains(date(2026, 10, 31, 23), calendar: calendar)) // Saturday night
        XCTAssertFalse(night.contains(date(2026, 10, 30, 1), calendar: calendar)) // Thursday night
    }

    func testMinutesAreClamped() {
        let hours = WorkingHours(isEnabled: true, startMinute: -5, endMinute: 5000)
        XCTAssertEqual(hours.startMinute, 0)
        XCTAssertEqual(hours.endMinute, 24 * 60 - 1)
    }

    // MARK: - WorkingHours.nextStart

    func testNextStartLaterToday() {
        XCTAssertEqual(officeHours.nextStart(onOrAfter: date(2026, 10, 26, 7), calendar: calendar), date(2026, 10, 26, 9))
        XCTAssertEqual(officeHours.nextStart(onOrAfter: date(2026, 10, 26, 9), calendar: calendar), date(2026, 10, 26, 9))
    }

    func testNextStartSkipsWeekend() {
        XCTAssertEqual(officeHours.nextStart(onOrAfter: date(2026, 10, 30, 10), calendar: calendar), date(2026, 11, 2, 9))
    }

    func testNextStartWithNoDays() {
        let none = WorkingHours(isEnabled: true, weekdays: [])
        XCTAssertNil(none.nextStart(onOrAfter: date(2026, 10, 26), calendar: calendar))
        // Disabled hours ignore the days.
        let disabled = WorkingHours(isEnabled: false, weekdays: [])
        XCTAssertEqual(disabled.nextStart(onOrAfter: date(2026, 10, 25, 10), calendar: calendar), date(2026, 10, 26, 9))
    }

    // MARK: - SnoozeOption

    func testShortSnoozes() {
        let now = date(2026, 10, 26, 10, 15)
        XCTAssertEqual(SnoozeOption.thirtyMinutes.resumeDate(from: now, calendar: calendar), date(2026, 10, 26, 10, 45))
        XCTAssertEqual(SnoozeOption.oneHour.resumeDate(from: now, calendar: calendar), date(2026, 10, 26, 11, 15))
        XCTAssertEqual(SnoozeOption.twoHours.resumeDate(from: now, calendar: calendar), date(2026, 10, 26, 12, 15))
        XCTAssertTrue(SnoozeOption.oneHour.resumesWork)
        XCTAssertFalse(SnoozeOption.untilTomorrow.resumesWork)
    }

    func testUntilTomorrowUsesNextWorkingDay() {
        XCTAssertEqual(
            SnoozeOption.untilTomorrow.resumeDate(from: date(2026, 10, 26, 16), calendar: calendar, workingHours: officeHours),
            date(2026, 10, 27, 9)
        )
        // Friday afternoon: back on Monday.
        XCTAssertEqual(
            SnoozeOption.untilTomorrow.resumeDate(from: date(2026, 10, 30, 16), calendar: calendar, workingHours: officeHours),
            date(2026, 11, 2, 9)
        )
        // Early on Tuesday: still tomorrow, not today at 9.
        XCTAssertEqual(
            SnoozeOption.untilTomorrow.resumeDate(from: date(2026, 10, 27, 1), calendar: calendar, workingHours: officeHours),
            date(2026, 10, 28, 9)
        )
    }

    func testUntilTomorrowWithoutWorkingHours() {
        let off = WorkingHours(isEnabled: false, startMinute: 8 * 60 + 30)
        XCTAssertEqual(
            SnoozeOption.untilTomorrow.resumeDate(from: date(2026, 10, 30, 16), calendar: calendar, workingHours: off),
            date(2026, 10, 31, 8, 30)
        )
        let noDays = WorkingHours(isEnabled: true, weekdays: [], startMinute: 10 * 60)
        XCTAssertEqual(
            SnoozeOption.untilTomorrow.resumeDate(from: date(2026, 10, 30, 16), calendar: calendar, workingHours: noDays),
            date(2026, 10, 31, 10)
        )
    }

    func testUntilTomorrowAcrossDSTChange() {
        // Clocks go back on 25 Oct 2026 in Rome: 9:00 is still 9:00 local time.
        XCTAssertEqual(
            SnoozeOption.untilTomorrow.resumeDate(from: date(2026, 10, 24, 22), calendar: calendar),
            date(2026, 10, 25, 9)
        )
    }

    // MARK: - Text

    func testUntilText() {
        let now = date(2026, 10, 26, 10)
        XCTAssertEqual(AvailabilityText.until(date(2026, 10, 26, 10, 30), now: now, calendar: calendar), "fino alle 10:30")
        XCTAssertEqual(AvailabilityText.until(date(2026, 10, 27, 9), now: now, calendar: calendar), "fino a domani alle 9:00")
        XCTAssertEqual(AvailabilityText.until(date(2026, 10, 30, 9), now: now, calendar: calendar), "fino a venerdì alle 9:00")
        XCTAssertEqual(AvailabilityText.until(date(2026, 11, 9, 9), now: now, calendar: calendar), "fino al 9/11 alle 9:00")
        XCTAssertEqual(AvailabilityText.until(date(2026, 10, 27, 1, 5), now: now, calendar: calendar), "fino a domani all'1:05")
    }

    func testClockAndWeekdays() {
        XCTAssertEqual(AvailabilityText.clock(minute: 9 * 60), "9:00")
        XCTAssertEqual(AvailabilityText.clock(minute: 18 * 60 + 5), "18:05")
        XCTAssertEqual(AvailabilityText.clock(date(2026, 10, 26, 7, 45), calendar: calendar), "7:45")
        XCTAssertEqual(AvailabilityText.weekdayName(2), "lunedì")
        XCTAssertEqual(AvailabilityText.weekdayName(1), "domenica")
        XCTAssertEqual(WorkingHours.weekdaysMondayFirst.map(AvailabilityText.weekdayInitial).joined(), "LMMGVSD")
    }

    func testSummary() {
        XCTAssertEqual(AvailabilityText.summary(officeHours), "lun, mar, mer, gio, ven · 9:00–18:00")
        XCTAssertEqual(AvailabilityText.summary(WorkingHours(isEnabled: true, weekdays: [])), "Nessun giorno selezionato")
    }

    func testWorkingHoursCodable() throws {
        let data = try JSONEncoder().encode(officeHours)
        XCTAssertEqual(try JSONDecoder().decode(WorkingHours.self, from: data), officeHours)
    }
}
