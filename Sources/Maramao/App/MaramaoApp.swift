import SwiftUI
import AppKit
import CoreServices
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

    func applicationWillFinishLaunching(_ notification: Notification) {
        // maramao:// URLs. Installed before launch finishes so the URL that
        // launched the app is not lost, and handled here directly so SwiftUI
        // never tries to open a window for it.
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    /// Fallback path for URLs, in case AppKit routes them to the delegate.
    func application(_ application: NSApplication, open urls: [URL]) {
        Task { @MainActor in
            for url in urls { AutomationRunner.handle(url) }
        }
    }

    @objc private func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor) {
        guard let string = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: string) else { return }
        Task { @MainActor in AutomationRunner.handle(url) }
    }

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
