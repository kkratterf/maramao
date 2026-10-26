import XCTest
@testable import MaramaoCore

final class LogRingTests: XCTestCase {
    func testKeepsLinesInOrderBelowCapacity() {
        var ring = LogRing(capacity: 3)
        XCTAssertEqual(ring.lines, [])
        ring.append("a")
        ring.append("b")
        XCTAssertEqual(ring.lines, ["a", "b"])
    }

    func testDropsTheOldestLinesWhenFull() {
        var ring = LogRing(capacity: 3)
        for line in ["a", "b", "c", "d", "e"] { ring.append(line) }
        XCTAssertEqual(ring.lines, ["c", "d", "e"])
        for line in ["f", "g", "h"] { ring.append(line) }
        XCTAssertEqual(ring.lines, ["f", "g", "h"])
    }

    func testNeverGrowsPastItsCapacity() {
        var ring = LogRing()
        for i in 0..<1000 { ring.append("line \(i)") }
        XCTAssertEqual(ring.lines.count, LogRing.defaultCapacity)
        XCTAssertEqual(ring.lines.first, "line 800")
        XCTAssertEqual(ring.lines.last, "line 999")
    }

    func testZeroCapacityKeepsNothing() {
        var ring = LogRing(capacity: 0)
        ring.append("a")
        XCTAssertEqual(ring.lines, [])
        var negative = LogRing(capacity: -4)
        negative.append("a")
        XCTAssertEqual(negative.lines, [])
    }
}

final class BugReportTests: XCTestCase {
    private func report(log: [String] = ["10:00:00 Work started", "10:25:00 Short break started"]) -> BugReport {
        BugReport(
            appVersion: "0.2.0 (5)",
            macOS: "Version 15.1 (Build 24B83)",
            mac: "MacBookAir10,1 (arm64)",
            displays: ["1440×900 @2x (main)", "2560×1440 @1x"],
            settings: [.init("Work", "25 min"), .init("Strict mode", "off")],
            log: log
        )
    }

    func testTextListsEverySection() {
        let text = report().text
        XCTAssertTrue(text.hasPrefix("Maramao 0.2.0 (5)\n"))
        XCTAssertTrue(text.contains("macOS: Version 15.1 (Build 24B83)\n"))
        XCTAssertTrue(text.contains("Mac: MacBookAir10,1 (arm64)\n"))
        XCTAssertTrue(text.contains("Displays: 1440×900 @2x (main); 2560×1440 @1x\n"))
        XCTAssertTrue(text.contains("- Work: 25 min\n- Strict mode: off\n"))
        XCTAssertTrue(text.contains("Log (last 2 lines):\n10:00:00 Work started\n10:25:00 Short break started\n"))
    }

    func testTextSaysWhenTheLogIsEmpty() {
        XCTAssertTrue(report(log: []).text.contains("Log (last 0 lines):\n(empty)\n"))
    }

    func testIssueURLUsesTheBugForm() throws {
        let url = try XCTUnwrap(report().issueURL())
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.host, "github.com")
        XCTAssertEqual(components.path, "/kkratterf/maramao/issues/new")
        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(items["template"], "bug.yml")
        XCTAssertEqual(items["version"], "0.2.0 (5)")
        XCTAssertEqual(items["macos"], "Version 15.1 (Build 24B83), MacBookAir10,1 (arm64), 2 display(s)")
        XCTAssertEqual(items["diagnostics"], report().text)
    }

    func testIssueURLEncodesReservedCharacters() throws {
        let url = try XCTUnwrap(report(log: ["a+b & c=d #1"]).issueURL())
        XCTAssertFalse(url.absoluteString.contains("a+b"))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let diagnostics = components.queryItems?.first { $0.name == "diagnostics" }?.value
        XCTAssertTrue(diagnostics?.contains("a+b & c=d #1") ?? false)
    }

    func testIssueURLDropsTheOldestLogLinesToFit() throws {
        let log = (0..<200).map { "10:00:\($0) A fairly long log line to fill the URL quickly, number \($0)" }
        let url = try XCTUnwrap(report(log: log).issueURL(maxLength: 3000))
        XCTAssertLessThanOrEqual(url.absoluteString.count, 3000)
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let diagnostics = try XCTUnwrap(components.queryItems?.first { $0.name == "diagnostics" }?.value)
        XCTAssertTrue(diagnostics.contains("number 199"))
        XCTAssertFalse(diagnostics.contains("number 0\n"))
    }
}
