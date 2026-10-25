import XCTest
@testable import MaramaoCore

final class ShortcutAutomationTests: XCTestCase {
    func testTriggersForPhaseChanges() {
        XCTAssertEqual(AutomationTrigger.triggers(from: .idle, to: .work), [.workStarts])
        XCTAssertEqual(AutomationTrigger.triggers(from: .work, to: .shortBreak), [.breakStarts])
        XCTAssertEqual(AutomationTrigger.triggers(from: .work, to: .longBreak), [.breakStarts])
        XCTAssertEqual(AutomationTrigger.triggers(from: .shortBreak, to: .idle), [.breakEnds])
        XCTAssertEqual(AutomationTrigger.triggers(from: .longBreak, to: .work), [.breakEnds, .workStarts])
        XCTAssertEqual(AutomationTrigger.triggers(from: .work, to: .idle), [])
        XCTAssertEqual(AutomationTrigger.triggers(from: .work, to: .work), [])
        XCTAssertEqual(AutomationTrigger.triggers(from: .shortBreak, to: .shortBreak), [])
        XCTAssertEqual(AutomationTrigger.triggers(from: .idle, to: .shortBreak), [.breakStarts])
    }

    func testTitlesAreItalian() {
        XCTAssertEqual(AutomationTrigger.breakStarts.title, "Quando inizia la pausa")
        XCTAssertEqual(AutomationTrigger.allCases.count, 3)
    }

    func testRunArguments() {
        XCTAssertEqual(ShortcutCommand.runArguments(name: "Pausa Spotify"), ["run", "Pausa Spotify", "--input-path", "-"])
        XCTAssertEqual(ShortcutCommand.runArguments(name: "  Luci soffuse \n"), ["run", "Luci soffuse", "--input-path", "-"])
        XCTAssertNil(ShortcutCommand.runArguments(name: ""))
        XCTAssertNil(ShortcutCommand.runArguments(name: "   "))
        XCTAssertEqual(ShortcutCommand.executablePath, "/usr/bin/shortcuts")
    }

    func testInputText() {
        XCTAssertEqual(
            ShortcutCommand.inputText(trigger: .breakStarts, phase: .shortBreak, mode: "walkingCat"),
            #"{"event":"breakStarts","mode":"walkingCat","phase":"shortBreak"}"#
        )
        XCTAssertEqual(
            ShortcutCommand.inputText(trigger: .workStarts, phase: .work, mode: nil),
            #"{"event":"workStarts","phase":"work"}"#
        )
        XCTAssertEqual(
            ShortcutCommand.inputText(trigger: .breakEnds, phase: .idle, mode: ""),
            #"{"event":"breakEnds","phase":"idle"}"#
        )
    }

    func testInputTextIsValidJSONEvenWithOddCharacters() throws {
        let text = ShortcutCommand.inputText(trigger: .breakEnds, phase: .work, mode: "a\"b\\c\nd\u{1}")
        let object = try JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: String]
        XCTAssertEqual(object?["mode"], "a\"b\\c\nd\u{1}")
        XCTAssertEqual(object?["event"], "breakEnds")
        XCTAssertEqual(object?["phase"], "work")
    }

    func testParseList() {
        let output = "Pausa Spotify\n\nluci soffuse\nBlocca schermo\nPausa Spotify\n  \n"
        XCTAssertEqual(ShortcutCommand.parseList(output), ["Blocca schermo", "luci soffuse", "Pausa Spotify"])
        XCTAssertEqual(ShortcutCommand.parseList(""), [])
    }
}
