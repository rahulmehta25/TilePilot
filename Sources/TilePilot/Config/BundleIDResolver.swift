import Foundation
import AppKit

final class BundleIDResolver {

    struct RunningAppInfo {
        let name: String
        let bundleID: String
        let icon: NSImage?
    }

    /// List all user-facing running applications with their bundle IDs
    static func listRunningApps() -> [RunningAppInfo] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app in
                guard let bundleID = app.bundleIdentifier,
                      let name = app.localizedName else { return nil }
                return RunningAppInfo(name: name, bundleID: bundleID, icon: app.icon)
            }
    }

    /// Resolve an app name to its bundle ID by checking running apps
    static func resolve(appName: String) -> String? {
        let lowered = appName.lowercased()
        return NSWorkspace.shared.runningApplications
            .first { app in
                app.localizedName?.lowercased() == lowered
            }?
            .bundleIdentifier
    }

    /// Check if a bundle ID corresponds to a currently running application
    static func isRunning(bundleID: String) -> Bool {
        NSWorkspace.shared.runningApplications
            .contains { $0.bundleIdentifier == bundleID }
    }
}
