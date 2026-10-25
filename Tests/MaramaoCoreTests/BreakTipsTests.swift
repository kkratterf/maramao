import XCTest
@testable import MaramaoCore

/// Deterministic generator so the tests do not depend on luck.
private struct SplitMix64: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

final class BreakTipsTests: XCTestCase {
    func testListsAreCuratedAndDistinct() {
        XCTAssertGreaterThanOrEqual(BreakTips.short.count, 8)
        XCTAssertGreaterThanOrEqual(BreakTips.long.count, 8)
        XCTAssertEqual(Set(BreakTips.short).count, BreakTips.short.count, "no duplicates in short tips")
        XCTAssertEqual(Set(BreakTips.long).count, BreakTips.long.count, "no duplicates in long tips")
        XCTAssertTrue(Set(BreakTips.short).isDisjoint(with: Set(BreakTips.long)), "long-break tips differ from short-break ones")
        for tip in BreakTips.short + BreakTips.long {
            XCTAssertFalse(tip.trimmingCharacters(in: .whitespaces).isEmpty)
            XCTAssertLessThanOrEqual(tip.count, 90, "tip fits in a small bubble: \(tip)")
        }
    }

    func testTipsMatchBreakKind() {
        XCTAssertEqual(BreakTips.tips(isLongBreak: false), BreakTips.short)
        XCTAssertEqual(BreakTips.tips(isLongBreak: true), BreakTips.long)
        var picker = BreakTipPicker()
        var generator = SplitMix64(state: 1)
        for _ in 0..<50 {
            XCTAssertTrue(BreakTips.short.contains(picker.next(isLongBreak: false, using: &generator)))
            XCTAssertTrue(BreakTips.long.contains(picker.next(isLongBreak: true, using: &generator)))
        }
    }

    func testNeverRepeatsImmediately() {
        var picker = BreakTipPicker()
        var generator = SplitMix64(state: 42)
        var previous = picker.next(isLongBreak: false, using: &generator)
        for _ in 0..<500 {
            let tip = picker.next(isLongBreak: false, using: &generator)
            XCTAssertNotEqual(tip, previous)
            XCTAssertEqual(picker.last, tip)
            previous = tip
        }
    }

    func testNoRepeatWithTwoTipsAlternates() {
        var picker = BreakTipPicker(shortTips: ["a", "b"], longTips: ["c"])
        var generator = SplitMix64(state: 7)
        let first = picker.next(isLongBreak: false, using: &generator)
        for index in 1...20 {
            let tip = picker.next(isLongBreak: false, using: &generator)
            XCTAssertEqual(tip, index % 2 == 0 ? first : (first == "a" ? "b" : "a"))
        }
    }

    func testSingleTipAndEmptyListAreSafe() {
        var picker = BreakTipPicker(shortTips: [], longTips: ["solo"])
        XCTAssertEqual(picker.next(isLongBreak: true), "solo")
        XCTAssertEqual(picker.next(isLongBreak: true), "solo")
        XCTAssertEqual(picker.next(isLongBreak: false), "")
    }

    func testCoversManyTipsOverTime() {
        var picker = BreakTipPicker()
        var generator = SplitMix64(state: 2024)
        var seen = Set<String>()
        for _ in 0..<300 {
            seen.insert(picker.next(isLongBreak: true, using: &generator))
        }
        XCTAssertEqual(seen, Set(BreakTips.long))
    }

    func testStartsFromAGivenLastTip() {
        let last = BreakTips.short[0]
        var picker = BreakTipPicker(last: last)
        var generator = SplitMix64(state: 3)
        XCTAssertNotEqual(picker.next(isLongBreak: false, using: &generator), last)
    }
}
