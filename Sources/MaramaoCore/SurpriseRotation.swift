import Foundation

/// Which cats 🎲 Sorpresa may pick, and the pick itself.
///
/// Modes are raw `BreakModeID` values, so this logic knows nothing about the
/// modes that exist: a new break mode joins the rotation on its own.
public struct SurpriseRotation: Equatable, Sendable {
    /// Every concrete mode there is, in menu order.
    public let modes: [String]
    /// The modes the user left on. Ids that no longer exist are ignored.
    public let enabled: Set<String>

    public init(modes: [String], enabled: Set<String>) {
        self.modes = modes
        self.enabled = enabled
    }

    /// The modes Sorpresa can pick, in menu order. Never empty while there is at
    /// least one mode: with nothing selected (or only unknown ids), every cat plays.
    public var pool: [String] {
        let chosen = modes.filter { enabled.contains($0) }
        return chosen.isEmpty ? modes : chosen
    }

    /// True when the mode takes part in the rotation.
    public func isOn(_ mode: String) -> Bool { pool.contains(mode) }

    /// True when the mode is the only one left on: turning it off is refused, so
    /// Sorpresa always has a cat to pick.
    public func isLastOn(_ mode: String) -> Bool { pool == [mode] }

    /// The rotation with `mode` turned on or off. Turning the last one off changes nothing.
    public func setting(_ mode: String, on: Bool) -> SurpriseRotation {
        guard modes.contains(mode) else { return self }
        var next = Set(pool)
        if on {
            next.insert(mode)
        } else {
            guard next.count > 1 else { return self }
            next.remove(mode)
        }
        return SurpriseRotation(modes: modes, enabled: next)
    }

    /// A mode from the pool, never `last` unless it is the only one on.
    /// Returns nil only when there is no mode at all.
    public func next<G: RandomNumberGenerator>(after last: String?, using generator: inout G) -> String? {
        let pool = self.pool
        guard !pool.isEmpty else { return nil }
        var candidates = pool.filter { $0 != last }
        if candidates.isEmpty { candidates = pool }
        return candidates.randomElement(using: &generator)
    }

    public func next(after last: String?) -> String? {
        var generator = SystemRandomNumberGenerator()
        return next(after: last, using: &generator)
    }
}
