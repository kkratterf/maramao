import XCTest
@testable import MaramaoCore

final class FocusFilterPolicyTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "FocusFilterPolicyTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        defaults = nil
        super.tearDown()
    }

    func testDefaultsChangeNothing() {
        let policy = FocusFilterPolicy()
        XCTAssertEqual(policy, .unrestricted)
        XCTAssertFalse(policy.isActive)
        XCTAssertTrue(policy.soundsAllowed)
        XCTAssertEqual(policy.breakMode(default: "catPile"), "catPile")
    }

    func testCatsOffMeansNoBreakModeAndNoSounds() {
        let policy = FocusFilterPolicy(catsEnabled: false, breakModeOverride: "sleepyCat", soundsEnabled: true)
        XCTAssertTrue(policy.isActive)
        XCTAssertNil(policy.breakMode(default: "catPile"))
        XCTAssertFalse(policy.soundsAllowed)
    }

    func testOverrideWinsOverSettings() {
        let policy = FocusFilterPolicy(breakModeOverride: "sleepyCat")
        XCTAssertEqual(policy.breakMode(default: "catPile"), "sleepyCat")
        XCTAssertEqual(FocusFilterPolicy(breakModeOverride: "").breakMode(default: "catPile"), "catPile")
    }

    func testSoundsOffKeepsTheCats() {
        let policy = FocusFilterPolicy(soundsEnabled: false)
        XCTAssertFalse(policy.soundsAllowed)
        XCTAssertEqual(policy.breakMode(default: "memeWall"), "memeWall")
    }

    func testNothingStoredLoadsUnrestricted() {
        XCTAssertEqual(FocusFilterPolicy.load(from: defaults), .unrestricted)
    }

    func testStoreAndLoadRoundTrip() {
        let policy = FocusFilterPolicy(catsEnabled: false, breakModeOverride: "laserChase", soundsEnabled: false)
        policy.store(in: defaults)
        XCTAssertEqual(FocusFilterPolicy.load(from: defaults), policy)

        // Turning the Focus off stores the defaults again and clears the override.
        FocusFilterPolicy.unrestricted.store(in: defaults)
        XCTAssertEqual(FocusFilterPolicy.load(from: defaults), .unrestricted)
    }
}
