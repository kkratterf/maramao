import AppKit
import SwiftUI

/// A heart that floats up from the cat after a click.
struct WalkingCatHeart: Identifiable {
    let id: Int
    /// Global Cocoa coordinates.
    let origin: CGPoint
    /// Same clock as `WalkingCatSnapshot.time`. May be slightly in the future to stagger hearts.
    let birth: TimeInterval
    let drift: CGFloat
    let size: CGFloat

    static let lifetime: TimeInterval = 1.5
}

/// Everything the stage views need to draw one frame of the cat.
struct WalkingCatSnapshot {
    var time: TimeInterval = 0
    /// Bottom centre of the cat's frame, in global Cocoa coordinates (bottom-left origin).
    var position: CGPoint = .zero
    /// Width of the cat's frame; the height is always `width * 0.8` (CatView's 200×160 design).
    var width: CGFloat = 130
    var pose: CatPose = .walking(step: 0)
    var facingLeft = false
    var eyesClosed = false
    var tailWag: Double = 0
    var breathX: CGFloat = 1
    var breathY: CGFloat = 1
    var opacity: Double = 1
    var bubble: String?
    var bubbleAge: TimeInterval = 0
    var bubbleRemaining: TimeInterval = 0
    var hearts: [WalkingCatHeart] = []

    var height: CGFloat { width * 0.8 }

    /// The cat's whole frame in global coordinates.
    var frameRect: CGRect {
        CGRect(x: position.x - width / 2, y: position.y, width: width, height: height)
    }

    /// The part of the frame actually covered by the cat, used for clicks and bubbles.
    var bodyRect: CGRect {
        // Fractions of the frame: left, right (facing right), top, bottom (from the top).
        let left: CGFloat
        let right: CGFloat
        let top: CGFloat
        let bottom: CGFloat
        switch pose {
        case .walking:
            left = 0.2; right = 0.98; top = 0.22; bottom = 0.97
        case .sitting:
            left = 0.28; right = 0.78; top = 0.1; bottom = 0.97
        case .sleeping:
            left = 0.15; right = 0.9; top = 0.5; bottom = 0.97
        case .stretching:
            left = 0.2; right = 0.92; top = 0.42; bottom = 0.95
        }
        let x0 = facingLeft ? 1 - right : left
        let x1 = facingLeft ? 1 - left : right
        let frame = frameRect
        return CGRect(
            x: frame.minX + frame.width * x0,
            y: frame.minY + frame.height * (1 - bottom),
            width: frame.width * (x1 - x0),
            height: frame.height * (bottom - top)
        )
    }
}

/// Shared, observable state for every stage window (one per screen).
@MainActor
final class WalkingCatModel: ObservableObject {
    @Published var snapshot = WalkingCatSnapshot()
    let palette: CatPalette

    init(palette: CatPalette) {
        self.palette = palette
    }
}

/// Bridges selector-based AppKit callbacks (timers, notifications) to a closure on the main actor.
@MainActor
final class WalkingCatRelay: NSObject {
    private let action: (Any?) -> Void

    init(_ action: @escaping (Any?) -> Void) {
        self.action = action
    }

    @objc func fire(_ sender: Any?) {
        action(sender)
    }
}

/// The window the cat is going to sit on.
struct WalkingCatTarget: Equatable {
    /// Window server number, or `nil` for the fallback area when no window was found.
    var windowNumber: Int?
    /// Global Cocoa coordinates.
    var frame: NSRect
}

/// Finds the frontmost window of another app. Uses only window bounds, owner and layer,
/// which `CGWindowListCopyWindowInfo` returns without Screen Recording permission.
@MainActor
enum WalkingCatWindowFinder {
    static func frontmostWindow() -> WalkingCatTarget? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        let ownPID = Int(ProcessInfo.processInfo.processIdentifier)
        let screens = NSScreen.screens
        for info in list {
            let layer = (info[kCGWindowLayer as String] as? NSNumber)?.intValue ?? -1
            if layer != 0 { continue }
            let pid = (info[kCGWindowOwnerPID as String] as? NSNumber)?.intValue ?? -1
            if pid == ownPID || pid < 0 { continue }
            let alpha = (info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1
            if alpha <= 0.01 { continue }
            guard let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else { continue }
            if bounds.width <= 200 || bounds.height <= 150 { continue }
            let frame = NSScreen.cocoaRect(fromQuartz: bounds)
            if !screens.contains(where: { $0.frame.intersects(frame) }) { continue }
            let number = (info[kCGWindowNumber as String] as? NSNumber)?.intValue ?? 0
            return WalkingCatTarget(windowNumber: number, frame: frame)
        }
        return nil
    }

    /// The middle of the main screen, used when there is no window to sit on.
    static func fallbackTarget() -> WalkingCatTarget {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let width = visible.width * 0.5
        let height = visible.height * 0.5
        let frame = NSRect(x: visible.midX - width / 2, y: visible.midY - height / 2, width: width, height: height)
        return WalkingCatTarget(windowNumber: nil, frame: frame)
    }

    /// The screen showing most of `rect`.
    static func screen(for rect: NSRect) -> NSScreen? {
        var best: NSScreen?
        var bestArea: CGFloat = 0
        for screen in NSScreen.screens {
            let overlap = screen.frame.intersection(rect)
            if overlap.isNull { continue }
            let area = overlap.width * overlap.height
            if area > bestArea {
                bestArea = area
                best = screen
            }
        }
        return best ?? NSScreen.main ?? NSScreen.screens.first
    }

    /// The screen containing `point`, or the closest one.
    static func screen(containing point: CGPoint) -> NSScreen? {
        let screens = NSScreen.screens
        if let hit = screens.first(where: { $0.frame.contains(point) }) { return hit }
        var best: NSScreen?
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for screen in screens {
            let frame = screen.frame
            let dx = max(frame.minX - point.x, 0, point.x - frame.maxX)
            let dy = max(frame.minY - point.y, 0, point.y - frame.maxY)
            let distance = dx * dx + dy * dy
            if distance < bestDistance {
                bestDistance = distance
                best = screen
            }
        }
        return best ?? NSScreen.main
    }
}
