import AppKit

/// Creates the break mode for each break and tears it down when the break is over.
@MainActor
final class BreakCoordinator {
    private var current: BreakMode?
    private(set) var currentModeID: BreakModeID?

    var isActive: Bool { current != nil }

    func start(mode: BreakModeID, context: BreakContext) {
        end()
        let resolved = mode.resolved()
        let breakMode = Self.make(resolved)
        current = breakMode
        currentModeID = resolved
        breakMode.begin(context: context)
    }

    func end() {
        guard let breakMode = current else { return }
        current = nil
        currentModeID = nil
        breakMode.end()
    }

    private static func make(_ id: BreakModeID) -> BreakMode {
        switch id {
        case .walkingCat: return WalkingCatBreak()
        case .memeWall: return MemeWallBreak()
        case .sleepyCat: return SleepyCatBreak()
        case .catPile: return CatPileBreak()
        case .laserChase: return LaserChaseBreak()
        case .random: return WalkingCatBreak()
        }
    }
}
