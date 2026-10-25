import Foundation
import ServiceManagement

/// Thin wrapper around `SMAppService.mainApp` (macOS 13+) to open Maramao
/// at login. Registration only works when the app runs from its `.app`
/// bundle; from `swift run` the status is usually `.notFound`.
enum LoginItem {
    /// True when Maramao is registered to open at login.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// True when the user still has to allow the login item in
    /// System Settings → General → Login Items.
    static var requiresApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    /// Registers or unregisters the app. Throws the underlying error.
    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
        } else {
            let status = SMAppService.mainApp.status
            if status == .enabled || status == .requiresApproval {
                try SMAppService.mainApp.unregister()
            }
        }
    }
}
