import XCTest
@testable import MaramaoCore

final class BreakAccessibilityTests: XCTestCase {
    func testMotionPreference() {
        XCTAssertEqual(MotionPreference.defaultPreference, .system)
        XCTAssertTrue(MotionPreference.system.reducesMotion(systemReduceMotion: true))
        XCTAssertFalse(MotionPreference.system.reducesMotion(systemReduceMotion: false))
        XCTAssertTrue(MotionPreference.reduced.reducesMotion(systemReduceMotion: false))
        XCTAssertFalse(MotionPreference.full.reducesMotion(systemReduceMotion: true))
        XCTAssertEqual(MotionPreference.allCases.map(\.label), ["Come il sistema", "Ridotte", "Complete"])
        XCTAssertEqual(MotionPreference(rawValue: "reduced"), .reduced)
    }

    func testDurations() {
        XCTAssertEqual(BreakSpeech.duration(seconds: 300), "5 minuti")
        XCTAssertEqual(BreakSpeech.duration(seconds: 60), "1 minuto")
        XCTAssertEqual(BreakSpeech.duration(seconds: 30), "30 secondi")
        XCTAssertEqual(BreakSpeech.duration(seconds: 1), "1 secondo")
        XCTAssertEqual(BreakSpeech.duration(seconds: 150), "2 minuti e 30 secondi")
        XCTAssertEqual(BreakSpeech.duration(seconds: 61), "1 minuto e 1 secondo")
        XCTAssertEqual(BreakSpeech.duration(seconds: -5), "0 secondi")
    }

    func testBreakStarted() {
        XCTAssertEqual(BreakSpeech.breakStarted(duration: 300, modeTitle: "Muro di meme"), "Pausa: 5 minuti. Muro di meme.")
        XCTAssertEqual(BreakSpeech.breakStarted(duration: 899.6, modeTitle: nil), "Pausa: 15 minuti.")
        XCTAssertEqual(BreakSpeech.breakStarted(duration: 60, modeTitle: ""), "Pausa: 1 minuto.")
        XCTAssertEqual(BreakSpeech.breakStarted(duration: 30, modeTitle: nil), "Pausa: 30 secondi.")
    }

    func testRemainingAndCountdown() {
        XCTAssertEqual(BreakSpeech.remaining(seconds: 240), "Mancano 4 minuti")
        XCTAssertEqual(BreakSpeech.remaining(seconds: 60), "Manca 1 minuto")
        XCTAssertEqual(BreakSpeech.remaining(seconds: 30), "Mancano 30 secondi")
        XCTAssertEqual(BreakSpeech.countdownValue(remaining: 89.2), "1 minuto e 30 secondi")
    }

    func testSkipHint() {
        XCTAssertEqual(BreakSpeech.skipHint(secondsUntilUnlock: nil, shortcut: "⌃⌥⌘S"), "Modalità severa: la pausa non si salta.")
        XCTAssertEqual(BreakSpeech.skipHint(secondsUntilUnlock: 45, shortcut: nil), "Potrai saltare la pausa tra 45 secondi.")
        XCTAssertEqual(BreakSpeech.skipHint(secondsUntilUnlock: 0, shortcut: "⌃⌥⌘S"), "Puoi saltare la pausa, anche con ⌃⌥⌘S.")
        XCTAssertEqual(BreakSpeech.skipHint(secondsUntilUnlock: 0, shortcut: nil), "Puoi saltare la pausa.")
    }

    func testMilestonesEachMinuteThenThirtyAndTen() {
        XCTAssertEqual(BreakSpeech.milestone(previous: 240.5, current: 239.5), 240)
        XCTAssertEqual(BreakSpeech.milestone(previous: 61, current: 60), 60)
        XCTAssertNil(BreakSpeech.milestone(previous: 239.5, current: 238.5))
        XCTAssertEqual(BreakSpeech.milestone(previous: 30.5, current: 29.5), 30)
        XCTAssertEqual(BreakSpeech.milestone(previous: 10.4, current: 9.4), 10)
        XCTAssertNil(BreakSpeech.milestone(previous: 9, current: 8))
        XCTAssertNil(BreakSpeech.milestone(previous: 1, current: 0))
        XCTAssertNil(BreakSpeech.milestone(previous: 5, current: 6))
    }

    func testMilestonesAcrossAWholeBreakAreSparse() {
        var spoken: [Int] = []
        var previous: TimeInterval = 300
        var t: TimeInterval = 300
        while t > 0 {
            t -= 1
            if let mark = BreakSpeech.milestone(previous: previous, current: t) { spoken.append(mark) }
            previous = t
        }
        XCTAssertEqual(spoken, [240, 180, 120, 60, 30, 10])
    }
}
