import XCTest
@testable import MaramaoCore

final class AutomationCommandTests: XCTestCase {
    private func parse(_ string: String) -> AutomationCommand? {
        guard let url = URL(string: string) else {
            XCTFail("Invalid URL literal \(string)")
            return nil
        }
        return AutomationCommand(url: url)
    }

    func testSimpleCommands() {
        XCTAssertEqual(parse("maramao://start"), .start)
        XCTAssertEqual(parse("maramao://pause"), .pause)
        XCTAssertEqual(parse("maramao://resume"), .resume)
        XCTAssertEqual(parse("maramao://toggle"), .toggle)
        XCTAssertEqual(parse("maramao://break"), .takeBreak)
        XCTAssertEqual(parse("maramao://skip"), .skip)
        XCTAssertEqual(parse("maramao://reset"), .reset)
    }

    func testModeAndPreviewKeepTheId() {
        XCTAssertEqual(parse("maramao://mode/memeWall"), .setMode("memeWall"))
        XCTAssertEqual(parse("maramao://mode/random"), .setMode("random"))
        XCTAssertEqual(parse("maramao://preview/catPile"), .preview("catPile"))
        XCTAssertEqual(parse("maramao://preset/deep"), .setPreset("deep"))
        XCTAssertEqual(parse("maramao://Preset/Classic/"), .setPreset("Classic"))
    }

    func testAlternativeSpellings() {
        XCTAssertEqual(parse("MARAMAO://START"), .start)
        XCTAssertEqual(parse("maramao://start/"), .start)
        XCTAssertEqual(parse("maramao:start"), .start)
        XCTAssertEqual(parse("maramao:///start"), .start)
        XCTAssertEqual(parse("maramao://start?source=raycast"), .start)
        XCTAssertEqual(parse("maramao:mode/sleepyCat"), .setMode("sleepyCat"))
        XCTAssertEqual(parse("maramao://Mode/walkingCat/"), .setMode("walkingCat"))
    }

    func testRejectsUnknownOrMalformed() {
        XCTAssertNil(parse("maramao://"))
        XCTAssertNil(parse("maramao://dance"))
        XCTAssertNil(parse("maramao://mode"))
        XCTAssertNil(parse("maramao://preview"))
        XCTAssertNil(parse("maramao://preset"))
        XCTAssertNil(parse("maramao://preset/long/now"))
        XCTAssertNil(parse("maramao://mode/a/b"))
        XCTAssertNil(parse("maramao://start/now"))
        XCTAssertNil(parse("https://start"))
        XCTAssertNil(parse("tomatobar://start"))
    }

    func testDocumentedURLsAllParse() {
        for template in AutomationCommand.documentedURLs {
            let url = template.replacingOccurrences(of: "<id>", with: "memeWall")
            XCTAssertNotNil(parse(url), url)
        }
    }
}
