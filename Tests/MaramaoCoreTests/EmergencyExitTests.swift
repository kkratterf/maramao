import XCTest
@testable import MaramaoCore

final class RapidClickDetectorTests: XCTestCase {
    func testFiveQuickClicksTrigger() {
        var detector = RapidClickDetector(requiredClicks: 5, window: 3)
        XCTAssertFalse(detector.registerClick(at: 10.0))
        XCTAssertFalse(detector.registerClick(at: 10.3))
        XCTAssertFalse(detector.registerClick(at: 10.6))
        XCTAssertFalse(detector.registerClick(at: 10.9))
        XCTAssertTrue(detector.registerClick(at: 11.2))
    }

    func testBurstStartsOverAfterTriggering() {
        var detector = RapidClickDetector(requiredClicks: 3, window: 2)
        XCTAssertFalse(detector.registerClick(at: 0))
        XCTAssertFalse(detector.registerClick(at: 0.1))
        XCTAssertTrue(detector.registerClick(at: 0.2))
        XCTAssertTrue(detector.clicks.isEmpty)
        XCTAssertFalse(detector.registerClick(at: 0.3))
        XCTAssertFalse(detector.registerClick(at: 0.4))
        XCTAssertTrue(detector.registerClick(at: 0.5))
    }

    func testSlowClicksNeverTrigger() {
        var detector = RapidClickDetector(requiredClicks: 5, window: 3)
        for i in 0..<20 {
            XCTAssertFalse(detector.registerClick(at: Double(i) * 1.0))
        }
    }

    func testOldClicksFallOutOfTheWindow() {
        var detector = RapidClickDetector(requiredClicks: 3, window: 1)
        XCTAssertFalse(detector.registerClick(at: 0))
        XCTAssertFalse(detector.registerClick(at: 0.5))
        // The first click is now older than the window.
        XCTAssertFalse(detector.registerClick(at: 1.2))
        XCTAssertEqual(detector.clicks, [0.5, 1.2])
        XCTAssertTrue(detector.registerClick(at: 1.4))
    }

    func testClockGoingBackwardsStartsFresh() {
        var detector = RapidClickDetector(requiredClicks: 2, window: 5)
        XCTAssertFalse(detector.registerClick(at: 100))
        XCTAssertFalse(detector.registerClick(at: 50))
        XCTAssertEqual(detector.clicks, [50])
        XCTAssertTrue(detector.registerClick(at: 51))
    }

    func testResetForgetsClicks() {
        var detector = RapidClickDetector(requiredClicks: 2, window: 5)
        XCTAssertFalse(detector.registerClick(at: 1))
        detector.reset()
        XCTAssertFalse(detector.registerClick(at: 2))
        XCTAssertTrue(detector.registerClick(at: 3))
    }

    func testSingleClickConfiguration() {
        var detector = RapidClickDetector(requiredClicks: 0, window: 1)
        XCTAssertEqual(detector.requiredClicks, 1)
        XCTAssertTrue(detector.registerClick(at: 1))
    }
}

final class BreakWatchdogTests: XCTestCase {
    private let end = Date(timeIntervalSinceReferenceDate: 1_000_000)

    func testNotOverdueBeforeOrRightAtTheEnd() {
        XCTAssertFalse(BreakWatchdog.isOverdue(now: end.addingTimeInterval(-60), endDate: end))
        XCTAssertFalse(BreakWatchdog.isOverdue(now: end, endDate: end))
    }

    func testNotOverdueWithinGrace() {
        XCTAssertFalse(BreakWatchdog.isOverdue(now: end.addingTimeInterval(29), endDate: end, grace: 30))
        XCTAssertFalse(BreakWatchdog.isOverdue(now: end.addingTimeInterval(30), endDate: end, grace: 30))
    }

    func testOverdueAfterGrace() {
        XCTAssertTrue(BreakWatchdog.isOverdue(now: end.addingTimeInterval(30.5), endDate: end, grace: 30))
        XCTAssertTrue(BreakWatchdog.isOverdue(now: end.addingTimeInterval(3600), endDate: end))
    }

    func testNegativeGraceIsTreatedAsZero() {
        XCTAssertTrue(BreakWatchdog.isOverdue(now: end.addingTimeInterval(1), endDate: end, grace: -10))
        XCTAssertFalse(BreakWatchdog.isOverdue(now: end, endDate: end, grace: -10))
    }
}
