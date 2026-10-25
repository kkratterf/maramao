import Foundation

/// Which displays the cats cover during a break.
public enum DisplayScope: String, CaseIterable, Sendable {
    /// Every connected display (default).
    case all
    /// Only the main display, the one with the menu bar.
    case main
    /// Only the display the mouse pointer is on when the break starts.
    case mouse

    public static let defaultScope: DisplayScope = .all

    /// Italian label for Settings.
    public var label: String {
        switch self {
        case .all: return String(localized: "Tutti gli schermi")
        case .main: return String(localized: "Solo lo schermo principale")
        case .mouse: return String(localized: "Solo lo schermo con il mouse")
        }
    }

    /// Indices of the displays to cover, given `count` displays where index 0 is the main
    /// display (as in `NSScreen.screens`) and the index of the display under the mouse, if known.
    /// Never empty when there is at least one display: falls back to the main one.
    public func selectedIndices(displayCount count: Int, mouseIndex: Int?) -> [Int] {
        guard count > 0 else { return [] }
        switch self {
        case .all:
            return Array(0..<count)
        case .main:
            return [0]
        case .mouse:
            if let mouseIndex, mouseIndex >= 0, mouseIndex < count {
                return [mouseIndex]
            }
            return [0]
        }
    }
}
