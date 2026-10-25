import AppKit
import Combine
import Sparkle
import MaramaoCore

/// Auto-update with Sparkle 2 (issue #28).
///
/// The updater only starts when Info.plist carries a real `SUPublicEDKey`
/// (see `UpdaterConfiguration`): until the maintainer pastes the public key,
/// `isAvailable` is false and every update control stays hidden. The feed is
/// `SUFeedURL`, the appcast published on GitHub Pages by `release.yml`.
@MainActor
final class AppUpdater: ObservableObject {
    static let shared = AppUpdater()

    /// False when the build has no real public key, or runs outside the .app.
    let isAvailable: Bool

    /// Mirrors `SPUUpdater.canCheckForUpdates` (false while a check runs).
    @Published private(set) var canCheckForUpdates = false

    /// Version of an update Sparkle found on its own, until the user deals with it.
    @Published private(set) var pendingUpdateVersion: String?

    /// "Aggiorna automaticamente": Sparkle checks the feed once a day and
    /// offers the update when there is one.
    @Published var automaticallyChecksForUpdates = false {
        didSet {
            guard let updater = controller?.updater,
                  updater.automaticallyChecksForUpdates != automaticallyChecksForUpdates
            else { return }
            updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
        }
    }

    private var controller: SPUStandardUpdaterController?
    /// Sparkle keeps its delegates weakly.
    private let userDriverDelegate = UpdaterUserDriverDelegate()

    init() {
        let info = Bundle.main.infoDictionary ?? [:]
        isAvailable = UpdaterConfiguration.isEnabled(
            publicKey: info["SUPublicEDKey"] as? String,
            feedURL: info["SUFeedURL"] as? String,
            bundlePath: Bundle.main.bundlePath
        )
    }

    /// Starts Sparkle. Call once at launch; does nothing when unavailable.
    func start() {
        guard isAvailable, controller == nil else { return }
        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: userDriverDelegate
        )
        self.controller = controller
        let updater = controller.updater
        automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    /// "Controlla aggiornamenti…": a user-initiated check, with Sparkle's window.
    func checkForUpdates() {
        guard let controller = controller else { return }
        // A menu bar app is never frontmost: bring Sparkle's window forward.
        NSApp.activate(ignoringOtherApps: true)
        controller.updater.checkForUpdates()
    }

    fileprivate func setPendingUpdate(_ version: String?) {
        pendingUpdateVersion = version
    }
}

// Gentle reminders: Maramao has no Dock icon, so a scheduled update alert can
// end up behind other windows. Sparkle still shows it, and the menu also
// gets a "nuova versione" line until the update session ends.
final class UpdaterUserDriverDelegate: NSObject, SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool {
        return true
    }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        let version = update.displayVersionString
        Task { @MainActor in
            AppUpdater.shared.setPendingUpdate(version)
        }
    }

    func standardUserDriverWillFinishUpdateSession() {
        Task { @MainActor in
            AppUpdater.shared.setPendingUpdate(nil)
        }
    }
}
