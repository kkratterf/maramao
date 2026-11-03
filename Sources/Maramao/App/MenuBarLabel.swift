import SwiftUI
import Combine
import MaramaoCore

struct MenuBarRing: Hashable {
    /// Filled part of the ring, 0...MenuBarRingRenderer.steps.
    var step: Int
}

/// What the menu bar item shows. The cat is always there (as an SF Symbol, so it follows
/// the menu bar's light and dark look); `text` is what comes after it, usually the countdown.
struct MenuBarContent: Equatable {
    var showsCat: Bool
    var text: String
    var ring: MenuBarRing?
}

/// Turns the engine state and the display settings into `MenuBarContent`,
/// publishing only when it changes.
@MainActor
final class MenuBarModel: ObservableObject {
    @Published private(set) var content = MenuBarContent(showsCat: true, text: "", ring: nil)

    convenience init() {
        self.init(engine: PomodoroEngine.shared, settings: AppSettings.shared)
    }

    init(engine: PomodoroEngine, settings: AppSettings) {
        let clock = Publishers.CombineLatest4(engine.$phase, engine.$remaining, engine.$phaseDuration, engine.$isPaused)
        let prefs = Publishers.CombineLatest(settings.$menuBarStyleRaw, settings.$menuBarHideSeconds)
        clock
            .combineLatest(prefs)
            .map { clockValues, prefValues -> MenuBarContent in
                makeMenuBarContent(
                    phase: clockValues.0,
                    remaining: clockValues.1,
                    phaseDuration: clockValues.2,
                    isPaused: clockValues.3,
                    style: MenuBarStyle(rawValue: prefValues.0) ?? .defaultStyle,
                    hideSeconds: prefValues.1
                )
            }
            .removeDuplicates()
            .assign(to: &$content)
    }
}

/// Pure mapping from state to what the menu bar shows.
private func makeMenuBarContent(
    phase: PomodoroPhase,
    remaining: TimeInterval,
    phaseDuration: TimeInterval,
    isPaused: Bool,
    style: MenuBarStyle,
    hideSeconds: Bool
) -> MenuBarContent {
    // Idle: there is no countdown to show, only the cat.
    guard phase != .idle else {
        if style == .catWithRing {
            return MenuBarContent(showsCat: false, text: "", ring: MenuBarRing(step: 0))
        }
        return MenuBarContent(showsCat: true, text: "", ring: nil)
    }

    let clock = formatMenuBarClock(remaining, showSeconds: !hideSeconds)
    // Keep a hint that the timer is paused, otherwise the digits just freeze.
    let countdown = isPaused ? "⏸ \(clock)" : clock
    switch style {
    case .catAndCountdown:
        return MenuBarContent(showsCat: true, text: countdown, ring: nil)
    case .catOnly:
        return MenuBarContent(showsCat: true, text: "", ring: nil)
    case .countdownOnly:
        return MenuBarContent(showsCat: false, text: countdown, ring: nil)
    case .catWithRing:
        let progress = phaseDuration > 0 ? 1 - remaining / phaseDuration : 0
        let step = menuBarRingStep(progress: progress, steps: MenuBarRingRenderer.steps)
        return MenuBarContent(showsCat: false, text: "", ring: MenuBarRing(step: step))
    }
}

/// Renders the ring as a template image (so it follows the menu bar's
/// light/dark appearance) and caches one image per step.
@MainActor
enum MenuBarRingRenderer {
    /// Ring resolution: at most this many distinct images.
    nonisolated static let steps = 48

    private static var cache: [MenuBarRing: NSImage] = [:]

    static func image(for ring: MenuBarRing) -> NSImage {
        if let cached = cache[ring] { return cached }
        let view = MenuBarRingView(
            symbolName: MenuBarCat.symbolName,
            progress: Double(ring.step) / Double(steps)
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        let image = renderer.nsImage ?? NSImage(size: NSSize(width: 18, height: 18))
        image.isTemplate = true
        cache[ring] = image
        return image
    }
}

/// The cat in the menu bar. It stays a cat in every phase: the menu bar item is how people
/// find Maramao, so it should not turn into a tomato or a cup while the timer runs.
enum MenuBarCat {
    /// "cat.fill" ships with SF Symbols 4 (macOS 13); fall back to a paw just in case.
    static var symbolName: String {
        NSImage(systemSymbolName: "cat.fill", accessibilityDescription: nil) != nil ? "cat.fill" : "pawprint.fill"
    }

    static let image: NSImage = {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        let base = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Maramao") ?? NSImage()
        let image = base.withSymbolConfiguration(config) ?? base
        image.isTemplate = true
        return image
    }()
}

/// The ring drawn in black on transparent: it becomes a template image.
private struct MenuBarRingView: View {
    let symbolName: String
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.black.opacity(0.3), lineWidth: 1.6)
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(Color.black, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: symbolName)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.black)
        }
        .padding(1)
        .frame(width: 18, height: 18)
    }
}
