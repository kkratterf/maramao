import XCTest
@testable import MaramaoCore

final class OnboardingTests: XCTestCase {
    func testStepsRunInOrder() {
        XCTAssertEqual(OnboardingStep.allCases, [.welcome, .timing, .cat, .trial, .emergencyExit, .launchAtLogin])
        var step = OnboardingStep.first
        var visited = [step]
        while let next = step.next {
            step = next
            visited.append(step)
        }
        XCTAssertEqual(visited, OnboardingStep.allCases)
    }

    func testFirstAndLast() {
        XCTAssertTrue(OnboardingStep.welcome.isFirst)
        XCTAssertNil(OnboardingStep.welcome.previous)
        XCTAssertTrue(OnboardingStep.launchAtLogin.isLast)
        XCTAssertNil(OnboardingStep.launchAtLogin.next)
        XCTAssertFalse(OnboardingStep.cat.isFirst)
        XCTAssertFalse(OnboardingStep.cat.isLast)
    }

    func testPreviousUndoesNext() {
        for step in OnboardingStep.allCases {
            if let next = step.next { XCTAssertEqual(next.previous, step) }
        }
    }

    func testNumberIsOneBased() {
        XCTAssertEqual(OnboardingStep.welcome.number, 1)
        XCTAssertEqual(OnboardingStep.launchAtLogin.number, OnboardingStep.allCases.count)
    }

    func testTrialBreakIsShort() {
        XCTAssertEqual(OnboardingStep.trialBreakSeconds, 10)
    }

    func testNewUserSeesOnboarding() {
        XCTAssertFalse(OnboardingPolicy.hasCompleted(stored: nil, hasPriorSettings: false))
    }

    func testUpgradingUserSkipsOnboarding() {
        XCTAssertTrue(OnboardingPolicy.hasCompleted(stored: nil, hasPriorSettings: true))
    }

    func testStoredFlagWins() {
        XCTAssertTrue(OnboardingPolicy.hasCompleted(stored: true, hasPriorSettings: false))
        XCTAssertFalse(OnboardingPolicy.hasCompleted(stored: false, hasPriorSettings: true))
    }
}
