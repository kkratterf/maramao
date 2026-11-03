import AppKit
import SwiftUI

/// A heart sprayed out of the catch point.
struct LaserChaseHeart: Identifiable {
    let id: Int
    /// Global Cocoa coordinates.
    let origin: CGPoint
    /// Same clock as `LaserChaseSnapshot.time`. May be slightly in the future to stagger hearts.
    let birth: TimeInterval
    /// Initial speed in points per second, Cocoa coordinates (up is positive).
    let velocity: CGVector
    let size: CGFloat
    /// Degrees turned over the heart's life.
    let spin: Double
    let symbol: String

    static let lifetime: TimeInterval = 1.3
    static let symbols = ["❤️", "💖", "💕", "💗", "💘"]
}

/// Everything the stage views need to draw one frame: the cat, the laser dot and the effects.
struct LaserChaseSnapshot {
    var time: TimeInterval = 0
    /// Bottom centre of the cat's frame on the "floor", in global Cocoa coordinates.
    var position: CGPoint = .zero
    /// Width of the cat's frame; the height is always `width * 0.8` (CatView's 200×160 design).
    var width: CGFloat = 180
    var pose: CatPose = .sitting
    var facingLeft = false
    var eyesClosed = false
    var tailWag: Double = 0
    /// Height of the cat above its shadow while it pounces.
    var lift: CGFloat = 0
    /// Horizontal shake of the butt wiggle before a pounce.
    var jitter: CGFloat = 0
    /// Vertical squash: crouching before a pounce, puffing up when proud.
    var squashY: CGFloat = 1
    var dot: CGPoint = .zero
    var dotVisible = true
    /// Last positions of the dot, oldest first, for the glowing trail.
    var trail: [CGPoint] = []
    var hearts: [LaserChaseHeart] = []

    var height: CGFloat { width * 0.8 }

    /// The cat's frame in global coordinates, lifted while it is in the air.
    var frameRect: CGRect {
        CGRect(x: position.x - width / 2, y: position.y + lift, width: width, height: height)
    }
}

/// Per-frame state shared by every screen. Published at 60 fps while the break runs.
@MainActor
final class LaserChaseModel: ObservableObject {
    @Published var snapshot = LaserChaseSnapshot()
    let palette: CatPalette

    init(palette: CatPalette) {
        self.palette = palette
    }
}

/// Bridges the selector-based frame timer to a closure on the main actor.
@MainActor
final class LaserChaseRelay: NSObject {
    private let action: () -> Void

    init(_ action: @escaping () -> Void) {
        self.action = action
    }

    @objc func fire(_ sender: Any?) {
        action()
    }
}

/// Hosts a screen's scene and lets the skip button work on the first click.
final class LaserChaseHostingView: NSHostingView<AnyView> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
