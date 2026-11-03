import XCTest
@testable import MaramaoCore

final class SleepyCatLinesTests: XCTestCase {
    func testLinesUseTheBreakLengthAndTheWakeUps() {
        let lines = SleepyCatLines.angry(breakMinutes: 5, wakeUps: 3)
        XCTAssertGreaterThanOrEqual(lines.count, 10)
        XCTAssertTrue(lines.contains { $0.contains("5") })
        XCTAssertTrue(lines.contains { $0.contains("3") })
        XCTAssertEqual(Set(lines).count, lines.count, "no duplicate lines")
        XCTAssertFalse(SleepyCatLines.asleep.isEmpty)
    }

    func testShuffleBagGivesEveryIndexOncePerRound() {
        var bag = ShuffleBag(count: 6)
        for _ in 0..<5 {
            var round: [Int] = []
            for _ in 0..<6 { round.append(bag.next()!) }
            XCTAssertEqual(Set(round), Set(0..<6))
        }
    }

    func testShuffleBagNeverRepeatsBackToBack() {
        var bag = ShuffleBag(count: 3)
        var previous = bag.next()
        for _ in 0..<300 {
            let pick = bag.next()
            XCTAssertNotEqual(pick, previous)
            previous = pick
        }
    }

    func testShuffleBagEdgeCases() {
        var empty = ShuffleBag(count: 0)
        XCTAssertNil(empty.next())
        var single = ShuffleBag(count: 1)
        XCTAssertEqual(single.next(), 0)
        XCTAssertEqual(single.next(), 0)
    }
}
