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
    /// The welcome window, alive only while it is on screen.
    private var onboardingWindow: NSWindow?
    private var onboardingCloseObserver: NSObjectProtocol?

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
        // Community cat packs from ~/Library/Application Support/Maramao/Cats.
        Task { @MainActor in CatPackLibrary.shared.reload() }
        // Runs the user's Shortcuts on phase changes (off unless turned on in Settings).
        Task { @MainActor in ShortcutAutomations.shared.activate() }
        Task { @MainActor in MeasurementHooks.run() }
        // Sparkle auto-update; a no-op until Info.plist has a real public key.
        Task { @MainActor in AppUpdater.shared.start() }
        // First launch: a cat explains what is about to happen (issue #88).
        Task { @MainActor in
            if !AppSettings.shared.hasCompletedOnboarding { self.showOnboarding() }
        }
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
            window.title = String(localized: "Impostazioni di Maramao")
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

    /// Opens the welcome window: on first launch, and from Settings. Created on demand and
    /// released when closed. Closing it in any way (finished, skipped, close button) counts
    /// as done, so it is shown once.
    @MainActor
    func showOnboarding() {
        if onboardingWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 480),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = String(localized: "Benvenuto in Maramao")
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(
                rootView: OnboardingView(onClose: { [weak window] in window?.close() })
                    .environmentObject(AppSettings.shared)
                    .environmentObject(PomodoroEngine.shared)
            )
            window.center()
            onboardingCloseObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.onboardingDidClose() }
            }
            onboardingWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow?.makeKeyAndOrderFront(nil)
    }

    @MainActor
    private func onboardingDidClose() {
        AppSettings.shared.hasCompletedOnboarding = true
        if let observer = onboardingCloseObserver {
            NotificationCenter.default.removeObserver(observer)
            onboardingCloseObserver = nil
        }
        onboardingWindow?.contentView = nil
        onboardingWindow = nil
    }
}
