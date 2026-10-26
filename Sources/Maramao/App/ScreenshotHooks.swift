import AppKit
import Foundation

/// Renders the app's own windows to PNG files, so CI can show what a break looks like
/// (`scripts/render-screenshots.sh`). The app snapshots itself with
/// `cacheDisplay(in:to:)`, which needs no Screen Recording permission: CI runners do
/// not have one, and `screencapture` would give back a black or empty picture there.
///
/// `MARAMAO_SHOTS=<directory>` turns it on, together with `MARAMAO_MEASURE=<mode id>`
/// (see `MeasurementHooks`) to put a break on screen. The app takes one shot of every
/// visible window at each delay in `MARAMAO_SHOT_DELAYS` (seconds, comma separated,
/// default `2,5,9`), writes a `manifest.txt` next to the PNGs and quits.
enum ScreenshotHooks {
    private static let defaultDelays: [TimeInterval] = [2, 5, 9]
    /// Lines for `manifest.txt`: one per PNG, plus one per delay that saw no window.
    @MainActor private static var manifest: [String] = []

    /// Starts the capture schedule when `MARAMAO_SHOTS` is set. Does nothing otherwise.
    @MainActor
    static func run() {
        let environment = ProcessInfo.processInfo.environment
        guard let path = environment["MARAMAO_SHOTS"], !path.isEmpty else { return }
        let label = environment["MARAMAO_MEASURE"] ?? "app"
        let delays = parseDelays(environment["MARAMAO_SHOT_DELAYS"])
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        for (index, delay) in delays.enumerated() {
            let isLast = index == delays.count - 1
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                Task { @MainActor in
                    capture(into: directory, label: label, at: delay)
                    if isLast { finish(into: directory) }
                }
            }
        }
    }

    /// `"2,5"` -> `[2, 5]`. Falls back to the default for an empty or unparsable value.
    private static func parseDelays(_ value: String?) -> [TimeInterval] {
        guard let value else { return defaultDelays }
        let parsed = value
            .split(separator: ",")
            .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            .filter { $0 >= 0 }
        return parsed.isEmpty ? defaultDelays : parsed.sorted()
    }

    /// Writes one PNG per visible window with a content view.
    @MainActor
    private static func capture(into directory: URL, label: String, at delay: TimeInterval) {
        let stamp = String(format: "%.0f", delay)
        var saved = 0
        for window in NSApp.windows {
            guard window.isVisible, let view = window.contentView, view.bounds.width > 1, view.bounds.height > 1 else { continue }
            guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
            view.cacheDisplay(in: view.bounds, to: rep)
            guard let png = rep.representation(using: .png, properties: [:]) else { continue }
            saved += 1
            let name = "\(label)-t\(stamp)s-w\(saved).png"
            do {
                try png.write(to: directory.appendingPathComponent(name))
                let frame = window.frame
                let geometry = String(format: "%.0fx%.0f@%.0f,%.0f", frame.width, frame.height, frame.minX, frame.minY)
                let ink = String(format: "%.1f", inkPercentage(of: rep) * 100)
                manifest.append("\(name) \(rep.pixelsWide)x\(rep.pixelsHigh) window=\(geometry) ink=\(ink)%")
            } catch {
                manifest.append("\(name) error=\(error.localizedDescription)")
            }
        }
        if saved == 0 {
            manifest.append("\(label)-t\(stamp)s none=no-visible-window")
        }
    }

    /// Fraction of a sampled grid of pixels that is not fully transparent. A frame at 0%
    /// is empty: the mode drew nothing, or drew it somewhere else.
    private static func inkPercentage(of rep: NSBitmapImageRep) -> Double {
        let steps = 32
        var inked = 0
        var sampled = 0
        for row in 0..<steps {
            for column in 0..<steps {
                let x = rep.pixelsWide * column / steps
                let y = rep.pixelsHigh * row / steps
                guard x < rep.pixelsWide, y < rep.pixelsHigh else { continue }
                sampled += 1
                if let color = rep.colorAt(x: x, y: y), color.alphaComponent > 0.02 { inked += 1 }
            }
        }
        return sampled == 0 ? 0 : Double(inked) / Double(sampled)
    }

    /// Writes the manifest and quits, so the script can move on to the next mode.
    @MainActor
    private static func finish(into directory: URL) {
        let text = manifest.joined(separator: "\n") + "\n"
        try? text.write(to: directory.appendingPathComponent("manifest.txt"), atomically: true, encoding: .utf8)
        print(text, terminator: "")
        fflush(stdout)
        PomodoroEngine.shared.shutdown()
        exit(0)
    }
}
