import XCTest
@testable import MaramaoCore

final class DisplayScopeTests: XCTestCase {
    func testAllCoversEveryDisplay() {
        XCTAssertEqual(DisplayScope.all.selectedIndices(displayCount: 3, mouseIndex: 2), [0, 1, 2])
        XCTAssertEqual(DisplayScope.all.selectedIndices(displayCount: 1, mouseIndex: nil), [0])
    }

    func testMainIsAlwaysTheFirstDisplay() {
        XCTAssertEqual(DisplayScope.main.selectedIndices(displayCount: 3, mouseIndex: 2), [0])
        XCTAssertEqual(DisplayScope.main.selectedIndices(displayCount: 1, mouseIndex: 0), [0])
    }

    func testMouseFollowsThePointer() {
        XCTAssertEqual(DisplayScope.mouse.selectedIndices(displayCount: 3, mouseIndex: 1), [1])
        XCTAssertEqual(DisplayScope.mouse.selectedIndices(displayCount: 3, mouseIndex: 0), [0])
    }

    func testMouseFallsBackToMainWhenUnknownOrOutOfRange() {
        XCTAssertEqual(DisplayScope.mouse.selectedIndices(displayCount: 2, mouseIndex: nil), [0])
        XCTAssertEqual(DisplayScope.mouse.selectedIndices(displayCount: 2, mouseIndex: 5), [0])
        XCTAssertEqual(DisplayScope.mouse.selectedIndices(displayCount: 2, mouseIndex: -1), [0])
    }

    func testNoDisplaysMeansNothingToCover() {
        for scope in DisplayScope.allCases {
            XCTAssertEqual(scope.selectedIndices(displayCount: 0, mouseIndex: nil), [])
        }
    }

    func testDefaultsAndLabels() {
        XCTAssertEqual(DisplayScope.defaultScope, .all)
        XCTAssertEqual(DisplayScope(rawValue: "mouse"), .mouse)
        XCTAssertEqual(DisplayScope.allCases.map(\.label), [
            "Tutti gli schermi",
            "Solo lo schermo principale",
            "Solo lo schermo con il mouse",
        ])
    }
}
