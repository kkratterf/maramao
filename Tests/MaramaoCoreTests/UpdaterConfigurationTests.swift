import XCTest
@testable import MaramaoCore

final class UpdaterConfigurationTests: XCTestCase {
    /// 32 bytes, base64: the shape of a key printed by Sparkle's generate_keys.
    private let realKey = Data(repeating: 7, count: 32).base64EncodedString()
    private let feed = "https://kkratterf.github.io/maramao/appcast.xml"
    private let bundle = "/Applications/Maramao.app"

    func testPlaceholderKeyIsNotReal() {
        XCTAssertFalse(UpdaterConfiguration.isRealPublicKey(UpdaterConfiguration.placeholderPublicKey))
    }

    func testMissingOrEmptyKeyIsNotReal() {
        XCTAssertFalse(UpdaterConfiguration.isRealPublicKey(nil))
        XCTAssertFalse(UpdaterConfiguration.isRealPublicKey(""))
        XCTAssertFalse(UpdaterConfiguration.isRealPublicKey("   "))
    }

    func testKeyMustBe32BytesOfBase64() {
        XCTAssertTrue(UpdaterConfiguration.isRealPublicKey(realKey))
        XCTAssertTrue(UpdaterConfiguration.isRealPublicKey(" \(realKey)\n"))
        XCTAssertFalse(UpdaterConfiguration.isRealPublicKey("not base64 at all!"))
        XCTAssertFalse(UpdaterConfiguration.isRealPublicKey(Data(repeating: 1, count: 16).base64EncodedString()))
        XCTAssertFalse(UpdaterConfiguration.isRealPublicKey(Data(repeating: 1, count: 64).base64EncodedString()))
    }

    func testFeedURLMustBeHTTPS() {
        XCTAssertTrue(UpdaterConfiguration.isValidFeedURL(feed))
        XCTAssertFalse(UpdaterConfiguration.isValidFeedURL("http://kkratterf.github.io/maramao/appcast.xml"))
        XCTAssertFalse(UpdaterConfiguration.isValidFeedURL("appcast.xml"))
        XCTAssertFalse(UpdaterConfiguration.isValidFeedURL(""))
        XCTAssertFalse(UpdaterConfiguration.isValidFeedURL(nil))
    }

    func testEnabledOnlyWithEverythingInPlace() {
        XCTAssertTrue(UpdaterConfiguration.isEnabled(publicKey: realKey, feedURL: feed, bundlePath: bundle))
        XCTAssertTrue(UpdaterConfiguration.isEnabled(publicKey: realKey, feedURL: feed, bundlePath: bundle + "/"))
        XCTAssertFalse(UpdaterConfiguration.isEnabled(
            publicKey: UpdaterConfiguration.placeholderPublicKey, feedURL: feed, bundlePath: bundle))
        XCTAssertFalse(UpdaterConfiguration.isEnabled(publicKey: realKey, feedURL: nil, bundlePath: bundle))
    }

    func testDisabledOutsideAnAppBundle() {
        // `swift run` executes the bare binary from .build.
        XCTAssertFalse(UpdaterConfiguration.isEnabled(
            publicKey: realKey, feedURL: feed, bundlePath: "/Users/me/maramao/.build/debug"))
    }
}
