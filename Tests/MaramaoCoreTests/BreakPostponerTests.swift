import XCTest
@testable import MaramaoCore

final class BreakPostponerTests: XCTestCase {
    private let inCall = BusySignals(microphoneInUse: true)

    func testBusySignals() {
        XCTAssertFalse(BusySignals.idle.isBusy)
        XCTAssertTrue(BusySignals(microphoneInUse: true).isBusy)
        XCTAssertTrue(BusySignals(cameraInUse: true).isBusy)
        XCTAssertTrue(BusySignals(presenting: true).isBusy)
    }

    func testStartsTheBreakWhenNotBusy() {
        var postponer = BreakPostponer()
        XCTAssertEqual(postponer.decide(busy: .idle), .startBreak)
        XCTAssertFalse(postponer.isPostponing)
    }

    func testStartsTheBreakWhenDisabled() {
        var postponer = BreakPostponer(isEnabled: false)
        XCTAssertEqual(postponer.decide(busy: inCall), .startBreak)
    }

    func testPostponesOneMinuteAtATimeAndAnnouncesOnce() {
        var postponer = BreakPostponer(maxPostpone: 600)
        XCTAssertEqual(postponer.decide(busy: inCall), .postpone(seconds: 60, announce: true))
        XCTAssertEqual(postponer.decide(busy: inCall), .postpone(seconds: 60, announce: false))
        XCTAssertEqual(postponer.postponed, 120)
        XCTAssertTrue(postponer.isPostponing)
    }

    func testStopsAtTheMaximum() {
        var postponer = BreakPostponer(maxPostpone: 600)
        for _ in 0..<10 {
            guard case .postpone = postponer.decide(busy: inCall) else {
                return XCTFail("should postpone up to 10 minutes")
            }
        }
        XCTAssertEqual(postponer.postponed, 600)
        XCTAssertEqual(postponer.decide(busy: inCall), .startBreak)
    }

    func testCallEndingStartsTheBreak() {
        var postponer = BreakPostponer(maxPostpone: 600)
        _ = postponer.decide(busy: inCall)
        XCTAssertEqual(postponer.decide(busy: .idle), .startBreak)
    }

    func testWaitsForeverWithoutMaximum() {
        var postponer = BreakPostponer(maxPostpone: 0)
        XCTAssertTrue(postponer.waitsForever)
        for _ in 0..<200 {
            guard case .postpone = postponer.decide(busy: BusySignals(presenting: true)) else {
                return XCTFail("should keep waiting")
            }
        }
    }

    func testResetAllowsANewAnnouncement() {
        var postponer = BreakPostponer(maxPostpone: 120)
        _ = postponer.decide(busy: inCall)
        _ = postponer.decide(busy: inCall)
        XCTAssertEqual(postponer.decide(busy: inCall), .startBreak)
        postponer.reset()
        XCTAssertEqual(postponer.postponed, 0)
        XCTAssertEqual(postponer.decide(busy: inCall), .postpone(seconds: 60, announce: true))
    }

    func testLabels() {
        XCTAssertEqual(BreakPostponer.maxLabel(minutes: 0), "Aspetta sempre")
        XCTAssertEqual(BreakPostponer.maxLabel(minutes: 10), "Al massimo 10 min")
        XCTAssertTrue(BreakPostponer.maxMinutesOptions.contains(BreakPostponer.defaultMaxMinutes))
        XCTAssertEqual(BreakPostponer.announcement, "Ti aspetto dopo la call 🐈")
    }
}

final class PresentationDetectorTests: XCTestCase {
    private let main = CGRect(x: 0, y: 0, width: 1512, height: 982)
    private let external = CGRect(x: 1512, y: -200, width: 2560, height: 1440)

    func testWindowCoveringAScreenCounts() {
        XCTAssertTrue(PresentationDetector.coversAScreen(windows: [main], screens: [main, external]))
        XCTAssertTrue(PresentationDetector.coversAScreen(
            windows: [CGRect(x: 1512, y: -199, width: 2559, height: 1440)],
            screens: [main, external]
        ))
    }

    func testRegularWindowsDoNotCount() {
        let windows = [
            CGRect(x: 0, y: 25, width: 1512, height: 957), // maximised below the menu bar
            CGRect(x: 100, y: 100, width: 800, height: 600),
            CGRect(x: 0, y: 0, width: 0, height: 0),
        ]
        XCTAssertFalse(PresentationDetector.coversAScreen(windows: windows, screens: [main, external]))
        XCTAssertFalse(PresentationDetector.coversAScreen(windows: [], screens: [main]))
    }

    func testKnownApps() {
        XCTAssertTrue(PresentationDetector.isPresentationApp(bundleID: "com.apple.iWork.Keynote"))
        XCTAssertTrue(PresentationDetector.isPresentationApp(bundleID: "us.zoom.xos"))
        XCTAssertFalse(PresentationDetector.isPresentationApp(bundleID: "com.apple.dt.Xcode"))
        XCTAssertFalse(PresentationDetector.isPresentationApp(bundleID: nil))
    }
}
