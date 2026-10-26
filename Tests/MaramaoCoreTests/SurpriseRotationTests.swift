import XCTest
@testable import MaramaoCore

/// Deterministic generator so the tests do not depend on luck.
private struct SurpriseGenerator: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

final class SurpriseRotationTests: XCTestCase {
    private let modes = ["walkingCat", "memeWall", "sleepyCat", "catPile"]

    func testPoolKeepsMenuOrderAndIgnoresUnknownModes() {
        let rotation = SurpriseRotation(modes: modes, enabled: ["catPile", "walkingCat", "laserChase"])
        XCTAssertEqual(rotation.pool, ["walkingCat", "catPile"])
        XCTAssertTrue(rotation.isOn("walkingCat"))
        XCTAssertFalse(rotation.isOn("memeWall"))
        XCTAssertFalse(rotation.isOn("laserChase"))
    }

    func testEveryModePlaysWhenNothingIsSelected() {
        XCTAssertEqual(SurpriseRotation(modes: modes, enabled: []).pool, modes)
        XCTAssertEqual(SurpriseRotation(modes: modes, enabled: ["gone"]).pool, modes)
    }

    func testTurningModesOnAndOff() {
        var rotation = SurpriseRotation(modes: modes, enabled: Set(modes))
        rotation = rotation.setting("memeWall", on: false)
        XCTAssertEqual(rotation.pool, ["walkingCat", "sleepyCat", "catPile"])
        rotation = rotation.setting("memeWall", on: true)
        XCTAssertEqual(rotation.pool, modes)
        // An unknown mode cannot be switched on.
        XCTAssertEqual(rotation.setting("laserChase", on: true).pool, modes)
    }

    func testTheLastModeStaysOn() {
        let rotation = SurpriseRotation(modes: modes, enabled: ["sleepyCat"])
        XCTAssertTrue(rotation.isLastOn("sleepyCat"))
        XCTAssertFalse(rotation.isLastOn("catPile"))
        XCTAssertEqual(rotation.setting("sleepyCat", on: false), rotation)
    }

    func testNextStaysInThePool() {
        let rotation = SurpriseRotation(modes: modes, enabled: ["memeWall", "catPile"])
        var generator = SurpriseGenerator(state: 7)
        var seen: Set<String> = []
        for _ in 0..<60 {
            let mode = rotation.next(after: nil, using: &generator)
            XCTAssertNotNil(mode)
            seen.insert(mode ?? "")
        }
        XCTAssertEqual(seen, ["memeWall", "catPile"])
    }

    func testNextNeverRepeatsThePreviousMode() {
        let rotation = SurpriseRotation(modes: modes, enabled: Set(modes))
        var generator = SurpriseGenerator(state: 42)
        var last: String?
        for _ in 0..<200 {
            let mode = rotation.next(after: last, using: &generator)
            XCTAssertNotNil(mode)
            XCTAssertNotEqual(mode, last)
            last = mode
        }
    }

    func testASingleModeRepeatsItself() {
        let rotation = SurpriseRotation(modes: modes, enabled: ["catPile"])
        var generator = SurpriseGenerator(state: 3)
        XCTAssertEqual(rotation.next(after: "catPile", using: &generator), "catPile")
    }

    func testNoModesAtAll() {
        let rotation = SurpriseRotation(modes: [], enabled: ["catPile"])
        XCTAssertTrue(rotation.pool.isEmpty)
        XCTAssertNil(rotation.next(after: nil))
    }
}
