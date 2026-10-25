import SwiftUI
import MaramaoCore

@main
struct MaramaoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var engine = PomodoroEngine.shared
    @StateObject private var settings = AppSettings.shared
    @StateObject private var stats = StatsStore.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environmentObject(engine)
                .environmentObject(settings)
                .environmentObject(stats)
        } label: {
            MenuBarLabel()
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar only: no Dock icon (also set via LSUIElement in the bundle).
        NSApp.setActivationPolicy(.accessory)
        // System-wide shortcuts (Carbon hot keys, no permission needed).
        Task { @MainActor in GlobalShortcuts.shared.activate() }
        // Runs the user's Shortcuts on phase changes (off unless turned on in Settings).
        Task { @MainActor in ShortcutAutomations.shared.activate() }
        Task { @MainActor in MeasurementHooks.run() }
        // Sparkle auto-update; a no-op until Info.plist has a real public key.
        Task { @MainActor in AppUpdater.shared.start() }
    }

    /// Never leave a cat behind: close every break window before quitting.
    @MainActor
    func applicationWillTerminate(_ notification: Notification) {
        PomodoroEngine.shared.shutdown()
    }

    /// Opens the settings window. A plain NSWindow, because `Settings` scenes
    /// cannot be opened reliably from a MenuBarExtra on every macOS version.
    @MainActor
    func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 560),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Impostazioni di Maramao"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(
                rootView: SettingsView()
                    .environmentObject(AppSettings.shared)
                    .environmentObject(PomodoroEngine.shared)
                    .environmentObject(StatsStore.shared)
            )
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
